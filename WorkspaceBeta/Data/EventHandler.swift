//
//  EventHandler.swift
//  WorkspaceBeta
//
//

import Foundation
import Combine

final class EventHandler {

    private var apiClient: APIClient

    private var cancellables: Set<AnyCancellable> = []

    var meetUrl: String = ""

    var ownUser: UserResponseData?

    private var messageReactions: [MessageReaction] = [] {
        didSet {
            messageReactionsSubject.send(messageReactions)
        }
    }

    private let messageReactionsSubject = CurrentValueSubject<[MessageReaction], Never>([])
    var messageReactionsPublisher: AnyPublisher<[MessageReaction], Never> {
        messageReactionsSubject.eraseToAnyPublisher()
    }

    private var users: [UserResponseData] = [] {
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



    init(apiClient: APIClient) {
        self.apiClient = apiClient
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
            streamTopics[topic.streamUuid]?[topicToUpdateIndex].lastMessageUuid = topic.lastMessageUuid
            streamTopics[topic.streamUuid]?[topicToUpdateIndex].lastMessage = messagePool.first(where: { $0.uuid == topic.lastMessageUuid })
         }
    }

    func addTopicMessagess(_ messages: [MessageResponseData], to streamUuid: String, and topicUuid: String) {
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

    func addMessageInStreamTopic(message: MessageResponseData) {
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


    @objc func loadNewEvents() {
//        guard let queueId else { return }
//        apiClient.createPublisher(for: EventsRequest(queueId: queueId, lastEventId: "\(lastEventId)"))
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] completion in
//                if case let .failure(error) = completion {
//                    // Error
//                }
//            } receiveValue: { [weak self] response in
//                let newMessages = response.events.compactMap {
//                    switch $0 {
//                    case let .message(messageEvent):
//                        return messageEvent.message
//                    default:
//                        return nil
//                    }
//                }
//                self?.messages = newMessages
//                self?.newMessagesSubject.send(newMessages)
//            }
//            .store(in: &cancellables)
    }

}
