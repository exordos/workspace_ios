//
//  ChatViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine
import GiphyUISDK

final class ChatViewModel: ObservableObject {

    @Published private(set) var model: Chat
    private(set) var apiClient: APIClient
    private(set) var eventHandler: EventHandler
    private var cancellables: Set<AnyCancellable> = []
    @Published var loadingState: LoadingState = .initialized
    @Published var message: String = ""
    @Published var image: Image? = nil
    @Published var messageToSend: MessageResponseData?
    @Published var jitsiNameItem: JitsiNameItem?
    @Published var messages: [MessageResponseData] = []
    @Published var streams: [StreamData] = []

    var currentStream: StreamData? {
        streams.first { $0.uuid == model.streamUuid }
    }

    init(apiClient: APIClient, model: Chat, eventHandler: EventHandler) {
        self.apiClient = apiClient
        self.model = model
        self.eventHandler = eventHandler
        subscribe()
    }

    func subscribe() {
        eventHandler.streamTopicMessagesPublisher
            .sink { [weak self] streamTopicMessages in
                guard let self else { return }
                let messages = streamTopicMessages["\(model.streamUuid).\(model.topicUuid)"] ?? []
                let newMessages = messages.filter {
                    !self.model.messages.contains($0)
                }
                model.messages.append(contentsOf: newMessages)
            }
            .store(in: &cancellables)
            eventHandler.streamsPublisher
                .assign(to: &$streams)
//        eventHandler.messagesPublisher
//            .sink { [weak self] newMessages in
//                guard let self else { return }
//                let currentTypeMessages = newMessages.compactMap {
//                    switch $0 {
//                    case let .direct(message):
//                        return self.model.isDirectMessages ? message.unifiedMessage : nil
//                    case let .channel(message):
//                        return self.model.isDirectMessages ? nil : message.unifiedMessage
//                    }
//                }
//                let messageIds = self.model.messages.map { $0.id }
//                let filteredMessages = currentTypeMessages.filter {
//                    !messageIds.contains($0.id) && self.model.chatId == "[\($0.senderId), \(self.model.currentUser.userId)]"
//                }
//                self.model.messages.append(contentsOf: filteredMessages)
//            }
//            .store(in: &cancellables)
    }

    func onAppear() {
        if loadingState == .initialized, messages.isEmpty {
            loadInitialMessages()
        }
    }

    func onSendButtonTapped() async {
        if let image {
            let imageData = try? imageData(
                        from: image,
                        renderSize: CGSize(width: 1024, height: 1024),
                        jpegQuality: 0.85
            )
            if let imageData {
                let imageUploadResponse = try? await apiClient.uploadFile(for: UploadFileRequest(), data: imageData, filename: "file", mimeType: "image/jpeg", streamUuid: model.streamUuid)
                var messageText = ""
                if !message.isEmpty {
                    messageText += "\(message)\r\n"
                }
                if let imageUploadResponse {
                    messageText += "![\(imageUploadResponse.name)](urn:image:\(imageUploadResponse.uuid))\n\n"
                }
                sendMessage(with: messageText)
                message = ""
            }
        } else if !message.isEmpty {
            sendMessage(with: message)
            message = ""
            image = nil
        }
    }

    func sendMessage(with text: String) {
        let message = MessageResponseData(uuid: UUID().uuidString,
                                          updatedAt: Date(),
                                          createdAt: Date(),
                                          streamUuid: model.streamUuid,
                                          topicUuid: model.topicUuid,
                                          payload: .init(kind: .markdown, content: text),
                                          isOwn: true,
                                          authorUuid: eventHandler.ownUser?.uuid ?? "",
                                          reactions: [:])
        eventHandler.addMessageToStreamTopic(message: message)
        apiClient.createPublisher(for: SendMessageRequest(streamUuid: model.streamUuid, topicUuid: model.topicUuid, content: text))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }

            }
            .store(in: &cancellables)
    }

    func loadInitialMessages() {
        loadMessages()
    }

    func loadMessages() {
        apiClient.createPublisher(for: MessagesRequest(streamUuid: model.streamUuid, topicUuid: model.topicUuid))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                eventHandler.addTopicMessages(response, to: model.streamUuid, and: model.topicUuid)
            }
            .store(in: &cancellables)
    }

    func didTapOnCallButton() {
        let generatedCallName = JitsiStyleRoomNameGenerator().generate()
        sendMessage(with: "\(eventHandler.meetUrl)/\(generatedCallName)")
        jitsiNameItem = .init(jitsiName: generatedCallName)
    }

    func didTapOnCallMessage(with jitsiName: String) {
        jitsiNameItem = .init(jitsiName: jitsiName)
    }

    @MainActor
    private func imageData(
        from image: Image,
        renderSize: CGSize,
        jpegQuality: CGFloat
    ) throws -> Data {
        let renderer = ImageRenderer(
            content: image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: renderSize.width, height: renderSize.height)
        )
        renderer.scale = UIScreen.main.scale
        guard let uiImage = renderer.uiImage,
              let data = uiImage.jpegData(compressionQuality: jpegQuality) else {
            throw APIError.decoding
        }
        return data
    }
}

struct JitsiStyleRoomNameGenerator {
    private let adjectives = [
        "amber", "brisk", "calm", "clever", "daring", "eager", "fancy", "gentle",
        "jolly", "kind", "lucky", "merry", "nimble", "proud", "quick", "sunny",
        "tidy", "vivid", "witty", "zesty"
    ]
    private let colorsOrQualifiers = [
        "blue", "crimson", "golden", "green", "indigo", "ivory", "jade", "lavender",
        "orange", "pearl", "ruby", "silver", "teal", "violet"
    ]
    private let nouns = [
        "anchor", "badger", "beacon", "comet", "dolphin", "falcon", "forest", "harbor",
        "lantern", "meadow", "otter", "panda", "river", "rocket", "sparrow", "summit",
        "tiger", "valley", "willow", "zephyr"
    ]

    func generate() -> String {
        let adjective = adjectives.randomElement() ?? ""
        let color = colorsOrQualifiers.randomElement() ?? ""
        let noun = nouns.randomElement() ?? ""
        return adjective + color.capitalized + noun.capitalized
    }
}

struct JitsiNameItem: Identifiable {
    let id = UUID()
    let jitsiName: String
}
