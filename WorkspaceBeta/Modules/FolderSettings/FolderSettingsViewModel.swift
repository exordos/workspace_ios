//
//  FolderSettingsViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class FolderSettingsViewModel: ObservableObject {

    @Published private(set) var model: FolderSettings
    private let apiClient: APIClient

    init(apiClient: APIClient, model: FolderSettings) {
        self.apiClient = apiClient
        self.model = model
    }
}
