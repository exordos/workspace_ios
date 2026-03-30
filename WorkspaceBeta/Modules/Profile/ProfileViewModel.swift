//
//  ProfileViewModel.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 28.03.2026.
//  
//

import SwiftUI
import Combine

final class ProfileViewModel: ObservableObject {

    @Published private(set) var model: Profile
    private let apiClient: APIClient

    init(apiClient: APIClient, model: Profile) {
        self.apiClient = apiClient
        self.model = model
    }
}
