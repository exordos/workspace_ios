import FirebaseCore
import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

nonisolated enum WorkspacePushRoute: Equatable, Sendable {
    case direct(userUUID: String)
    case topic(stream: String, topic: String)
}

nonisolated enum WorkspacePushPayload: Equatable, Sendable {
    case cancel(messageIdentifiers: [String])
    case route(WorkspacePushRoute)
    case other

    init(userInfo: [AnyHashable: Any]) {
        func string(_ key: String) -> String? {
            if let value = userInfo[key] as? String { return value }
            if let value = userInfo[key] as? NSNumber { return value.stringValue }
            return nil
        }

        switch string("kind") {
        case "remove_notification_message":
            let identifiers = string("message_ids")?
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []
            self = identifiers.isEmpty ? .other : .cancel(messageIdentifiers: identifiers)
        case "private_chat_message":
            guard let userUUID = string("sender_id"), !userUUID.isEmpty else {
                self = .other
                return
            }
            self = .route(.direct(userUUID: userUUID))
        case "stream_chat_message":
            guard let stream = string("stream"), !stream.isEmpty,
                  let topic = string("topic"), !topic.isEmpty
            else {
                self = .other
                return
            }
            self = .route(.topic(stream: stream, topic: topic))
        default:
            self = .other
        }
    }
}

@MainActor
final class WorkspacePushNotifications: NSObject {
    static let shared = WorkspacePushNotifications()

    private var isConfigured = false
    private var tokenContinuations: [UUID: AsyncStream<String>.Continuation] = [:]
    private var routeContinuations: [UUID: AsyncStream<WorkspacePushRoute>.Continuation] = [:]

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        guard !isConfigured else { return }
        guard let configurationPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: configurationPath)
        else { return }

        if FirebaseApp.app() == nil { FirebaseApp.configure(options: options) }
        Messaging.messaging().delegate = self
        isConfigured = true
    }

    func activate() async -> String? {
        configure()
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        guard granted else { return nil }
        UIApplication.shared.registerForRemoteNotifications()
        guard isConfigured else { return nil }
        return try? await Messaging.messaging().token()
    }

    func receiveAPNSToken(_ token: Data) {
        guard isConfigured else { return }
        Messaging.messaging().apnsToken = token
    }

    func tokenUpdates() -> AsyncStream<String> {
        AsyncStream { continuation in
            let id = UUID()
            let owner = self
            tokenContinuations[id] = continuation
            continuation.onTermination = { [weak owner] _ in
                Task { @MainActor [weak owner] in
                    owner?.tokenContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    func routeUpdates() -> AsyncStream<WorkspacePushRoute> {
        AsyncStream { continuation in
            let id = UUID()
            let owner = self
            routeContinuations[id] = continuation
            continuation.onTermination = { [weak owner] _ in
                Task { @MainActor [weak owner] in
                    owner?.routeContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    func handleRemoteNotification(_ payload: WorkspacePushPayload) async -> UIBackgroundFetchResult {
        guard case .cancel(let messageIdentifiers) = payload else { return .noData }

        let center = UNUserNotificationCenter.current()
        let identifiers = Set(messageIdentifiers)
        let delivered = await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }
        let deliveredIdentifiers = delivered.compactMap { notification -> String? in
            let request = notification.request
            let workspaceMessageID = request.content.userInfo["workspace_message_id"]
                .map { String(describing: $0) }
            guard identifiers.contains(request.identifier) ||
                    workspaceMessageID.map(identifiers.contains) == true
            else { return nil }
            return request.identifier
        }
        center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
        center.removePendingNotificationRequests(withIdentifiers: messageIdentifiers)
        return deliveredIdentifiers.isEmpty ? .noData : .newData
    }

    private func publish(token: String) {
        guard !token.isEmpty else { return }
        tokenContinuations.values.forEach { $0.yield(token) }
    }

    private func publish(route: WorkspacePushRoute) {
        routeContinuations.values.forEach { $0.yield(route) }
    }
}

extension WorkspacePushNotifications: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in publish(token: fcmToken) }
    }
}

extension WorkspacePushNotifications: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let payload = WorkspacePushPayload(userInfo: response.notification.request.content.userInfo)
        completionHandler()
        guard case .route(let route) = payload else { return }
        Task { @MainActor in publish(route: route) }
    }
}
