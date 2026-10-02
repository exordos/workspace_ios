//
//  ChatUserInfoViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class ChatUserInfoViewModel: ObservableObject {

    @Published private(set) var model: ChatUserInfo
    private let apiClient: APIClient

    init(apiClient: APIClient, model: ChatUserInfo) {
        self.apiClient = apiClient
        self.model = model
    }
}
