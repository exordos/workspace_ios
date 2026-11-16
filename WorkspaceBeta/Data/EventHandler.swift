//
//  EventHandler.swift
//  WorkspaceBeta
//
//

import Foundation
import Combine
import SwiftData

final class EventHandler {

    struct InitialLoadingData {
        let streams: [StreamResponseData]
        let topics: [TopicResponseData]
        let streamBindings: [StreamBindingResponseData]
        let users: [UserResponseData]
        var folders: [FolderResponseData]
        var drafts: [DraftResponseData]
        var messageReactions: [MessageReactionResponseData]
        var messages: [MessageResponseData]
    }

    private var apiClient: APIClient
    let userProfile: UserProfile

    private var cancellables: Set<AnyCancellable> = []

    var meetUrl: String = ""

    var ownUser: UserResponseData?

    var loadingState: LoadingState = .initialized {
        didSet {
            loadingStateSubject.send(loadingState)
        }
    }

    private let loadingStateSubject = CurrentValueSubject<LoadingState, Never>(.initialized)
    var loadingStatePublisher: AnyPublisher<LoadingState, Never> {
        loadingStateSubject.eraseToAnyPublisher()
    }

    var initialLoadingErrorViewModel: FullScreenErrorViewModel? {
        didSet {
            initialLoadingErrorSubject.send(initialLoadingErrorViewModel)
        }
    }

    private let initialLoadingErrorSubject = CurrentValueSubject<FullScreenErrorViewModel?, Never>(nil)
    var initialLoadingErrorPublisher: AnyPublisher<FullScreenErrorViewModel?, Never> {
        initialLoadingErrorSubject.eraseToAnyPublisher()
    }

    private var listenTask: Task<Void, Never>?

    init(apiClient: APIClient, userProfile: UserProfile) {
        self.apiClient = apiClient
        self.userProfile = userProfile
    }

    func shouldRequestEncryptionKey(for stream: StreamData) -> Bool {
        guard stream.hasEncryption, let selectedServer = userProfile.selectedServer else { return false }
        return !selectedServer.encryptedChatKeys.contains { $0.uuid.lowercased() == stream.currentEncryptionKeyUuid?.lowercased() }
    }

    func loadServerSettings() {
        initialLoadingErrorViewModel = nil
        loadingState = .loading
        apiClient.createPublisher(for: ServerSettingsRequest(with: userProfile.selectedServer?.baseUrl ?? ""))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.initialLoadingFailed()
                }
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
                    self?.initialLoadingFailed()
                }
            } receiveValue: { [weak self] response in
                self?.ownUser = response

                self?.loadInitialData(with: response)
            }
            .store(in: &cancellables)
    }

    func loadInitialData(with ownUser: UserResponseData) {
        Publishers.Zip4(apiClient.createPublisher(for: UsersRequest()), apiClient.createPublisher(for: StreamsRequest()), apiClient.createPublisher(for: TopicsRequest()), apiClient.createPublisher(for: StreamBindingsRequest()))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.initialLoadingFailed()
                }
            } receiveValue: { [weak self] usersResponse, streamsResponse, topicsResponse, streamBindingsResponse in
                guard let self else { return }
                let initialData = InitialLoadingData(streams: streamsResponse, topics: topicsResponse, streamBindings: streamBindingsResponse, users: usersResponse, folders: [], drafts: [], messageReactions: [], messages: [])
                self.loadAdditionalData(to: initialData, with: ownUser)
            }
            .store(in: &cancellables)
    }

    func loadAdditionalData(to initialData: InitialLoadingData, with ownUser: UserResponseData) {
        Publishers.Zip3(apiClient.createPublisher(for: MessageReactionsRequest(userUuid: ownUser.uuid)), apiClient.createPublisher(for: DraftsRequest()), apiClient.createPublisher(for: FoldersRequest()))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.initialLoadingFailed()
                }
            } receiveValue: { [weak self] messageReactionsResponse, draftsResponse, foldersResponse in
                guard let self else { return }
                var updatedData = initialData
                updatedData.messageReactions = messageReactionsResponse
                updatedData.drafts = draftsResponse
                updatedData.folders = foldersResponse
                loadMessages(with: updatedData)
            }
            .store(in: &cancellables)
    }

    func loadMessages(with initialData: InitialLoadingData) {
        let streamMessageUuids = Set(initialData.streams.compactMap { $0.lastMessageUuid })
        let topicMessageUuids = Set(initialData.topics.compactMap { $0.lastMessageUuid })
        let messageUuids = Array(topicMessageUuids.union(streamMessageUuids))
        var startIndex = messageUuids.startIndex
        loadMessagesBatch(initialData: initialData, startIndex: startIndex, messageUuids: messageUuids)
    }

    func loadMessagesBatch(initialData: InitialLoadingData, startIndex: Int, messageUuids: [String]) {
        let batchSize = 100
        let endIndex = messageUuids.index(startIndex, offsetBy: batchSize, limitedBy: messageUuids.endIndex) ?? messageUuids.endIndex
        let batch = Array(messageUuids[startIndex..<endIndex])
        apiClient.createPublisher(for: MessagesByIdsRequest(messageIds: batch))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.initialLoadingFailed()
                }
            } receiveValue: { [weak self] messagesResponse in
                guard let self else { return }

                var updatedData = initialData
                updatedData.messages.append(contentsOf: messagesResponse)

                let newStartIndex = endIndex
                if newStartIndex < messageUuids.endIndex {
                    self.loadMessagesBatch(initialData: updatedData, startIndex: newStartIndex, messageUuids: messageUuids)
                } else {
                    self.loadingState = .loaded
                    self.setInitialData(updatedData)
                }
            }
            .store(in: &cancellables)
    }

    func setInitialData(_ initialData: InitialLoadingData) {
        do {
            for newUserResponseData in initialData.users {
                let userUuid = newUserResponseData.uuid
                let userFetchDescriptor = FetchDescriptor<UserData>(predicate: #Predicate{ user in
                    user.uuid == userUuid
                })
                let users = try userProfile.context.fetch(userFetchDescriptor)
                let user = users.first
                if let user {
                    user.avatar = newUserResponseData.avatar
                    user.email = newUserResponseData.email
                    user.firstName = newUserResponseData.firstName
                    user.lastName = newUserResponseData.lastName
                    user.status = newUserResponseData.status
                    user.statusEmoji = newUserResponseData.statusEmoji
                    user.statusText = newUserResponseData.statusText
                } else {
                    let newUserData = UserData(with: newUserResponseData)
                    userProfile.context.insert(newUserData)
                }
            }

            for newStreamResponseData in initialData.streams {
                let streamUuid = newStreamResponseData.uuid
                let streamFetchDescriptor = FetchDescriptor<StreamData>(predicate: #Predicate{ stream in
                    stream.uuid == streamUuid
                })
                let streams = try userProfile.context.fetch(streamFetchDescriptor)
                let stream = streams.first
                if let stream {
                    stream.unreadCount = newStreamResponseData.unreadCount
                    stream.activeUnreadCount = newStreamResponseData.activeUnreadCount
                    stream.passiveUnreadCount = newStreamResponseData.passiveUnreadCount
                    stream.name = newStreamResponseData.name
                    stream.isArchived = newStreamResponseData.isArchived
                    stream.currentEncryptionKeyUuid = newStreamResponseData.currentEncryptionKeyUuid
                    stream.notificationMode = newStreamResponseData.notificationMode
                    stream.role = newStreamResponseData.role
                } else {
                    let newStreamData = StreamData(from: newStreamResponseData)
                    if let directUserUuid = newStreamResponseData.directUserUuid {
                        let userFetchDescriptor = FetchDescriptor<UserData>(predicate: #Predicate{ user in
                            user.uuid == directUserUuid
                        })
                        let users = try? userProfile.context.fetch(userFetchDescriptor)
                        let directUser = users?.first
                        newStreamData.directUser = directUser
                    }
                    userProfile.context.insert(newStreamData)
                }
            }

            for newTopicResponseData in initialData.topics {
                let topicUuid = newTopicResponseData.uuid
                let topicFetchDescriptor = FetchDescriptor<TopicData>(predicate: #Predicate{ topic in
                    topic.uuid == topicUuid
                })
                let topic = try userProfile.context.fetch(topicFetchDescriptor).first
                if let topic {
                    topic.isDefault = newTopicResponseData.isDefault
                    topic.isDone = newTopicResponseData.isDone
                    topic.color = newTopicResponseData.color
                    topic.unreadCount = newTopicResponseData.unreadCount
                    let notificationMode: TopicNotificationMode
                    switch newTopicResponseData.notificationMode {
                    case .default:
                        notificationMode = .default
                    case .follow:
                        notificationMode = .follow
                    case .mute:
                        notificationMode = .mute
                    }
                    topic.notificationMode = notificationMode
                } else {
                    let streamUuid = newTopicResponseData.streamUuid
                    let streamFetchDescriptor = FetchDescriptor<StreamData>(predicate: #Predicate{ stream in
                        stream.uuid == streamUuid
                    })
                    let streams = try? userProfile.context.fetch(streamFetchDescriptor)
                    let stream = streams?.first
                    if let stream {
                        let newTopicData = TopicData(from: newTopicResponseData, stream: stream)
                        userProfile.context.insert(newTopicData)
                    }
                }
            }

            try userProfile.context.save()

            for newMessageResponseData in initialData.messages {
                let messageUuid = newMessageResponseData.uuid
                let messageFetchDescriptor = FetchDescriptor<LastMessageData>(predicate: #Predicate{ message in
                    message.uuid == messageUuid
                })
                let messages = try userProfile.context.fetch(messageFetchDescriptor)
                let message = messages.first
                if let message {
                    let payload: MessagePayload
                    switch newMessageResponseData.payload {
                    case let .e2ee(e2eePayload):
                        payload = .e2ee(.init(kind: .e2ee, content: e2eePayload.content, keyUuid: e2eePayload.keyUuid))
                    case let .keyAnnounced(keyAnnouncedPayload):
                        payload = .keyAnnounced(.init(kind: .keyAnnounced, keyUuid: keyAnnouncedPayload.keyUuid))
                    case let .keyGrant(keyGrantPayload):
                        payload = .keyGrant(.init(kind: .keyGrant, keyUuid: keyGrantPayload.keyUuid, requestMessageUuid: keyGrantPayload.requestMessageUuid, senderDeviceId: keyGrantPayload.senderDeviceId, recipientDeviceId: keyGrantPayload.recipientDeviceId, content: keyGrantPayload.content))
                    case let .keyReject(keyRejectPayload):
                        payload = .keyReject(.init(kind: .keyReject, keyUuid: keyRejectPayload.keyUuid, requestMessageUuid: keyRejectPayload.requestMessageUuid, senderDeviceId: keyRejectPayload.senderDeviceId, recipientDeviceId: keyRejectPayload.recipientDeviceId))
                    case let .keyRequest(keyRequestPayload):
                        payload = .keyRequest(.init(kind: .keyRequest, keyUuid: keyRequestPayload.keyUuid, deviceId: keyRequestPayload.deviceId, deviceName: keyRequestPayload.deviceName, publicKey: keyRequestPayload.publicKey))
                    case let .markdown(markdownPayload):
                        payload = .markdown(.init(kind: .markdown, content: markdownPayload.content))
                    case .undefined:
                        payload = .undefined
                    }
                    message.payload = payload
                    message.reactions = newMessageResponseData.reactions
                } else {
                    let streamUuid = newMessageResponseData.streamUuid
                    let streamFetchDescriptor = FetchDescriptor<StreamData>(predicate: #Predicate{ stream in
                        stream.uuid == streamUuid
                    })
                    let streams = try userProfile.context.fetch(streamFetchDescriptor)
                    let stream = streams.first

                    let topicUuid = newMessageResponseData.topicUuid
                    let topicFetchDescriptor = FetchDescriptor<TopicData>(predicate: #Predicate{ topic in
                        topic.uuid == topicUuid
                    })
                    let topic = try userProfile.context.fetch(topicFetchDescriptor).first

                    let userUuid = newMessageResponseData.authorUuid
                    let userFetchDescriptor = FetchDescriptor<UserData>(predicate: #Predicate{ user in
                        user.uuid == userUuid
                    })
                    let users = try userProfile.context.fetch(userFetchDescriptor)
                    let author = users.first

                    if let stream, let topic, let author {
                        let newMessage = LastMessageData(with: newMessageResponseData, stream: stream, topic: topic, author: author)
                        userProfile.context.insert(newMessage)
                    }
                }
            }

            for newStreamBindingResponseData in initialData.streamBindings {
                let streamBindingUuid = newStreamBindingResponseData.uuid
                let streamBindingFetchDescriptor = FetchDescriptor<StreamBindingData>(predicate: #Predicate{ streamBinding in
                    streamBinding.uuid == streamBindingUuid
                })
                let streamBindings = try userProfile.context.fetch(streamBindingFetchDescriptor)
                let streamBinding = streamBindings.first
                if let streamBinding {
                    streamBinding.role = newStreamBindingResponseData.role
                } else {
                    let streamUuid = newStreamBindingResponseData.uuid
                    let streamFetchDescriptor = FetchDescriptor<StreamData>(predicate: #Predicate{ stream in
                        stream.uuid == streamUuid
                    })
                    let streams = try userProfile.context.fetch(streamFetchDescriptor)
                    let stream = streams.first

                    let userUuid = newStreamBindingResponseData.uuid
                    let userFetchDescriptor = FetchDescriptor<UserData>(predicate: #Predicate{ user in
                        user.uuid == userUuid
                    })
                    let users = try userProfile.context.fetch(userFetchDescriptor)
                    let user = users.first

                    if let stream, let user {
                        let newStreamBindingData = StreamBindingData(uuid: newStreamBindingResponseData.uuid, role: newStreamBindingResponseData.role, stream: stream, user: user)
                        userProfile.context.insert(newStreamBindingData)
                    }
                }
            }

            for newMessageReactionResponseData in initialData.messageReactions {
                let messageReactionUuid = newMessageReactionResponseData.uuid
                let messageReactionFetchDescriptor = FetchDescriptor<MessageReactionData>(predicate: #Predicate{ messageReaction in
                    messageReaction.uuid == messageReactionUuid
                })
                let messageReactions = try userProfile.context.fetch(messageReactionFetchDescriptor)
                let messageReaction = messageReactions.first
                if messageReaction == nil {
                    let userUuid = newMessageReactionResponseData.uuid
                    let userFetchDescriptor = FetchDescriptor<UserData>(predicate: #Predicate{ user in
                        user.uuid == userUuid
                    })
                    let users = try userProfile.context.fetch(userFetchDescriptor)
                    let user = users.first

                    if let user {
                        let newMessageReactionData = MessageReactionData(with: newMessageReactionResponseData, user: user)
                        userProfile.context.insert(newMessageReactionData)
                    }
                }
            }

            for folderResponseData in initialData.folders {
                let folderUuid = folderResponseData.uuid
                let folderFetchDescriptor = FetchDescriptor<FolderData>(predicate: #Predicate{ folder in
                    folder.uuid == folderUuid
                })
                let folders = try userProfile.context.fetch(folderFetchDescriptor)
                let folder = folders.first
                if let folder {
                    folder.unreadCount = folderResponseData.unreadCount
                } else {
                    let newFolderData = FolderData(with: folderResponseData)
                    userProfile.context.insert(newFolderData)
                }
                if let folderItemsResponseData = folderResponseData.folderItems {
                    for newFolderItemResponseData in folderItemsResponseData {
                        let folderItemUuid = newFolderItemResponseData.uuid
                        let folderItemFetchDescriptor = FetchDescriptor<FolderItemData>(predicate: #Predicate{ folderItem in
                            folderItem.uuid == folderItemUuid
                        })
                        let folderItems = try userProfile.context.fetch(folderItemFetchDescriptor)
                        let folderItem = folderItems.first
                        if let folderItem {
                            folderItem.unreadCount = newFolderItemResponseData.unreadCount
                        } else {
                            let folderUuid = folderResponseData.uuid
                            let folderFetchDescriptor = FetchDescriptor<FolderData>(predicate: #Predicate{ folder in
                                folder.uuid == folderUuid
                            })
                            let folders = try userProfile.context.fetch(folderFetchDescriptor)
                            let folder = folders.first

                            let streamUuid = newFolderItemResponseData.streamUuid
                            let streamFetchDescriptor = FetchDescriptor<StreamData>(predicate: #Predicate{ stream in
                                stream.uuid == streamUuid
                            })
                            let streams = try userProfile.context.fetch(streamFetchDescriptor)
                            let stream = streams.first

                            if let folder, let stream {
                                let newFolderItemData = FolderItemData(with: newFolderItemResponseData, stream: stream, folder: folder)
                                userProfile.context.insert(newFolderItemData)
                            }
                        }
                    }
                }
            }

            for newDraftResponseData in initialData.drafts {
                let draftUuid = newDraftResponseData.uuid
                let draftFetchDescriptor = FetchDescriptor<DraftData>(predicate: #Predicate{ draft in
                    draft.uuid == draftUuid
                })
                let drafts = try userProfile.context.fetch(draftFetchDescriptor)
                let draft = drafts.first
                if let draft {
                    let payload: MessagePayload
                    switch newDraftResponseData.payload {
                    case let .e2ee(e2eePayload):
                        payload = .e2ee(.init(kind: .e2ee, content: e2eePayload.content, keyUuid: e2eePayload.keyUuid))
                    case let .keyAnnounced(keyAnnouncedPayload):
                        payload = .keyAnnounced(.init(kind: .keyAnnounced, keyUuid: keyAnnouncedPayload.keyUuid))
                    case let .keyGrant(keyGrantPayload):
                        payload = .keyGrant(.init(kind: .keyGrant, keyUuid: keyGrantPayload.keyUuid, requestMessageUuid: keyGrantPayload.requestMessageUuid, senderDeviceId: keyGrantPayload.senderDeviceId, recipientDeviceId: keyGrantPayload.recipientDeviceId, content: keyGrantPayload.content))
                    case let .keyReject(keyRejectPayload):
                        payload = .keyReject(.init(kind: .keyReject, keyUuid: keyRejectPayload.keyUuid, requestMessageUuid: keyRejectPayload.requestMessageUuid, senderDeviceId: keyRejectPayload.senderDeviceId, recipientDeviceId: keyRejectPayload.recipientDeviceId))
                    case let .keyRequest(keyRequestPayload):
                        payload = .keyRequest(.init(kind: .keyRequest, keyUuid: keyRequestPayload.keyUuid, deviceId: keyRequestPayload.deviceId, deviceName: keyRequestPayload.deviceName, publicKey: keyRequestPayload.publicKey))
                    case let .markdown(markdownPayload):
                        payload = .markdown(.init(kind: .markdown, content: markdownPayload.content))
                    case .undefined:
                        payload = .undefined
                    }
                    draft.payload = payload
                    draft.revision = newDraftResponseData.revision
                    draft.updatedAt = newDraftResponseData.updatedAt
                } else {
                    let streamUuid = newDraftResponseData.streamUuid
                    let streamFetchDescriptor = FetchDescriptor<StreamData>(predicate: #Predicate{ stream in
                        stream.uuid == streamUuid
                    })
                    let streams = try userProfile.context.fetch(streamFetchDescriptor)
                    let stream = streams.first

                    let topicUuid = newDraftResponseData.topicUuid
                    let topicFetchDescriptor = FetchDescriptor<TopicData>(predicate: #Predicate{ topic in
                        topic.uuid == topicUuid
                    })
                    let topic = try userProfile.context.fetch(topicFetchDescriptor).first

                    if let stream, let topic {
                        let newDraft = DraftData(with: newDraftResponseData, stream: stream, topic: topic)
                        userProfile.context.insert(newDraft)
                    }
                }
            }


            try userProfile.context.save()
            start()
        } catch {
            print(error)
        }
    }

    func addMessageReaction(_ messageReaction: MessageReactionResponseData) {
        let userUuid = messageReaction.userUuid
        let userFetchDescriptor = FetchDescriptor<UserData>(predicate: #Predicate{ user in
            user.uuid == userUuid
        })
        let users = try? userProfile.context.fetch(userFetchDescriptor)
        let user = users?.first
        if let user {
            let messageReactionData = MessageReactionData(with: messageReaction, user: user)
            userProfile.context.insert(messageReactionData)
            try? userProfile.context.save()
        }
    }

    func deleteMessageReaction(_ messageReaction: MessageReactionResponseData) {
        let messageReactionUuid = messageReaction.uuid
        let messageReactionFetchDescriptor = FetchDescriptor<MessageReactionData>(predicate: #Predicate{ messageReaction in
            messageReaction.uuid == messageReactionUuid
        })
        let messageReactions = try? userProfile.context.fetch(messageReactionFetchDescriptor)
        let messageReactionData = messageReactions?.first
        if let messageReactionData {
            userProfile.context.delete(messageReactionData)
            try? userProfile.context.save()
        }
    }

    func setInitialUsers(_ users: [UserResponseData]) {
        for userResponse in users {
            let user = UserData(with: userResponse)
            userProfile.context.insert(user)
        }
    }

    func addUser(_ userResponse: UserResponseData) {
        let user = UserData(with: userResponse)
        userProfile.context.insert(user)
    }

    func updateUser(_ userResponse: UserResponseData) {
        let user = UserData(with: userResponse)
        userProfile.context.insert(user)
        try? userProfile.context.save()
    }

    func addFolder(_ folderResponseData: FolderResponseData) {
        let folderData = FolderData(with: folderResponseData)
        userProfile.context.insert(folderData)
        if let folderItemsResponseData = folderResponseData.folderItems {
            let folderItemDataArray = folderItemsResponseData.compactMap { folderItemResponseData in
                let streamUuid = folderItemResponseData.streamUuid
                let streamFetchDescriptor = FetchDescriptor<StreamData>(predicate: #Predicate{ stream in
                    stream.uuid == streamUuid
                })
                let streams = try? userProfile.context.fetch(streamFetchDescriptor)
                let stream = streams?.first
                if let stream {
                    return FolderItemData(with: folderItemResponseData, stream: stream, folder: folderData)
                } else {
                    return nil
                }
            }
            for folderItemData in folderItemDataArray {
                userProfile.context.insert(folderItemData)
            }
        }
    }

    func updateFolder(_ folderResponseData: FolderResponseData) {
        addFolder(folderResponseData)
    }

    func setInitialStreams(_ streams: [StreamResponseData]) {
        for streamResponse in streams {
            let stream = StreamData(from: streamResponse)
            userProfile.context.insert(stream)
            try? userProfile.context.save()
        }
    }

    func addStream(_ streamResponse: StreamResponseData) {
        let stream = StreamData(from: streamResponse)
        userProfile.context.insert(stream)
    }

    func updateStream(_ streamResponse: StreamResponseData) {
        let stream = StreamData(from: streamResponse)
        userProfile.context.insert(stream)
        try? userProfile.context.save()
    }

    func setInitialTopics(_ topics: [TopicResponseData]) {
        for topicResponse in topics {
            addTopic(topicResponse)
        }
    }

    func addTopic(_ topicResponse: TopicResponseData) {
        let streamUuid = topicResponse.streamUuid
        let streamFetchDescriptor = FetchDescriptor<StreamData>(predicate: #Predicate{ stream in
            stream.uuid == streamUuid
        })
        let streams = try? userProfile.context.fetch(streamFetchDescriptor)
        let stream = streams?.first
        if let stream {
            let topic = TopicData(from: topicResponse, stream: stream)
            userProfile.context.insert(topic)
            try? userProfile.context.save()
        }
    }

    func updateTopic(_ topicResponse: TopicResponseData) {
        let topicUuid = topicResponse.uuid
        let topicFetchDescriptor = FetchDescriptor<TopicData>(predicate: #Predicate{ topic in
            topic.uuid == topicUuid
        })
        let topic = try? userProfile.context.fetch(topicFetchDescriptor).first
        if let topic {
            topic.isDefault = topicResponse.isDefault
            topic.isDone = topicResponse.isDone
            topic.color = topicResponse.color
            topic.unreadCount = topicResponse.unreadCount
            let notificationMode: TopicNotificationMode
            switch topicResponse.notificationMode {
            case .default:
                notificationMode = .default
            case .follow:
                notificationMode = .follow
            case .mute:
                notificationMode = .mute
            }
            topic.notificationMode = notificationMode
        }
    }

    func setInitialMessages(_ messages: [MessageResponseData]) {
        for message in messages {
            setInitialMessage(message)
        }
    }

    func setInitialMessage(_ message: MessageResponseData) {
        let streamUuid = message.streamUuid
        let streamFetchDescriptor = FetchDescriptor<StreamData>(predicate: #Predicate{ stream in
            stream.uuid == streamUuid
        })
        let streams = try? userProfile.context.fetch(streamFetchDescriptor)
        let stream = streams?.first
        let topicUuid = message.topicUuid
        let topicFetchDescriptor = FetchDescriptor<TopicData>(predicate: #Predicate{ topic in
            topic.uuid == topicUuid
        })
        let topic = try? userProfile.context.fetch(topicFetchDescriptor).first
        if let stream, let topic {
            let message = MessageData(with: message, stream: stream, topic: topic)
            let messageAuthorUuid = message.authorUuid
            let authorFetchDescriptor = FetchDescriptor<UserData>(predicate: #Predicate{ user in
                user.uuid == messageAuthorUuid
            })
            let authors = try? userProfile.context.fetch(authorFetchDescriptor)
            let author = authors?.first
            message.author = author

            userProfile.context.insert(message)


            try? userProfile.context.save()
        }
    }
    func addDraft(_ draftResponseData: DraftResponseData) {
        let streamUuid = draftResponseData.streamUuid
        let streamFetchDescriptor = FetchDescriptor<StreamData>(predicate: #Predicate{ stream in
            stream.uuid == streamUuid
        })
        let streams = try? userProfile.context.fetch(streamFetchDescriptor)
        let stream = streams?.first
        let topicUuid = draftResponseData.topicUuid
        let topicFetchDescriptor = FetchDescriptor<TopicData>(predicate: #Predicate{ topic in
            topic.uuid == topicUuid
        })
        let topic = try? userProfile.context.fetch(topicFetchDescriptor).first
        if let stream, let topic {
            let draft = DraftData(with: draftResponseData, stream: stream, topic: topic)

            userProfile.context.insert(draft)


            try? userProfile.context.save()
        }
    }

    func updateDraft(_ draft: DraftResponseData) {
        addDraft(draft)
    }

    func addBinding(_ bindingResponseData: StreamBindingResponseData) {
        let streamUuid = bindingResponseData.streamUuid
        let streamFetchDescriptor = FetchDescriptor<StreamData>(predicate: #Predicate{ stream in
            stream.uuid == streamUuid
        })
        let streams = try? userProfile.context.fetch(streamFetchDescriptor)
        let stream = streams?.first
        let userUuid = bindingResponseData.userUuid
        let userFetchDescriptor = FetchDescriptor<UserData>(predicate: #Predicate{ user in
            user.uuid == userUuid
        })
        let users = try? userProfile.context.fetch(userFetchDescriptor)
        let user = users?.first
        if let stream, let user {
            let streamBindingData = StreamBindingData(uuid: bindingResponseData.uuid, role: bindingResponseData.role, stream: stream, user: user)

            userProfile.context.insert(streamBindingData)


            try? userProfile.context.save()
        }
    }

    func updateBinding(_ binding: StreamBindingResponseData) {
        addBinding(binding)
    }

//    func setInitialMessagePool(_ messagePool: [MessageResponseData]) {
//        let messagesWithAuthor = messagePool.map {
//            var messageWithAuthor = $0
////            let author = users.first(where: { $0.uuid == messageWithAuthor.authorUuid })
////            messageWithAuthor.author = author
//            return messageWithAuthor
//        }
//        self.messagePool = messagesWithAuthor
//    }

    func addMessages(_ messageResponseDataArray: [MessageResponseData], streamUuid: String, topicUuid: String) {
        let streamUuid = streamUuid
        let streamFetchDescriptor = FetchDescriptor<StreamData>(predicate: #Predicate{ stream in
            stream.uuid == streamUuid
        })
        let streams = try? userProfile.context.fetch(streamFetchDescriptor)
        let stream = streams?.first
        let topicUuid = topicUuid
        let topicFetchDescriptor = FetchDescriptor<TopicData>(predicate: #Predicate{ topic in
            topic.uuid == topicUuid
        })
        let topic = try? userProfile.context.fetch(topicFetchDescriptor).first
        if let stream, let topic {
            for messageResponseData in messageResponseDataArray {
                addMessage(messageResponseData, streamData: stream, topicData: topic)
            }
        }
    }

    func addMessage(_ messageResponseData: MessageResponseData, streamData: StreamData, topicData: TopicData) {
        let messageData = MessageData(with: messageResponseData, stream: streamData, topic: topicData)

        userProfile.context.insert(messageData)


        try? userProfile.context.save()
    }

    func addMessage(_ messageResponseData: MessageResponseData) {
        let streamUuid = messageResponseData.streamUuid
        let streamFetchDescriptor = FetchDescriptor<StreamData>(predicate: #Predicate{ stream in
            stream.uuid == streamUuid
        })
        let streams = try? userProfile.context.fetch(streamFetchDescriptor)
        let stream = streams?.first
        let topicUuid = messageResponseData.topicUuid
        let topicFetchDescriptor = FetchDescriptor<TopicData>(predicate: #Predicate{ topic in
            topic.uuid == topicUuid
        })
        let topic = try? userProfile.context.fetch(topicFetchDescriptor).first
        if let stream, let topic {
            let messageData = MessageData(with: messageResponseData, stream: stream, topic: topic)

            userProfile.context.insert(messageData)


            try? userProfile.context.save()
        }
    }

    func updateMessage(_ messageResponseData: MessageResponseData) {
        addMessage(messageResponseData)
    }

    func initialLoadingFailed() {
        loadingState = .error
        initialLoadingErrorViewModel = .init(actionToRepeat: loadServerSettings)
    }

//    func loadMessageReactions(for userUuid: String) {
//        apiClient.createPublisher(for: MessageReactionsRequest(userUuid: userUuid))
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] completion in
//                if case let .failure(error) = completion {
//                    self?.initialLoadingFailed()
//                }
//            } receiveValue: { [weak self] response in
//                self?.setInitialMessageReactions(response)
//                self?.loadUsers()
//            }
//            .store(in: &cancellables)
//    }

//    func loadUsers() {
//        loadingState = .loading
//        apiClient.createPublisher(for: UsersRequest())
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] completion in
//                if case let .failure(error) = completion {
//                    self?.initialLoadingFailed()
//                }
//            } receiveValue: { [weak self] response in
//                guard let self else { return }
////                self.setInitialUsers(response)
//                self.loadFolders(users: response)
//            }
//            .store(in: &cancellables)
//    }
//
//    func loadFolders(users: [UserResponseData]) {
//        apiClient.createPublisher(for: FoldersRequest())
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] completion in
//                if case let .failure(error) = completion {
//                    self?.initialLoadingFailed()
//                }
//            } receiveValue: { [weak self] response in
//                let sortedFolders = response.sorted { $0.createdAt < $1.createdAt
//                }
////                self?.setInitialFolders(sortedFolders)
//                self?.loadSubscribedStreams(users: users, folders: sortedFolders)
//            }
//            .store(in: &cancellables)
//    }
//
//    func loadSubscribedStreams(users: [UserResponseData], folders: [FolderResponseData]) {
//        apiClient.createPublisher(for: StreamsRequest())
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] completion in
//                if case let .failure(error) = completion {
//                    self?.initialLoadingFailed()
//                }
//            } receiveValue: { [weak self] response in
//                guard let self else { return }
//                self.loadStreamBindings(for: response)
//            }
//            .store(in: &cancellables)
//    }
//
//    func loadStreamBindings(for streams: [StreamResponseData]) {
//        apiClient.createPublisher(for: StreamBindingsRequest())
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] completion in
//                if case let .failure(error) = completion {
//                    self?.initialLoadingFailed()
//                }
//            } receiveValue: { [weak self] response in
//                guard let self else { return }
//                self.setInitialStreams(streams)
//                let streamMessageUuids = Set(streams.compactMap { $0.lastMessageUuid })
//                self.loadAllTopics(with: streamMessageUuids)
//            }
//            .store(in: &cancellables)
//    }
//
//    func loadAllTopics(with streamMessageUuids: Set<String>) {
//        apiClient.createPublisher(for: TopicsRequest())
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] completion in
//                if case let .failure(error) = completion {
//                    self?.initialLoadingFailed()
//                }
//            } receiveValue: { [weak self] response in
//                self?.setInitialTopics(response)
//                let topicMessageUuids = Set(response.compactMap { $0.lastMessageUuid })
//                let messageUuidsToLoad = topicMessageUuids.union(streamMessageUuids)
//                self?.loadMessages(with: Array(messageUuidsToLoad))
//                self?.loadingState = .loaded
//            }
//            .store(in: &cancellables)
//    }
//
//    func loadDrafts() {
//        apiClient.createPublisher(for: DraftsRequest())
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] completion in
//                if case let .failure(error) = completion {
//                    self?.initialLoadingFailed()
//                }
//            } receiveValue: { [weak self] response in
//                self?.setInitialDrafts(response)
//                self?.start()
//                self?.loadingState = .loaded
//            }
//            .store(in: &cancellables)
//    }

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
        case .user:
            didReceiveUserEvent(eventData: eventData, action: event.action)
        default:
            break
        }
    }

    func didReceiveMessageEvent(eventData: Data, action: ReceivedEventAction) {
        switch action {
        case .updated:
            if let message = try? payload(MessageResponseData.self, data: eventData) {
                updateMessage(message)
            }
        case .created:
            if let message = try? payload(MessageResponseData.self, data: eventData) {
                addMessage(message)
            }
        case .deleted:
            break
        }
    }

    func didReceiveStreamEvent(eventData: Data, action: ReceivedEventAction) {
        switch action {
        case .updated:
            if let stream = try? payload(StreamResponseData.self, data: eventData) {
                updateStream(stream)
            }
        case .created:
            if let stream = try? payload(StreamResponseData.self, data: eventData) {
                addStream(stream)
            }
        case .deleted:
            break
        }
    }

    func didReceiveUserEvent(eventData: Data, action: ReceivedEventAction) {
        switch action {
        case .updated:
            if let user = try? payload(UserResponseData.self, data: eventData) {
                updateUser(user)
            }
        case .created:
            if let user = try? payload(UserResponseData.self, data: eventData) {
                addUser(user)
            }
        case .deleted:
            break
        }
    }

    func didReceiveTopicEvent(eventData: Data, action: ReceivedEventAction) {
        switch action {
        case .updated:
            if let topic = try? payload(TopicResponseData.self, data: eventData) {
                updateTopic(topic)
            }
        case .created:
            if let topic = try? payload(TopicResponseData.self, data: eventData) {
                addTopic(topic)
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
