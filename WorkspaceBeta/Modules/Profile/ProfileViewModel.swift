//
//  ProfileViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class ProfileViewModel: ObservableObject {

    @Published private(set) var model: Profile
    private(set) var apiClient: APIClient
    let userProfile: UserProfile
    private(set) var eventHandler: EventHandler

    @Published var path = NavigationPath()

    init(apiClient: APIClient, model: Profile, userProfile: UserProfile, eventHandler: EventHandler) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
        self.eventHandler = eventHandler
    }

    func logout() {
        userProfile.selectedServer?.projectUuid = nil
    }
}
