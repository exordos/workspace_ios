//
//  ChatViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import SwiftData
import Combine
import GiphyUISDK
import CryptoKit

final class ChatViewModel: ObservableObject {

    private struct Constants {
        static let pageLimit = 50
    }

    @Published private(set) var model: Chat
    private(set) var apiClient: APIClient
    private(set) var eventHandler: EventHandler
    private var cancellables: Set<AnyCancellable> = []
    @Published var loadingState: LoadingState = .initialized
    @Published var message: String = ""
    @Published var image: Image? = nil
    @Published var messageToSend: MessageResponseData?
    @Published var jitsiNameItem: JitsiNameItem?
    @Published var streams: [StreamResponseData] = []
    private(set) var onInfoButtonTap: () -> Void
    private(set) var onUserTap: (String) -> Void

//    var currentStream: StreamResponseData? {
//        streams.first { $0.uuid == model.streamUuid }
//    }

//    var isOwner: Bool {
//        guard let currentStream else { return false }
//
//        return currentStream.role == "owner"
//    }

    func shouldRequestEncryptionKey(for currentStream: StreamData?) -> Bool {
        guard let currentStream else { return false }

        return eventHandler.shouldRequestEncryptionKey(for: currentStream)
    }

    init(apiClient: APIClient, model: Chat, eventHandler: EventHandler, onInfoButtonTap: @escaping () -> Void, onUserTap: @escaping (String) -> Void) {
        self.apiClient = apiClient
        self.model = model
        self.eventHandler = eventHandler
        self.onInfoButtonTap = onInfoButtonTap
        self.onUserTap = onUserTap
    }

    func onAppear(shouldLoadMessages: Bool) {
        if loadingState == .initialized {
            loadInitialMessages()
        }
    }

    func onSendButtonTapped(with currentStream: StreamData?) async {
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
                sendMessage(with: messageText, currentStream: currentStream)
                message = ""
            }
        } else if !message.isEmpty {
            sendMessage(with: message, currentStream: currentStream)
            message = ""
            image = nil
        }
    }

    func sendMessage(with text: String, currentStream: StreamData?) {
        guard let currentStream else { return }

        if currentStream.hasEncryption {
            encryptAndSendMessage(with: text, currentStream: currentStream)
        } else {
            sendMessage(with: .markdown(.init(kind: .markdown, content: text)))
        }
    }

    func encryptAndSendMessage(with text: String, currentStream: StreamData?) {
        guard let currentEncryptionKeyUuid = currentStream?.currentEncryptionKeyUuid, let currentStream, let currentUser = eventHandler.ownUser, let keyData = eventHandler.userProfile.keyData(keyUuid: currentEncryptionKeyUuid, userUuid: currentUser.uuid, streamUuid: currentStream.uuid), let data = text.data(using: .utf8) else { return }

        do {
            let encryptedMessage = try encryptMessage(groupKey: keyData, plaintext: data, streamUuid: currentStream.uuid, keyUuid: currentEncryptionKeyUuid)
            sendMessage(with: .e2ee(.init(kind: .e2ee, content: encryptedMessage.base64EncodedString(), keyUuid: currentEncryptionKeyUuid)))
        } catch {
            print("Error")
        }
    }

    func sendMessage(with payload: MessageResponsePayload) {
        let message = MessageResponseData(uuid: UUID().uuidString.lowercased(),
                                          updatedAt: Date(),
                                          createdAt: Date(),
                                          streamUuid: model.streamUuid,
                                          topicUuid: model.topicUuid,
                                          payload: payload,
                                          isOwn: true,
                                          authorUuid: eventHandler.ownUser?.uuid ?? "",
                                          reactions: [:])
//        eventHandler.addMessageToStreamTopic(message: message)
        apiClient.createPublisher(for: SendMessageRequest(streamUuid: model.streamUuid, topicUuid: model.topicUuid, payload: payload))
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

    func sendEncryptedKeyRequest(with currentStream: StreamData?) {
        guard let currentEncryptionKeyUuid = currentStream?.currentEncryptionKeyUuid else { return }
        let keyRequestPayload = MessageResponsePayload.KeyRequest(kind: .keyRequest, keyUuid: currentEncryptionKeyUuid, deviceId: eventHandler.userProfile.deviceId, deviceName: "iPhone", publicKey: eventHandler.userProfile.chatRequestPublicKey.base64EncodedString())
        sendMessage(with: .keyRequest(keyRequestPayload))
    }

    func sendReject(for requestPayload: MessagePayload.KeyRequest, requestMessageUuid: String) {
        let keyRejectPayload = MessageResponsePayload.KeyReject(kind: .keyReject, keyUuid: requestPayload.keyUuid, requestMessageUuid: requestMessageUuid, senderDeviceId: eventHandler.userProfile.deviceId, recipientDeviceId: requestPayload.deviceId)
        sendMessage(with: .keyReject(keyRejectPayload))
    }

    func sendGrant(for requestPayload: MessagePayload.KeyRequest, requestMessageUuid: String, currentStream: StreamData?) {
        guard let currentStream, let currentUser = eventHandler.ownUser, let keyData = eventHandler.userProfile.keyData(keyUuid: requestPayload.keyUuid, userUuid: currentUser.uuid, streamUuid: currentStream.uuid), let publicKeyData = requestPayload.publicKey.data(using: .utf8), let decodedPublicKeyData = Data(base64Encoded: publicKeyData) else { return }
        do {
            var keyGrantPayload = MessageResponsePayload.KeyGrant(kind: .keyGrant, keyUuid: requestPayload.keyUuid, requestMessageUuid: requestMessageUuid, senderDeviceId: eventHandler.userProfile.deviceId, recipientDeviceId: requestPayload.deviceId, content: "")
            let content = try encryptGroupKeyGrant(groupKey: keyData, recipientPublicKey: decodedPublicKeyData, streamUuid: currentStream.uuid, grantPayload: keyGrantPayload)
            keyGrantPayload.content = content.base64EncodedString()
            sendMessage(with: .keyGrant(keyGrantPayload))
        } catch {
            print(error)
        }
    }

    func loadInitialMessages() {
        loadMessages()
    }

    func loadMessages() {
        apiClient.createPublisher(for: MessagesRequest(streamUuid: model.streamUuid, topicUuid: model.topicUuid, pageLimit: Constants.pageLimit))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                eventHandler.addMessages(response, streamUuid: model.streamUuid, topicUuid: model.topicUuid)
            }
            .store(in: &cancellables)
    }

    func didTapOnCallButton() {
        let generatedCallName = JitsiStyleRoomNameGenerator().generate()
        sendMessage(with: .markdown(.init(kind: .markdown, content: "\(eventHandler.meetUrl)/\(generatedCallName)")))
        jitsiNameItem = .init(jitsiName: generatedCallName)
    }

    func didTapOnCallMessage(with jitsiName: String) {
        jitsiNameItem = .init(jitsiName: jitsiName)
    }

    func keyGrantMessage(for payload: MessagePayload.KeyGrant) -> String {
        do {
            let senderFetchDescriptor = FetchDescriptor<UserData>(predicate: #Predicate{ user in
                user.uuid == payload.senderDeviceId
            })
            let sender = try eventHandler.userProfile.context.fetch(senderFetchDescriptor).first
            let recipientFetchDescriptor = FetchDescriptor<UserData>(predicate: #Predicate{ user in
                user.uuid == payload.recipientDeviceId
            })
            let recipient = try eventHandler.userProfile.context.fetch(recipientFetchDescriptor).first
            return "\(sender?.displayableName ?? "Alice") sent a security key to \(recipient?.displayableName ?? "Bob")"
        } catch {
            return "Alice sent a security key to Bob"
        }
    }

    func keyRequestMessage(for payload: MessagePayload.KeyRequest, authorUuid: String) -> String {
        do {
            let authorFetchDescriptor = FetchDescriptor<UserData>(predicate: #Predicate{ user in
                user.uuid == authorUuid
            })
            let author = try eventHandler.userProfile.context.fetch(authorFetchDescriptor).first
            return "\(author?.displayableName ?? "Alice") requested a security key for device \(payload.deviceName)"
        } catch {
            return "Alice requested a security key for device \(payload.deviceName)"
        }
    }

    func wasRequestFulfilled(payload: MessagePayload.KeyRequest, messageUuid: String, streamUuid: String, topicUuid: String) -> Bool {
        let messagesFetchDescriptor = FetchDescriptor<MessageData>(predicate: #Predicate{ message in
            message.stream?.uuid == streamUuid && message.topic?.uuid == topicUuid
        })
        let messages = try? eventHandler.userProfile.context.fetch(messagesFetchDescriptor)
        if let messages {
            let resultMessages = messages.filter {
                switch $0.payload {
                case let .keyGrant(keyGrant):
                    return keyGrant.requestMessageUuid == messageUuid
                case let .keyReject(keyReject):
                    return keyReject.requestMessageUuid == messageUuid
                default:
                    return false
                }
            }
            return !resultMessages.isEmpty
        } else {
            return false
        }
    }

    func decryptedMessage(from payload: MessagePayload.E2ee, currentStream: StreamData?) -> String? {
        guard let currentStream, let currentUser = eventHandler.ownUser, let keyData = eventHandler.userProfile.keyData(keyUuid: payload.keyUuid, userUuid: currentUser.uuid, streamUuid: currentStream.uuid), let data = Data(base64Encoded: payload.content) else { return nil }

        do {
            let decryptedMessageData = try decryptMessage(groupKey: keyData, envelope: data, streamUuid: currentStream.uuid, keyUuid: payload.keyUuid)
            return String(data: decryptedMessageData, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func validKey(_ key: Data) throws {
        guard key.count == keyBytes else {
            throw ChatCryptoError.invalidKey
        }
    }

    let keyBytes = 32
    let tagBytes = 16

    func decryptMessage(
        groupKey: Data,
        envelope: Data,
        streamUuid: String,
        keyUuid: String
    ) throws -> Data {
        try validKey(groupKey)
        let info = try messageInfo(streamUuid: streamUuid, keyUuid: keyUuid)
        guard envelope.count >= keyBytes + tagBytes else {
            throw ChatCryptoError.invalidCiphertext
        }
        let salt = envelope.prefix(keyBytes)
        var messageKey = HkdfSha256.derive(
            ikm: groupKey,
            salt: Data(salt),
            info: info,
            outputByteCount: keyBytes
        )
        defer { messageKey.resetBytes(in: 0..<messageKey.count) }
        do {
            var aad = Data()
            aad.append(info)
            aad.append(salt)
            return try ChaChaAead.decrypt(
                key: SymmetricKey(data: messageKey),
                nonce: Data(count: 12),
                ciphertext: envelope.suffix(from: keyBytes),
                aad: aad
            )
        } catch {
            throw ChatCryptoError.invalidCiphertext
        }
    }

    func encryptMessage(
        groupKey: Data,
        plaintext: Data,
        streamUuid: String,
        keyUuid: String
    ) throws -> Data {
        try validKey(groupKey)
        let info = try messageInfo(streamUuid: streamUuid, keyUuid: keyUuid)
        let salt = randomBytes(keyBytes)
        var messageKey = HkdfSha256.derive(
            ikm: groupKey,
            salt: salt,
            info: info,
            outputByteCount: keyBytes
        )
        defer { messageKey.resetBytes(in: 0..<messageKey.count) }
        do {
            var aad = Data()
            aad.append(info)
            aad.append(salt)
            let ciphertext = try ChaChaAead.encrypt(
                key: SymmetricKey(data: messageKey),
                nonce: Data(count: 12),
                plaintext: plaintext,
                aad: aad
            )
            var envelope = Data()
            envelope.append(salt)
            envelope.append(ciphertext)
            return envelope
        } catch {
            throw ChatCryptoError.unavailable
        }
    }

    func encryptGroupKeyGrant(
            groupKey: Data,
            recipientPublicKey: Data,
            streamUuid: String,
            grantPayload: MessageResponsePayload.KeyGrant
        ) throws -> Data {
            try validKey(groupKey)
            try validKey(recipientPublicKey)
            let info = try grantInfo(streamUuid: streamUuid, context: grantPayload)
            var ephemeralPrivateKey = randomBytes(keyBytes)
            defer { ephemeralPrivateKey.resetBytes(in: 0..<ephemeralPrivateKey.count) }
            do {
                var aad = Data()
                aad.append(info)
                aad.append(UserProfile.grantMagic)
                aad.append(recipientPublicKey)
                let (enc, ciphertext) = try HpkeBase.seal(
                    recipientPublic: recipientPublicKey,
                    ephemeralPrivate: ephemeralPrivateKey,
                    info: info,
                    aad: aad,
                    plaintext: groupKey
                )
                var envelope = Data()
                envelope.append(UserProfile.grantMagic)
                envelope.append(enc)
                envelope.append(ciphertext)
                return envelope
            } catch {
                throw ChatCryptoError.invalidKey
            }
        }

    private func randomBytes(_ count: Int) -> Data {
        var bytes = Data(count: count)
        bytes.withUnsafeMutableBytes { buf in
            guard let base = buf.baseAddress else { return }
            let status = SecRandomCopyBytes(kSecRandomDefault, count, base)
            precondition(status == errSecSuccess)
        }
        return bytes
    }

    func messageInfo(streamUuid: String, keyUuid: String) throws -> Data {
        if streamUuid.isEmpty || keyUuid.isEmpty {
            throw ChatCryptoError.invalidContext
        }
        return try contextJson([
            "workspace-chat-crypto-v1",
            "message",
            streamUuid,
            keyUuid,
        ])
    }

    func grantInfo(streamUuid: String, context: MessageResponsePayload.KeyGrant) throws -> Data {
        let fields = [
            streamUuid,
            context.keyUuid,
            context.requestMessageUuid,
            context.senderDeviceId,
            context.recipientDeviceId,
        ]
        if fields.contains(where: \.isEmpty) {
            throw ChatCryptoError.invalidContext
        }
        return try contextJson([
            "workspace-chat-crypto-v1",
            "grant",
            streamUuid,
            context.keyUuid,
            context.requestMessageUuid,
            context.senderDeviceId,
            context.recipientDeviceId,
        ])
    }

    enum HkdfSha256 {
        /// RFC 5869 HKDF-SHA256 (not the HPKE labeled Extract/Expand).
        static func derive(ikm: Data, salt: Data, info: Data, outputByteCount: Int) -> Data {
            let key = HKDF<SHA256>.deriveKey(
                inputKeyMaterial: SymmetricKey(data: ikm),
                salt: salt,
                info: info,
                outputByteCount: outputByteCount
            )
            return key.withUnsafeBytes { Data($0) }
        }
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
