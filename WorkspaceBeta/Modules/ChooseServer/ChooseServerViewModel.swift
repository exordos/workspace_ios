//
//  ChooseServerViewModel.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 25.03.2026.
//  
//

import SwiftUI
import Combine

final class ChooseServerViewModel: ObservableObject {

    @Published var model: ChooseServer
    private let apiClient: APIClient
    let userProfile: UserProfile

    init(apiClient: APIClient, model: ChooseServer, userProfile: UserProfile) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
    }

    let baseUrlFieldViewModel = CommonInputViewModel(with: "Ссылка на организацию", isRequired: false, keyBoardType: .emailAddress, textContentType: .username)

    func setDefaultServerUrl() {
        model.baseUrl = "https://workspace.genesis-core.tech"
    }

    func applyBaseServerUrl() {
        userProfile.baseUrl = model.baseUrl
    }
}
