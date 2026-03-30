//
//  WorkspaceBetaApp.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 19.02.2026.
//

import SwiftUI
import SwiftData
import JitsiMeetSDK

enum LoadingState {
    case initialized
    case loading
    case loaded
    case error
}

@main
struct WorkspaceBetaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject var userProfile = UserProfile()

    var viewModel: WorkspaceBetaAppViewModel = {
        WorkspaceAPIClient.init(with: URLSession.shared)
        let viewModel = WorkspaceBetaAppViewModel(with: WorkspaceAPIClient.current)
        return viewModel
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if userProfile.apiKey == nil {
                    ChooseServerAssembly().assemble(with: userProfile)
                } else {
                    MainTabBarAssembly().assemble(with: viewModel.mainTabBarViewModel)
                }
            }
            .onAppear {
                WorkspaceAPIClient.current.userProfile = userProfile
                viewModel.userProfile = userProfile
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

class WorkspaceBetaAppViewModel {

    let apiClient: APIClient
    var userProfile: UserProfile?

    lazy var mainTabBarViewModel: MainTabBarViewModel = {
        let model = MainTabBar()
        let profile = userProfile
        return MainTabBarViewModel(apiClient: apiClient, model: model, userProfile: userProfile ?? UserProfile())
    }()

    init(with apiClient: APIClient) {
        self.apiClient = apiClient
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: ContentView())
        window.makeKeyAndVisible()
        self.window = window

        let defaultOptions = JitsiMeetConferenceOptions.fromBuilder { (builder) in
            builder.serverURL = URL(string: "https://meet.genesis-core.tech")
            builder.setFeatureFlag("welcomepage.enabled", withValue: false)
        }
        JitsiMeet.sharedInstance().defaultConferenceOptions = defaultOptions

        guard let launchOptions = launchOptions else { return false }
        return JitsiMeet.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
