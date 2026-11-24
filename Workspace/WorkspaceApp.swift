//
//  WorkspaceApp.swift
//  Workspace
//
//

import SwiftUI
import SwiftData
import JitsiMeetSDK
import FirebaseCore
import UserNotifications

@main
struct WorkspaceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ServerConfig.self,
            EncryptedChatKey.self,
            MessageData.self,
            StreamData.self,
            TopicData.self,
            UserData.self,
            DraftData.self,
            FolderData.self,
            FolderItemData.self,
            LastMessageData.self,
            MessageReactionData.self,
            StreamBindingData.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject var userProfile: UserProfile
    @Environment(\.scenePhase) private var scenePhase

    var viewModel: WorkspaceAppViewModel

    var body: some Scene {
        WindowGroup {
            mainView
                .task(id: userProfile.pushSession) {
                    PushNotifications.shared.synchronize()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        PushNotifications.shared.synchronize()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    init() {
        let userProfile = UserProfile(context: sharedModelContainer.mainContext)
        self._userProfile = StateObject(wrappedValue: userProfile)
        WorkspaceAPIClient().userProfile = userProfile
        PushNotifications.shared.profile = userProfile
        self.viewModel = WorkspaceAppViewModel(with: WorkspaceAPIClient.current, userProfile: userProfile)
    }

    private var mainView: some View {
        Group {
            if userProfile.serverConfigs.isEmpty {
                ChooseServerAssembly().assemble(with: userProfile)
            } else if userProfile.selectedServer?.projectUuid == nil {
                LogInAssembly().assemble(with: userProfile)
            } else {
                MainTabBarAssembly().assemble(with: viewModel.mainTabBarViewModel)
            }
        }
        .background(Color.background)
    }
}

class WorkspaceAppViewModel {

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
        UNUserNotificationCenter.current().delegate = self

        return JitsiMeet.sharedInstance().application(
            application,
            didFinishLaunchingWithOptions: launchOptions ?? [:]
        )
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotifications.shared.receivedDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        await PushNotifications.shared.processReadUpdate(userInfo) ? .newData : .noData
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        if await PushNotifications.shared.canPresent(userInfo) {
            return [.banner, .list, .sound]
        }
        return []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        await PushNotifications.shared.open(response.notification.request.content.userInfo)
    }
}
