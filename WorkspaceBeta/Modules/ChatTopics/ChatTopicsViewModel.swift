//
//  ChatTopicsViewModel.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 25.03.2026.
//  
//

import SwiftUI
import Combine

final class ChatTopicsViewModel: ObservableObject {

    @Published private(set) var model: ChatTopics
    private let apiClient: APIClient

    init(apiClient: APIClient, model: ChatTopics) {
        self.apiClient = apiClient
        self.model = model
    }
}
