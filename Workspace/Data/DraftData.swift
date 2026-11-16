//
//  DraftData.swift
//  Workspace
//
//

import Foundation
import SwiftData

@Model
class DraftData: Hashable {
    @Attribute(.unique) var uuid: String
    var payload: MessagePayload
    var updatedAt: Date
    var revision: Int

    var stream: StreamData?
    var topic: TopicData?

    init(with draftResponseData: DraftResponseData, stream: StreamData, topic: TopicData) {
        self.uuid = draftResponseData.uuid
        let payload: MessagePayload
        switch draftResponseData.payload {
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
        self.updatedAt = draftResponseData.updatedAt
        self.revision = draftResponseData.revision
        self.stream = stream
        self.topic = topic
    }
}
