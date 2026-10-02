//
//  HomeMentionsViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class HomeMentionsViewModel: ObservableObject {

    @Published private(set) var model: HomeMentions
    private(set) var apiClient: APIClient
    let userProfile: UserProfile
    private(set) var eventHandler: EventHandler
    @Published var loadingState: LoadingState = .initialized

    @Published var users: [UserResponseData] = []

    private var cancellables: Set<AnyCancellable> = []

    init(apiClient: APIClient, model: HomeMentions, userProfile: UserProfile, eventHandler: EventHandler) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
        self.eventHandler = eventHandler

        subscribeToEvents()
    }

    func subscribeToEvents() {
        eventHandler.usersPublisher
            .assign(to: &$users)
    }

    func onAppear() {
        loadMentionedMessages()
    }

    func loadMentionedMessages() {
        loadingState = .loading
        apiClient.createPublisher(for: MentionedMessagesRequest())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] messagesResponse in
                guard let self else { return }
                let messagesWithAuthor = messagesResponse.map {
                    var messageWithAuthor = $0
                    let author = self.users.first(where: { $0.uuid == messageWithAuthor.authorUuid })
                    messageWithAuthor.author = author
                    return messageWithAuthor
                }
                model.messages = messagesWithAuthor
                loadingState = .loaded
            }
            .store(in: &cancellables)
    }
}
