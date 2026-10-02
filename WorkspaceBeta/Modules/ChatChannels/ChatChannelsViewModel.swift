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
    private(set) var eventHandler: EventHandler
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
        self.eventHandler = eventHandler

        subscribeToEvents()
    }

    func onAppear() {
        if loadingState == .initialized {
//            eventHandler.loadServerSettings()
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
        eventHandler.streamsPublisher
            .assign(to: &$streams)

        eventHandler.messagePoolPublisher
            .assign(to: &$poolMessages)

        eventHandler.usersPublisher
            .assign(to: &$users)

        eventHandler.streamTopicsPublisher
            .assign(to: &$streamTopics)
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
        apiClient.createPublisher(for: TopicsRequest(streamUuid: [stream.uuid]))
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
                        self.eventHandler.setInitialMessagePool(messagesResponse)
                        let topicsWithMessages = response.map { topic in
                            var topicWithMessage = topic
                            let message = self.poolMessages.first(where: { message in
                                message.uuid == topic.lastMessageUuid
                            })
                            topicWithMessage.lastMessage = message
                            return topicWithMessage
                        }
                        self.eventHandler.addTopics(topicsWithMessages, to: stream.uuid)
                        self.eventHandler.addTopicsToPool(topicsWithMessages)
                        loadedTopics = topicsWithMessages
                    }
                    .store(in: &cancellables)
            }
            .store(in: &cancellables)
    }

    func setNextNotificationMode(for topic: TopicsResponseData) {
        let nextNotificationMode: TopicNotificationMode = switch topic.notificationMode {
        case .mute:
                .default
        case .default:
                .follow
        case .follow:
                .mute
        }
        setTopicNotificationMode(topicUuid: topic.uuid, notificationMode: nextNotificationMode.rawValue)
    }

    func setTopicNotificationMode(topicUuid: String, notificationMode: String) {
        apiClient.createPublisher(for: UpdateTopicNotificationModeRequest(topicUuid: topicUuid, notificationMode: notificationMode))
            .receive(on: DispatchQueue.main)
            .sink {  _ in } receiveValue: {  _ in }
            .store(in: &cancellables)
    }

}
