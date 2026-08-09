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
    private let apiClient: APIClient
    let userProfile: UserProfile

    init(apiClient: APIClient, model: Profile, userProfile: UserProfile) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
    }

    func logout() {
        userProfile.clearData()
    }
}
