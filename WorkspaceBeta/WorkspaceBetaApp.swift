//
//  WorkspaceBetaApp.swift
//  WorkspaceBeta
//
//

import SwiftUI
import SwiftData
import JitsiMeetSDK
import FirebaseCore
import FirebaseMessaging

@main
struct WorkspaceBetaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject var userProfile: UserProfile

    var viewModel: WorkspaceBetaAppViewModel

    var body: some Scene {
        WindowGroup {
            mainView
                .onAppear {
                    WorkspaceAPIClient.current.userProfile = userProfile
                    viewModel.userProfile = userProfile
                }
        }
        .modelContainer(sharedModelContainer)
    }

    init() {
        let userProfile = UserProfile()
        self._userProfile = StateObject(wrappedValue: userProfile)
        WorkspaceAPIClient()
        self.viewModel = WorkspaceBetaAppViewModel(with: WorkspaceAPIClient.current, userProfile: userProfile)
    }

    private var mainView: some View {
        Group {
            if userProfile.accessToken == nil {
                ChooseServerAssembly().assemble(with: userProfile)
            } else {
                MainTabBarAssembly().assemble(with: viewModel.mainTabBarViewModel)
            }
        }
        .background(Color.background)
    }
}

class WorkspaceBetaAppViewModel {

    let apiClient: APIClient
    var userProfile: UserProfile

    lazy var mainTabBarViewModel: MainTabBarViewModel = {
        let model = MainTabBar()
        let profile = userProfile
        return MainTabBarViewModel(apiClient: apiClient, model: model, userProfile: userProfile)
    }()

    init(with apiClient: APIClient, userProfile: UserProfile) {
        self.apiClient = apiClient
        self.userProfile = userProfile
    }
}


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        let defaultOptions = JitsiMeetConferenceOptions.fromBuilder { (builder) in
            builder.serverURL = URL(string: "https://meet.genesis-core.tech")
            builder.setFeatureFlag("welcomepage.enabled", withValue: false)
        }
        JitsiMeet.sharedInstance().defaultConferenceOptions = defaultOptions
        FirebaseApp.configure()


        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
          options: authOptions,
          completionHandler: { _, _ in }
        )

        application.registerForRemoteNotifications()

        let jitsiStarted = JitsiMeet.sharedInstance().application(
            application,
            didFinishLaunchingWithOptions: launchOptions ?? [:]
        )
        return jitsiStarted
    }

    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Messaging.messaging().apnsToken = deviceToken
        print(tokenString)
    }

//    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
//        print(userInfo)
//
//        Messaging.messaging().appDidReceiveMessage(userInfo)
//        completionHandler(.newData)
//    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        if let kind = userInfo["kind"] as? String {
            switch kind {
            case "remove_notification_message":
                if let messageIdsString = userInfo["message_ids"] as? String {
                    let messageIds = messageIdsString.split(separator: ",").map(String.init)
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: messageIds)
                }
            case "private_chat_message":
                if let messageId = userInfo["workspace_message_id"] as? String,
                   let senderFullName = userInfo["sender_full_name"] as? String,
                   let messageContent = userInfo["content"] as? String {
                    let content = UNMutableNotificationContent()
                    content.title = senderFullName
                    content.body = messageContent
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: .zero, repeats: false)
                    let request = UNNotificationRequest(identifier: messageId, content: content, trigger: trigger)
                }
             case "stream_chat_message":
                if let messageId = userInfo["workspace_message_id"] as? String,
                   let senderFullName = userInfo["sender_full_name"] as? String,
                   let messageContent = userInfo["content"] as? String,
                   let stream = userInfo["stream"] as? String,
                   let topic = userInfo["topic"] as? String {
                    let content = UNMutableNotificationContent()
                    content.title = "\(stream) -> \(topic)"
                    content.body = "\(senderFullName): \(messageContent)"
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: .zero, repeats: false)
                    let request = UNNotificationRequest(identifier: messageId, content: content, trigger: trigger)
                }
            default:
                break
            }
        }
        Messaging.messaging().appDidReceiveMessage(userInfo)
        print(userInfo)
        return UIBackgroundFetchResult.newData
    }
}

extension AppDelegate: MessagingDelegate {
    @objc func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print(fcmToken)
    }

}
