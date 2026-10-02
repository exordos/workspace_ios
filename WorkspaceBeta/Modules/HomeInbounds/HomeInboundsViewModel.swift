//
//  HomeInboundsViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class HomeInboundsViewModel: ObservableObject {

    @Published private(set) var model: HomeInbounds
    private(set) var apiClient: APIClient
    let userProfile: UserProfile
    private(set) var eventHandler: EventHandler
    @Published var loadingState: LoadingState = .initialized

    private var cancellables: Set<AnyCancellable> = []

    @Published var streams: [StreamData] = []
    @Published var streamTopics: [String:[TopicsResponseData]] = [:]
    @Published var poolMessages: [MessageResponseData] = []

    init(apiClient: APIClient, model: HomeInbounds, userProfile: UserProfile, eventHandler: EventHandler) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
        self.eventHandler = eventHandler

        subscribeToEvents()
    }

    func subscribeToEvents() {
        eventHandler.streamsPublisher
            .assign(to: &$streams)
        eventHandler.streamTopicsPublisher
            .assign(to: &$streamTopics)
        eventHandler.messagePoolPublisher
            .assign(to: &$poolMessages)
    }

    func onAppear() {

        loadingState = .loading

        let unreadStreamUuids = streams.filter { $0.activeUnreadCount > 0 }.map { $0.uuid }
        let streamWithLoadedTopicsUuids = Array(streamTopics.keys)
        let unreadStreamUuidsToLoadTopics = unreadStreamUuids.filter {  !streamWithLoadedTopicsUuids.contains($0) }
        if unreadStreamUuidsToLoadTopics.count > 0 {
            loadTopics(for: unreadStreamUuidsToLoadTopics)
        } else {
            loadingState = .loaded
        }
    }

    func loadTopics(for streamUuids: [String]) {
        apiClient.createPublisher(for: TopicsRequest(streamUuid: streamUuids))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.loadingState = .loaded
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                for streamUuid in streamUuids {
                    let messageIds = response.compactMap { $0.lastMessageUuid }
                    apiClient.createPublisher(for: MessagesByIdsRequest(messageIds: messageIds))
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] completion in
                            if case let .failure(error) = completion {
                                self?.loadingState = .loaded
                            }
                        } receiveValue: { [weak self] messagesResponse in
                            guard let self else { return }
                            self.eventHandler.addMessagesToPool(messagesResponse)
                            let topicsWithMessages = response.map { topic in
                                var topicWithMessage = topic
                                let message = self.poolMessages.first(where: { message in
                                    message.uuid == topic.lastMessageUuid
                                })
                                topicWithMessage.lastMessage = message
                                return topicWithMessage
                            }
                            self.eventHandler.addTopics(topicsWithMessages, to: streamUuid)
                            self.eventHandler.addTopicsToPool(topicsWithMessages)
                            self.loadingState = .loaded
                        }
                        .store(in: &cancellables)
                }
            }
            .store(in: &cancellables)
    }
}
