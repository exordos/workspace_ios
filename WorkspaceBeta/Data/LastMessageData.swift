//
//  LastMessageData.swift
//  WorkspaceBeta
//
//

import Foundation
import SwiftData

@Model
class LastMessageData: Hashable, Identifiable {
    @Attribute(.unique) var uuid: String
    var updatedAt: Date
    var createdAt: Date
    var payload: MessagePayload
    var isOwn: Bool
    var authorUuid: String
    var reactions: [String: Int]

    var stream: StreamData?
    var topic: TopicData?
    var author: UserData?

    var thumbnail: String {
        switch payload {
        case .markdown(let markdownMessage):
            markdownMessage.content
        case .e2ee(let e2eeMessage):
            ""
        case .keyRequest(let keyRequestMessage):
            ""
        case .keyGrant(let keyGrantMessage):
            ""
        case .keyReject(let keyRejectMessage):
            ""
        case .keyAnnounced(let keyAnnouncedMessage):
            ""
        case .undefined:
            ""
        }
    }

    init(with messageResonseData: MessageResponseData, stream: StreamData, topic: TopicData, author: UserData) {
        self.uuid = messageResonseData.uuid
        self.updatedAt = messageResonseData.updatedAt
        self.createdAt = messageResonseData.createdAt
        self.isOwn = messageResonseData.isOwn
        self.authorUuid = messageResonseData.authorUuid
        self.reactions = messageResonseData.reactions
        let payload: MessagePayload
        switch messageResonseData.payload {
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
        self.payload = payload
        self.stream = stream
        self.topic = topic
        self.author = author
    }
}
