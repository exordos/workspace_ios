//
//  ChatViewModel.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 24.02.2026.
//  
//

import SwiftUI
import Combine
import GiphyUISDK

final class ChatViewModel: ObservableObject {

    @Published private(set) var model: Chat
    private let apiClient: APIClient
    private var cancellables: Set<AnyCancellable> = []

    init(apiClient: APIClient, model: Chat) {
        self.apiClient = apiClient
        self.model = model
    }

    func sendMessage(with text: String) {
        apiClient.createPublisher(for: SendMessageRequest(type: model.isDirectMessages ? "direct" : "stream", to: model.chatId, content: text, topic: model.isDirectMessages ? nil : model.topic))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                // Success
            }
            .store(in: &cancellables)
    }
}
