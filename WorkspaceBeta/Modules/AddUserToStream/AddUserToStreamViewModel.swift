//
//  AddUserToStreamViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class AddUserToStreamViewModel: ObservableObject {

    @Published private(set) var model: AddUserToStream
    private let apiClient: APIClient

    init(apiClient: APIClient, model: AddUserToStream) {
        self.apiClient = apiClient
        self.model = model
    }
}
