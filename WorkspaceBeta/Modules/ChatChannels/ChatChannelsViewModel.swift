//
//  ChatChannelsViewModel.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 25.03.2026.
//  
//

import SwiftUI
import Combine

final class ChatChannelsViewModel: ObservableObject {

    @Published private(set) var model: ChatChannels
    private let apiClient: APIClient
    @Published var loadingState: LoadingState = .initialized
    let userProfile: UserProfile

    private var cancellables: Set<AnyCancellable> = []

    init(apiClient: APIClient, model: ChatChannels, userProfile: UserProfile) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
    }

    func onAppear() {
        if loadingState == .initialized {
            loadInitialData()
        }
    }

    func loadInitialData() {
        let messagesRequest = MessagesRequest(anchor: "newest", numBefore: "100", numAfter: "0", narrow: "[{\"operand\": \"dm\", \"operator\": \"is\"}]", applyMarkdown: "false")
        apiClient.createPublisher(for: messagesRequest)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                let recipientArrays = response.messages.compactMap { message -> [DisplayRecipient]? in
                    switch message {
                    case let .channel(channelMessageData):
                        return nil
                    case let .direct(directMessageData):
                        return directMessageData.displayRecipient
                    }
                }
                let recipients = recipientArrays.flatMap { $0 }
                let currentUserId = self?.userProfile.userId ?? 0
                let uniqueRecipients = Array(Set(recipients)).filter { $0.id != currentUserId }
                self?.model.chatHeaders.append(contentsOf: uniqueRecipients.map { ChatHeader(recipient: $0, currentUserId: "\(currentUserId)") })
            }
            .store(in: &cancellables)
    }
}

struct ChatHeader: Hashable {
    let title: String
    let gravatar: String?
    let streamId: String
    let lastMessageFullName: String?
    let lastMessageContent: String?
    let isDirectMessages: Bool
}

extension ChatHeader {
    init(from subscription: SubscriptionData) {
        self.title = subscription.name
        self.gravatar = nil
        self.streamId = "\(subscription.streamId)"
        self.lastMessageFullName = nil
        self.lastMessageContent = nil
        self.isDirectMessages = false
    }

    init(recipient: DisplayRecipient, currentUserId: String, lastMessageFullName: String? = nil, lastMessageContent: String? = nil) {
        self.title = recipient.fullName
        self.gravatar = nil
        self.streamId  = "[\(recipient.id), \(currentUserId)]"
        self.lastMessageFullName = lastMessageFullName
        self.lastMessageContent = lastMessageContent
        self.isDirectMessages = true
    }
}
