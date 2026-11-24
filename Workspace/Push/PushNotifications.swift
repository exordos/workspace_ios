import Combine
import UIKit
import UserNotifications

@MainActor
final class PushNotifications: ObservableObject {
    static let shared = PushNotifications()

    @Published var pendingTap: PushEnvelope?
    weak var profile: UserProfile?
    private var deviceToken: Data?
    private var registrationTask: Task<Void, Never>?
    private var needsRegistration = false
    private var generation = 0

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config, delegate: PushDeviceSessionDelegate(), delegateQueue: nil)
    }()

    func synchronize() {
        needsRegistration = true
        guard registrationTask == nil else { return }
        registrationTask = Task {
            while needsRegistration {
                needsRegistration = false
                await register()
            }
            registrationTask = nil
        }
    }

    func receivedDeviceToken(_ token: Data) {
        deviceToken = token
        synchronize()
    }

    private func register() async {
        guard let scope = profile?.pushSession else { return }
        let checkpoint = generation
        let api = WorkspaceAPIClient.current!
        do {
            guard let settings = try await api.createPublisher(for: ServerSettingsRequest(with: scope.baseUrl))
                .values.first(where: { _ in true }), isCurrent(scope, checkpoint) else { return }
            guard settings.apnsPushNotificationsEnabled == true,
                  let organizationUuid = settings.organizationUuid?.lowercased(),
                  UUID(uuidString: organizationUuid) != nil else { return }

            let center = UNUserNotificationCenter.current()
            let authorization = await center.notificationSettings().authorizationStatus
            guard isCurrent(scope, checkpoint) else { return }
            if authorization == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            }
            let granted = await center.notificationSettings().authorizationStatus
            guard isCurrent(scope, checkpoint) else { return }
            guard granted == .authorized || granted == .provisional || granted == .ephemeral else {
                endSession()
                return
            }
            guard let deviceToken else {
                UIApplication.shared.registerForRemoteNotifications()
                return
            }
            guard let user = try await api.createPublisher(for: OwnUserRequest())
                .values.first(where: { _ in true }), isCurrent(scope, checkpoint),
                  let accessToken = profile?.accessToken else { return }

            let userUuid = user.uuid.lowercased()
            let previous = try PushRegistration.read()
            let registration: PushRegistration
            if let previous, previous.session == scope, previous.userUuid == userUuid,
               previous.organizationUuid == organizationUuid {
                registration = previous
            } else {
                if let previous {
                    await clearNotifications(for: previous)
                    guard isCurrent(scope, checkpoint) else { return }
                }
                registration = PushRegistration(session: scope, organizationUuid: organizationUuid, userUuid: userUuid)
                try registration.save()
            }
            let request = try registration.request(method: .put, accessToken: accessToken, deviceToken: deviceToken)
            let (data, response) = try await session.data(for: request)
            guard isCurrent(scope, checkpoint), let response = response as? HTTPURLResponse,
                  [200, 201].contains(response.statusCode) else { return }
            let saved = try JSONDecoder().decode(RegisteredDevice.self, from: data)
            guard saved.uuid == registration.deviceUuid, saved.projectId == scope.projectUuid,
                  saved.userUuid == userUuid else {
                endSession()
                return
            }
        } catch {
            // Retry on the next foreground transition or APNs token callback.
        }
    }

    private func isCurrent(_ scope: PushSession, _ checkpoint: Int) -> Bool {
        scope == profile?.pushSession && checkpoint == generation
    }

    func endSession() {
        generation += 1
        pendingTap = nil
        guard let registration = try? PushRegistration.read() else { return }
        let accessToken = profile?.pushSession == registration.session ? profile?.accessToken : nil
        try? PushRegistration.storage.deleteItem()
        let inFlight = registrationTask
        Task {
            await clearNotifications(for: registration)
            // Keep DELETE behind a PUT that may already have reached Workspace.
            await inFlight?.value
            if let accessToken, let request = try? registration.request(method: .delete, accessToken: accessToken) {
                _ = try? await session.data(for: request)
            }
        }
    }

    func open(_ userInfo: [AnyHashable: Any]) {
        guard let (envelope, snapshot, _) = openEnvelope(userInfo),
              snapshot.activeUnreadCount > 0 else { return }
        pendingTap = envelope
    }

    func canPresent(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let (_, snapshot, _) = openEnvelope(userInfo) else { return false }
        return snapshot.activeUnreadCount > 0
    }

    func processReadUpdate(_ userInfo: [AnyHashable: Any]) async -> Bool {
        guard let (envelope, snapshot, registration) = openEnvelope(userInfo),
              snapshot.activeUnreadCount == 0 else { return false }
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
        let matched = delivered.compactMap { notification -> String? in
            guard let prior = PushEnvelope.read(notification.request.content.userInfo),
                  prior.streamUuid == envelope.streamUuid, prior.topicUuid == envelope.topicUuid,
                  let state = prior.open(using: registration),
                  state.epochGeneration == snapshot.epochGeneration,
                  state.epochVersion <= snapshot.epochVersion else { return nil }
            return notification.request.identifier
        }
        center.removeDeliveredNotifications(withIdentifiers: matched)
        return !matched.isEmpty
    }

    private func openEnvelope(_ userInfo: [AnyHashable: Any]) -> (PushEnvelope, PushEnvelope.Snapshot, PushRegistration)? {
        guard let registration = try? PushRegistration.read(), profile?.pushSession == registration.session,
              let envelope = PushEnvelope.read(userInfo),
              let snapshot = envelope.open(using: registration) else { return nil }
        return (envelope, snapshot, registration)
    }

    private func clearNotifications(for registration: PushRegistration) async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
        let identifiers = delivered.compactMap { notification in
            PushEnvelope.read(notification.request.content.userInfo)?.deviceUuid == registration.deviceUuid
                ? notification.request.identifier : nil
        }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

private struct RegisteredDevice: Decodable {
    let uuid: String
    let projectId: String
    let userUuid: String

    enum CodingKeys: String, CodingKey {
        case uuid
        case projectId = "project_id"
        case userUuid = "user_uuid"
    }
}

private final class PushDeviceSessionDelegate: NSObject, URLSessionTaskDelegate {
    nonisolated func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
