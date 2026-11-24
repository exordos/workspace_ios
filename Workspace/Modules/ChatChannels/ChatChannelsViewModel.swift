//
//  ChatChannelsViewModel.swift
//  Workspace
//
//  
//

import SwiftUI
import Combine

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
    @Published var notificationDestination: ChatNavigationDestination?


    private var cancellables: Set<AnyCancellable> = []

    init(apiClient: APIClient, model: ChatChannels, userProfile: UserProfile, eventHandler: EventHandler) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
        self.eventHandler = eventHandler

        subscribeToEvents()
    }

    func openNotification(_ route: PushEnvelope) async -> Bool {
        guard let scope = userProfile.pushSession, scope.projectUuid == route.projectUuid,
              let messageUuid = route.messageUuid else { return false }
        let base = "\(scope.baseUrl)/api/workspace/v1/messenger"
        do {
            guard let user = try await apiClient.createPublisher(for: OwnUserRequest())
                .values.first(where: { _ in true }), user.uuid.lowercased() == route.userUuid,
                  scope == userProfile.pushSession, !Task.isCancelled else { return false }
            let streamRequest = PushRouteRequest<StreamResponseData>(resource: .absolute("\(base)/streams/\(route.streamUuid)"))
            let topicRequest = PushRouteRequest<TopicResponseData>(resource: .absolute("\(base)/stream_topics/\(route.topicUuid)"))
            let messageRequest = PushRouteRequest<MessageResponseData>(resource: .absolute("\(base)/messages/\(messageUuid)"))
            let target = Publishers.Zip3(
                apiClient.createPublisher(for: streamRequest),
                apiClient.createPublisher(for: topicRequest),
                apiClient.createPublisher(for: messageRequest)
            )
            guard let (stream, topic, message) = try await target.values.first(where: { _ in true }),
                  scope == userProfile.pushSession, !Task.isCancelled,
                  stream.uuid == route.streamUuid, topic.uuid == route.topicUuid,
                  topic.streamUuid == stream.uuid, message.uuid == messageUuid,
                  message.streamUuid == stream.uuid, message.topicUuid == topic.uuid else { return false }

            eventHandler.updateStream(stream)
            eventHandler.addTopic(topic)
            eventHandler.addMessages([message], streamUuid: stream.uuid, topicUuid: topic.uuid)
            notificationDestination = .messages(stream.uuid, topic.uuid, stream.isPrivate, anchor: message.uuid)
            return true
        } catch {
            return false
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
        case .default, .unmute:
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
