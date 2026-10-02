//
//  AddFolderViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class AddFolderViewModel: ObservableObject {

    @Published private(set) var model: AddFolder
    private let apiClient: APIClient

    init(apiClient: APIClient, model: AddFolder) {
        self.apiClient = apiClient
        self.model = model
    }
}
