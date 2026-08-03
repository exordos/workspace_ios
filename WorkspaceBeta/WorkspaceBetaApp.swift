import SwiftUI
import JitsiMeetSDK

@main
struct WorkspaceBetaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appModel = WorkspaceAppModel()

    var body: some Scene {
        WindowGroup {
            WorkspaceRootView()
                .environment(appModel)
                .task { await appModel.restore() }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG
        application.isIdleTimerDisabled = true
        #endif

        let defaultOptions = JitsiMeetConferenceOptions.fromBuilder { builder in
            builder.serverURL = URL(string: "https://meet.genesis-core.tech")
            builder.setFeatureFlag("welcomepage.enabled", withValue: false)
        }
        JitsiMeet.sharedInstance().defaultConferenceOptions = defaultOptions

        WorkspacePushNotifications.shared.configure()

        if let launchOptions {
            _ = JitsiMeet.sharedInstance().application(
                application,
                didFinishLaunchingWithOptions: launchOptions
            )
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        WorkspacePushNotifications.shared.receiveAPNSToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let payload = WorkspacePushPayload(userInfo: userInfo)
        Task { @MainActor in
            let result = await WorkspacePushNotifications.shared.handleRemoteNotification(payload)
            completionHandler(result)
        }
    }
}
