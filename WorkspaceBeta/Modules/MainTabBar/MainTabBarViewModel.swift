//
//  MainTabBarViewModel.swift
//  WorkspaceBeta
//
//

import SwiftUI
import Combine

protocol MainTabBarViewModelProtocol {}

final class MainTabBarViewModel: MainTabBarViewModelProtocol, ObservableObject {

    private let apiClient: APIClient
    @Published private(set) var model: MainTabBar
    let userProfile: UserProfile
    let eventHandler: EventHandler

    lazy var voiceCallViewModel: VoiceCallViewModel = {
        let model = VoiceCall()
        return VoiceCallViewModel(apiClient: apiClient, model: model)
    }()

    lazy var mailViewModel: MailViewModel = {
        let model = Mail()
        return MailViewModel(apiClient: apiClient, model: model)
    }()

    lazy var calendarViewModel: CalendarViewModel = {
        let model = Calendar()
        return CalendarViewModel(apiClient: apiClient, model: model)
    }()

    lazy var chatChannelsViewModel: ChatChannelsViewModel = {
        let model = ChatChannels()
        return ChatChannelsViewModel(apiClient: apiClient, model: model, userProfile: userProfile, eventHandler: eventHandler)
    }()

    lazy var profileViewModel: ProfileViewModel = {
        let model = Profile()
        return ProfileViewModel(apiClient: apiClient, model: model, userProfile: userProfile)
    }()


    init(apiClient: APIClient, model: MainTabBar, userProfile: UserProfile) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
        self.eventHandler = EventHandler(apiClient: apiClient)
    }
}

extension MainTabBar.Tab {
    var image: Image {
        switch self {
        case .chat:
            return Image("chatTab")
        case .profile:
            return Image("profileTab")
        }
    }
}

