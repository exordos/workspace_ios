//
//  MessageData.swift
//  WorkspaceBeta
//
//

import Foundation
import SwiftData

@Model
class MessageData: Hashable, Identifiable {
    @Attribute(.unique) var uuid: String
    var updatedAt: Date
    var createdAt: Date
    var payload: MessagePayload
    var isOwn: Bool
    var authorUuid: String
    var reactions: [String: Int]
    var author: UserData?

    var stream: StreamData?
    var topic: TopicData?

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

    init(with messageResonseData: MessageResponseData, stream: StreamData, topic: TopicData) {
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
    }
}

enum MessagePayload: Codable, Hashable {

    enum Kind: String, Codable {
        case markdown
        case e2ee
        case keyRequest = "key_request"
        case keyGrant = "key_grant"
        case keyReject = "key_reject"
        case keyAnnounced = "key_announced"
        case unknown
    }

    struct Markdown: Codable, Hashable {
        let kind: Kind
        let content: String
    }

    struct E2ee: Hashable, Codable {
        let kind: Kind
        let content: String
        let keyUuid: String
    }

    struct KeyRequest: Hashable, Codable {
        let kind: Kind
        let keyUuid: String
        let deviceId: String
        let deviceName: String
        let publicKey: String
    }

    struct KeyGrant: Hashable, Codable {
        let kind: Kind
        let keyUuid: String
        let requestMessageUuid: String
        let senderDeviceId: String
        let recipientDeviceId: String
        var content: String
    }

    struct KeyReject: Hashable, Codable {
        let kind: Kind
        let keyUuid: String
        let requestMessageUuid: String
        let senderDeviceId: String
        let recipientDeviceId: String
    }

    struct KeyAnnounced: Hashable, Codable {
        let kind: Kind
        let keyUuid: String
    }

    case markdown(Markdown)
    case e2ee(E2ee)
    case keyRequest(KeyRequest)
    case keyGrant(KeyGrant)
    case keyReject(KeyReject)
    case keyAnnounced(KeyAnnounced)
    case undefined
}
