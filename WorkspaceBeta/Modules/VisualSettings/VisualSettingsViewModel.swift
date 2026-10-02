//
//  VisualSettingsViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class VisualSettingsViewModel: ObservableObject {

    @Published private(set) var model: VisualSettings
    private let apiClient: APIClient

    init(apiClient: APIClient, model: VisualSettings) {
        self.apiClient = apiClient
        self.model = model
    }
}
