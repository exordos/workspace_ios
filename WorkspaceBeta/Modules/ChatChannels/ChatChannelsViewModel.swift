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
    @Published var selectedStream: StreamData?
    @Published var loadedTopics: [TopicData] = []
    @Published var poolMessages: [MessageResponseData] = []
    @Published var streamTopics: [String: [TopicResponseData]] = [:]
    @Published var streamBindings: [String: [StreamBindingResponseData]] = [:]
    @Published var errorViewModel: FullScreenErrorViewModel?


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
        eventHandler.loadingStatePublisher
            .assign(to: &$loadingState)

        eventHandler.initialLoadingErrorPublisher
            .assign(to: &$errorViewModel)
    }

    func onTap(on stream: StreamData) {
        loadedTopics = stream.topics
//        if streamBindings[stream.uuid] != nil {
//            if let topics = streamTopics[stream.uuid] {
//                loadedTopics = stream.topics
//            } else {
//                loadTopics(for: stream)
//            }
//        } else {
//            loadBindings(for: stream)
//        }
    }

    func setNextNotificationMode(for topic: TopicData) {
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
