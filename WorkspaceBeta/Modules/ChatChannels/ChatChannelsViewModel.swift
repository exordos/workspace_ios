//
//  ChatChannelsViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine
import FirebaseMessaging

final class ChatChannelsViewModel: ObservableObject {

    @Published private(set) var model: ChatChannels
    @Published var loadingState: LoadingState = .initialized
    @Published var folders: [FolderResponseData] = []
    @Published var currentlySelectedFolder: FolderResponseData?
    private(set) var apiClient: APIClient
    let userProfile: UserProfile
    private(set) var eventHadler: EventHandler
    private var loadedSubscriptions: [StreamData] = []
    @Published var selectedStream: StreamData?
    @Published var loadedTopics: [TopicsResponseData] = []
    @Published var streams: [StreamData] = []
    @Published var poolMessages: [MessageResponseData] = []
    @Published var users: [UserResponseData] = []
    @Published var streamTopics: [String: [TopicsResponseData]] = [:]


    private var cancellables: Set<AnyCancellable> = []

    init(apiClient: APIClient, model: ChatChannels, userProfile: UserProfile, eventHandler: EventHandler) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
        self.eventHadler = eventHandler

        subscribeToEvents()
    }

    func onAppear() {
        if loadingState == .initialized {
            loadServerSettings()
            //            if let token = Messaging.messaging().fcmToken {
            //                apiClient.createPublisher(for: SendFcmTokenRequest(token: "workspace:apple:\(token)"))
            //                    .receive(on: DispatchQueue.main)
            //                    .sink { _ in
            //                    } receiveValue: { _ in
            //                    }
            //                    .store(in: &cancellables)
            //            }
        }
    }

    func subscribeToEvents() {
        eventHadler.streamsPublisher
            .assign(to: &$streams)

        eventHadler.messagePoolPublisher
            .assign(to: &$poolMessages)

        eventHadler.usersPublisher
            .assign(to: &$users)

        eventHadler.streamTopicsPublisher
            .assign(to: &$streamTopics)
    }

    func loadServerSettings() {
        loadingState = .loading
        apiClient.createPublisher(for: ServerSettingsRequest(with: userProfile.baseUrl ?? ""))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
                self?.loadingState = .loaded
            } receiveValue: { [weak self] response in
                guard let self else { return }
                eventHadler.meetUrl = response.meetUrl
                loadOwnUser()
            }
            .store(in: &cancellables)
    }

    func loadOwnUser() {
        apiClient.createPublisher(for: OwnUserRequest())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                self?.eventHadler.ownUser = response
                self?.loadUsers()
            }
            .store(in: &cancellables)
    }

    func loadMessageReactions(for userUuid: String) {
        apiClient.createPublisher(for: MessageReactionsRequest(userUuid: userUuid))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                self?.eventHadler.setInitialMessageReactions(response)
                self?.loadUsers()
            }
            .store(in: &cancellables)
    }

    func loadUsers() {
        loadingState = .loading
        apiClient.createPublisher(for: UsersRequest())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                self?.eventHadler.setInitialUsers(response)
                self?.loadFolders()
            }
            .store(in: &cancellables)
    }

    func loadFolders() {
        apiClient.createPublisher(for: FoldersRequest())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                let sortedFolders = response.sorted { $0.createdAt < $1.createdAt
                }
                self?.eventHadler.setInitialFolders(sortedFolders)
                if self?.currentlySelectedFolder == nil {
                    self?.currentlySelectedFolder = sortedFolders.first
                }
                self?.loadSubscribedStreams()
            }
            .store(in: &cancellables)
    }

    func loadSubscribedStreams() {
        apiClient.createPublisher(for: StreamsRequest())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                let messageIds = response.compactMap { $0.lastMessageUuid }
                apiClient.createPublisher(for: MessagesByIdsRequest(messageIds: messageIds))
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] completion in
                        if case let .failure(error) = completion {
                            // Error
                        }
                    } receiveValue: { [weak self] messagesResponse in
                        guard let self else { return }
                        self.eventHadler.setInitialMessagePool(messagesResponse)
                        let streamsWithMessages = response.map { stream in
                            var streamWithMessage = stream
                            let message = self.poolMessages.first(where: { message in
                                message.uuid == stream.lastMessageUuid
                            })
                            streamWithMessage.lastMessage = message
                            return streamWithMessage
                        }
                        self.eventHadler.setInitialStreams(streamsWithMessages)
                    }
                    .store(in: &cancellables)
            }
            .store(in: &cancellables)
    }

    func onTap(on stream: StreamData) {
        if let topics = streamTopics[stream.uuid] {
            loadedTopics = topics
        } else {
            loadTopics(for: stream)
        }
    }

    func loadTopics(for stream: StreamData) {
        loadedTopics.removeAll()
        apiClient.createPublisher(for: TopicsRequest(streamUuid: stream.uuid))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                let messageIds = response.compactMap { $0.lastMessageUuid }
                apiClient.createPublisher(for: MessagesByIdsRequest(messageIds: messageIds))
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] completion in
                        if case let .failure(error) = completion {
                            // Error
                        }
                    } receiveValue: { [weak self] messagesResponse in
                        guard let self else { return }
                        self.eventHadler.setInitialMessagePool(messagesResponse)
                        let topicsWithMessages = response.map { topic in
                            var topicWithMessage = topic
                            let message = self.poolMessages.first(where: { message in
                                message.uuid == topic.lastMessageUuid
                            })
                            topicWithMessage.lastMessage = message
                            return topicWithMessage
                        }
                        self.eventHadler.addTopics(topicsWithMessages, to: stream.uuid)
                        loadedTopics = topicsWithMessages
                    }
                    .store(in: &cancellables)
            }
            .store(in: &cancellables)
    }
}
