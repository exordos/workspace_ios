//
//  OwnUserSettingsViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class OwnUserSettingsViewModel: ObservableObject {

    @Published private(set) var model: OwnUserSettings
    private let apiClient: APIClient

    init(apiClient: APIClient, model: OwnUserSettings) {
        self.apiClient = apiClient
        self.model = model
    }
}
