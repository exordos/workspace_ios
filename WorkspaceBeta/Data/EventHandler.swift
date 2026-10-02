//
//  EventHandler.swift
//  WorkspaceBeta
//
//

import Foundation
import Combine

final class EventHandler {

    private var apiClient: APIClient
    let userProfile: UserProfile

    private var cancellables: Set<AnyCancellable> = []

    var meetUrl: String = ""

    var ownUser: UserResponseData?

    var loadingState: LoadingState = .initialized
    private var listenTask: Task<Void, Never>?

    private var messageReactions: [MessageReaction] = [] {
        didSet {
            messageReactionsSubject.send(messageReactions)
        }
    }

    private let messageReactionsSubject = CurrentValueSubject<[MessageReaction], Never>([])
    var messageReactionsPublisher: AnyPublisher<[MessageReaction], Never> {
        messageReactionsSubject.eraseToAnyPublisher()
    }

    private(set) var users: [UserResponseData] = [] {
        didSet {
            usersSubject.send(users)
        }
    }

    private let usersSubject = CurrentValueSubject<[UserResponseData], Never>([])
    var usersPublisher: AnyPublisher<[UserResponseData], Never> {
        usersSubject.eraseToAnyPublisher()
    }

    private var folders: [FolderResponseData] = [] {
        didSet {
            foldersSubject.send(folders)
        }
    }

    private let foldersSubject = CurrentValueSubject<[FolderResponseData], Never>([])
    var foldersPublisher: AnyPublisher<[FolderResponseData], Never> {
        foldersSubject.eraseToAnyPublisher()
    }

    private var streams: [StreamData] = [] {
        didSet {
            streamsSubject.send(streams)
        }
    }

    private let streamsSubject = CurrentValueSubject<[StreamData], Never>([])
    var streamsPublisher: AnyPublisher<[StreamData], Never> {
        streamsSubject.eraseToAnyPublisher()
    }

    private var topicsPool: [TopicsResponseData] = [] {
        didSet {
            topicsSubject.send(topicsPool)
        }
    }

    private let topicsSubject = CurrentValueSubject<[TopicsResponseData], Never>([])
    var topicsPublisher: AnyPublisher<[TopicsResponseData], Never> {
        topicsSubject.eraseToAnyPublisher()
    }

    func addTopicsToPool(_ topics: [TopicsResponseData]) {
        topicsPool.append(contentsOf: topics)
    }

    private var drafts: [DraftResponseData] = [] {
        didSet {
            draftsSubject.send(drafts)
        }
    }

    private let draftsSubject = CurrentValueSubject<[DraftResponseData], Never>([])
    var draftsPublisher: AnyPublisher<[DraftResponseData], Never> {
        draftsSubject.eraseToAnyPublisher()
    }

    private var messagePool: [MessageResponseData] = [] {
        didSet {
            messagePoolSubject.send(messagePool)
        }
    }

    private let messagePoolSubject = CurrentValueSubject<[MessageResponseData], Never>([])
    var messagePoolPublisher: AnyPublisher<[MessageResponseData], Never> {
        messagePoolSubject.eraseToAnyPublisher()
    }

    private var streamTopics: [String: [TopicsResponseData]] = [:] {
        didSet {
            streamTopicsSubject.send(streamTopics)
        }
    }

    private let streamTopicsSubject = CurrentValueSubject<[String: [TopicsResponseData]], Never>([:])
    var streamTopicsPublisher: AnyPublisher<[String: [TopicsResponseData]], Never> {
        streamTopicsSubject.eraseToAnyPublisher()
    }



    private var streamTopicMessages: [String: [MessageResponseData]] = [:] {
        didSet {
            streamTopicMessagesSubject.send(streamTopicMessages)
        }
    }

    private let streamTopicMessagesSubject = CurrentValueSubject<[String: [MessageResponseData]], Never>([:])
    var streamTopicMessagesPublisher: AnyPublisher<[String: [MessageResponseData]], Never> {
        streamTopicMessagesSubject.eraseToAnyPublisher()
    }



    init(apiClient: APIClient, userProfile: UserProfile) {
        self.apiClient = apiClient
        self.userProfile = userProfile
    }

    func setInitialMessageReactions(_ messageReactions: [MessageReaction]) {
        self.messageReactions = messageReactions
    }

    func addMessageReaction(_ messageReaction: MessageReaction) {
        if let ownUser, ownUser.uuid == messageReaction.userUuid {
            messageReactions.append(messageReaction)
        }
    }

    func deleteMessageReaction(_ messageReaction: MessageReaction) {
        guard let messageReactionToDeleteIndex = messageReactions.firstIndex( where: { $0.uuid == messageReaction.uuid }) else { return }
        messageReactions.remove(at: messageReactionToDeleteIndex)
    }

    func setInitialUsers(_ users: [UserResponseData]) {
        self.users = users
    }

    func addUser(_ user: UserResponseData) {
        users.append(user)
    }

    func updateUser(_ user: UserResponseData) {
        guard let userToUpdateIndex = users.firstIndex(where: { $0.uuid == user.uuid }) else { return }
        users[userToUpdateIndex].avatar = user.avatar
        users[userToUpdateIndex].email = user.email
        users[userToUpdateIndex].firstName = user.firstName
        users[userToUpdateIndex].lastName = user.lastName
        users[userToUpdateIndex].status = user.status
        users[userToUpdateIndex].statusEmoji = user.statusEmoji
        users[userToUpdateIndex].statusText = user.statusText
    }

    func setInitialFolders(_ folders: [FolderResponseData]) {
        self.folders = folders
    }

    func addFolder(_ folder: FolderResponseData) {
        folders.append(folder)
    }

    func updateFolder(_ folder: FolderResponseData) {
        guard let folderToUpdateIndex = folders.firstIndex(where: { $0.uuid == folder.uuid }) else { return }
        folders[folderToUpdateIndex].unreadCount = folder.unreadCount
        folders[folderToUpdateIndex].title = folder.title
        folders[folderToUpdateIndex].folderItems = folder.folderItems
    }

    func setInitialStreams(_ streams: [StreamData]) {
        self.streams = streams
    }

    func addStream(_ stream: StreamData) {
        streams.append(stream)
    }

    func updateStream(_ stream: StreamData) {
        guard let streamToUpdateIndex = streams.firstIndex(where: { $0.uuid == stream.uuid }) else { return }
        streams[streamToUpdateIndex].lastMessageUuid = stream.lastMessageUuid
        streams[streamToUpdateIndex].unreadCount = stream.unreadCount
        streams[streamToUpdateIndex].lastMessage = messagePool.first(where: { $0.uuid == stream.lastMessageUuid
        })
    }

    func setInitialDrafts(_ drafts: [DraftResponseData]) {
        self.drafts = drafts
    }

    func addDraft(_ draft: DraftResponseData) {
        drafts.append(draft)
    }

    func updateDraft(_ draft: DraftResponseData) {
        guard let draftToUpdateIndex = drafts.firstIndex(where: { $0.uuid == draft.uuid }) else { return }
        drafts[draftToUpdateIndex].payload = draft.payload
        drafts[draftToUpdateIndex].revision = draft.revision
    }

    func addTopics(_ topics: [TopicsResponseData], to streamUuid: String) {
        streamTopics[streamUuid] = topics
    }

    func addTopic(_ topic: TopicsResponseData) {
        if streamTopics[topic.streamUuid] != nil {
            streamTopics[topic.streamUuid]?.append(topic)
         }
    }

    func updateTopic(_ topic: TopicsResponseData) {
        if streamTopics[topic.streamUuid] != nil {
            guard let topicToUpdateIndex = streamTopics[topic.streamUuid]?.firstIndex(where: { $0.uuid == topic.uuid }) else { return }
            streamTopics[topic.streamUuid]?[topicToUpdateIndex].isDefault = topic.isDefault
            streamTopics[topic.streamUuid]?[topicToUpdateIndex].isDone = topic.isDone
            streamTopics[topic.streamUuid]?[topicToUpdateIndex].color = topic.color
            streamTopics[topic.streamUuid]?[topicToUpdateIndex].unreadCount = topic.unreadCount
            streamTopics[topic.streamUuid]?[topicToUpdateIndex].notificationMode = topic.notificationMode
            streamTopics[topic.streamUuid]?[topicToUpdateIndex].lastMessageUuid = topic.lastMessageUuid
            streamTopics[topic.streamUuid]?[topicToUpdateIndex].lastMessage = messagePool.first(where: { $0.uuid == topic.lastMessageUuid })
         }
    }

    func addTopicMessages(_ messages: [MessageResponseData], to streamUuid: String, and topicUuid: String) {
        let messagesWithAuthor = messages.map {
            var messageWithAuthor = $0
            let author = users.first(where: { $0.uuid == messageWithAuthor.authorUuid })
            messageWithAuthor.author = author
            return messageWithAuthor
        }
        streamTopicMessages["\(streamUuid).\(topicUuid)"] = messagesWithAuthor
    }

    func addMessageToStreamTopic(message: MessageResponseData) {
        let key = "\(message.streamUuid).\(message.topicUuid)"
        var messageWithAuthor = message
        let author = users.first(where: { $0.uuid == message.authorUuid })
        messageWithAuthor.author = author
        if streamTopicMessages[key] != nil {
            streamTopicMessages[key]?.append(messageWithAuthor)
        }
    }

    func updateMessageInStreamTopic(message: MessageResponseData) {
        let key = "\(message.streamUuid).\(message.topicUuid)"
        if streamTopicMessages[key] != nil {
            guard let messageToUpdateIndex = streamTopicMessages[key]?.firstIndex(where: { $0.uuid == message.uuid }) else { return }
            streamTopicMessages[key]?[messageToUpdateIndex].payload = message.payload
            streamTopicMessages[key]?[messageToUpdateIndex].reactions = message.reactions
         }
    }

    func setInitialMessagePool(_ messagePool: [MessageResponseData]) {
        let messagesWithAuthor = messagePool.map {
            var messageWithAuthor = $0
            let author = users.first(where: { $0.uuid == messageWithAuthor.authorUuid })
            messageWithAuthor.author = author
            return messageWithAuthor
        }
        self.messagePool = messagesWithAuthor
    }

    func addMessagesToPool(_ newMessages: [MessageResponseData]) {
        let messagesWithAuthor = newMessages.map {
            var messageWithAuthor = $0
            let author = users.first(where: { $0.id == messageWithAuthor.streamUuid })
            messageWithAuthor.author = author
            return messageWithAuthor
        }
        self.messagePool += messagesWithAuthor
    }

    func updateMessageInPool(_ message: MessageResponseData) {
        guard let messageToUpdateIndex = messagePool.firstIndex(where: { $0.uuid == message.uuid }) else { return }
        messagePool[messageToUpdateIndex].payload = message.payload
        messagePool[messageToUpdateIndex].reactions = message.reactions
    }


    func loadServerSettings() {
        loadingState = .loading
        apiClient.createPublisher(for: ServerSettingsRequest(with: userProfile.selectedServer?.baseUrl ?? ""))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
                self?.loadingState = .loaded
            } receiveValue: { [weak self] response in
                guard let self else { return }
                meetUrl = response.meetUrl
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
                self?.ownUser = response
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
                self?.setInitialMessageReactions(response)
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
                self?.setInitialUsers(response)
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
                self?.setInitialFolders(sortedFolders)
//                if self?.currentlySelectedFolder == nil {
//                    self?.currentlySelectedFolder = sortedFolders.first
//                }
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
                        self.setInitialMessagePool(messagesResponse)
                        let streamsWithMessages = response.map { stream in
                            var streamWithMessage = stream
                            let message = self.messagePool.first(where: { message in
                                message.uuid == stream.lastMessageUuid
                            })
                            let user = self.users.first { user in
                                user.uuid == stream.directUserUuid
                            }
                            streamWithMessage.directUser = user
                            streamWithMessage.lastMessage = message
                            return streamWithMessage
                        }
                        self.setInitialStreams(streamsWithMessages)
                        self.loadDrafts()
                    }
                    .store(in: &cancellables)
            }
            .store(in: &cancellables)
    }

    func loadDrafts() {
        apiClient.createPublisher(for: DraftsRequest())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                self?.setInitialDrafts(response)
                self?.start()
            }
            .store(in: &cancellables)
    }

    func start() {
        apiClient.createPublisher(for: EpochRequest())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                self?.startWebsocket(epochVersion: response.epochVersion, epochGeneration: response.epochGeneration)
            }
            .store(in: &cancellables)
    }

    func startWebsocket(epochVersion: Int, epochGeneration: String) {
        apiClient.createWebSocketTask(epochVersion: String(epochVersion), epochGeneration: epochGeneration)
        listenTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await message in self.apiClient.messages() {
                    switch message {
                    case .string(let text):
                        parse(eventData: Data(text.utf8))
                    case .data(let data):
                        print("Received \(data.count) bytes")
                    @unknown default:
                        break
                    }
                }
            } catch {
                print("Receive failed: \(error)")
            }
        }
    }

    func parse(eventData: Data) {
        let decoder = JSONDecoder()
        guard let event = try? decoder.decode(ReceivedEvent.self, from: eventData) else { return }
        switch event.objectType {
        case .message:
            didReceiveMessageEvent(eventData: eventData, action: event.action)
        case .stream:
            didReceiveStreamEvent(eventData: eventData, action: event.action)
        case .topic:
            didReceiveTopicEvent(eventData: eventData, action: event.action)
        default:
            break
        }
    }

    func didReceiveMessageEvent(eventData: Data, action: ReceivedEventAction) {
        switch action {
        case .updated:
            if let message = try? payload(MessageResponseData.self, data: eventData) {
                updateMessageInStreamTopic(message: message)
                updateMessageInPool(message)
            }
        case .created:
            if let message = try? payload(MessageResponseData.self, data: eventData) {
                addMessageToStreamTopic(message: message)
                addMessagesToPool([message])
            }
        case .deleted:
            break
        }
    }

    func didReceiveStreamEvent(eventData: Data, action: ReceivedEventAction) {
        switch action {
        case .updated:
            if let stream = try? payload(StreamData.self, data: eventData) {
                updateStream(stream)
            }
        case .created:
            if let stream = try? payload(StreamData.self, data: eventData) {
                addStream(stream)
            }
        case .deleted:
            break
        }
    }

    func didReceiveTopicEvent(eventData: Data, action: ReceivedEventAction) {
        switch action {
        case .updated:
            if let topic = try? payload(TopicsResponseData.self, data: eventData) {
                updateTopic(topic)
            }
        case .created:
            if let topic = try? payload(TopicsResponseData.self, data: eventData) {
                addTopic(topic)
                addTopicsToPool([topic])
            }
        case .deleted:
            break
        }
    }

    func payload<T: Decodable>(_ type: T.Type, data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PayloadBox<T>.self, from: data).payload
    }
}

enum ReceivedEventAction: String, Decodable {
    case updated
    case created
    case deleted
}

enum ReceivedEventObjectType: String, Decodable {
    case message
    case user
    case folder
    case stream
    case topic
    case messageReaction = "message_reaction"
}

struct ReceivedEvent: Decodable {
    let objectType: ReceivedEventObjectType
    let action: ReceivedEventAction

    enum CodingKeys: String, CodingKey {
        case objectType = "object_type"
        case action
    }
}

private struct PayloadBox<T: Decodable>: Decodable {
    let payload: T
}
