//
//  MessagesRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct MessagesRequest: APIRequest {
    typealias Response = [MessageResponseData]
    typealias ResponseError = EmptyDecodableError

    let streamUuid: String
    let topicUuid: String
    let pageLimit: Int
    let sortKey = "created_at"
    let sortDir = "desc"

    enum CodingKeys: String, CodingKey {
        case streamUuid = "stream_uuid"
        case topicUuid = "topic_uuid"
        case pageLimit = "page_limit"
        case sortKey = "sort_key"
        case sortDir = "sort_dir"
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/messages/")
    }

    var method: HTTPMethod {
        return .get
    }

    init(streamUuid: String, topicUuid: String, pageLimit: Int) {
        self.streamUuid = streamUuid
        self.topicUuid = topicUuid
        self.pageLimit = pageLimit
    }
}

struct MessagesByIdsRequest: APIRequest {
    typealias Response = [MessageResponseData]
    typealias ResponseError = EmptyDecodableError

    let uuid: [String]

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/messages/")
    }

    var method: HTTPMethod {
        return .get
    }

    init(messageIds: [String]) {
        self.uuid = messageIds
    }
}

struct MentionedMessagesRequest: APIRequest {
    typealias Response = [MessageResponseData]
    typealias ResponseError = EmptyDecodableError

    let mentioned = true

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/messages/")
    }

    var method: HTTPMethod {
        return .get
    }
}



struct MessageResponseData: Decodable, Hashable, Identifiable {
    let uuid: String
    let updatedAt: Date
    let createdAt: Date
    let streamUuid: String
    let topicUuid: String
    var payload: MessageResponsePayload
    let isOwn: Bool
    let authorUuid: String
    var reactions: [String: Int]
    var author: UserResponseData?

    var id: String {
        return uuid
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case streamUuid = "stream_uuid"
        case topicUuid = "topic_uuid"
        case payload
        case isOwn = "is_own"
        case authorUuid = "author_uuid"
        case reactions
    }

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
}

enum MessageResponsePayload: Codable, Hashable {

    struct MessageKind: Codable {
        let kind: Kind
    }

    enum Kind: String, Codable {
        case markdown
        case e2ee
        case keyRequest = "key_request"
        case keyGrant = "key_grant"
        case keyReject = "key_reject"
        case keyAnnounced = "key_announced"
        case unknown

        init(from decoder: Decoder) throws {
            self = try MessageResponsePayload.Kind(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
        }
    }

    struct Markdown: Codable, Hashable {
        let kind: Kind
        let content: String

        enum CodingKeys: String, CodingKey {
            case kind
            case content
        }
    }

    struct E2ee: Codable, Hashable {
        let kind: Kind
        let content: String
        let keyUuid: String

        enum CodingKeys: String, CodingKey {
            case kind
            case content
            case keyUuid = "key_uuid"
        }
    }

    struct KeyRequest: Codable, Hashable {
        let kind: Kind
        let keyUuid: String
        let deviceId: String
        let deviceName: String
        let publicKey: String

        enum CodingKeys: String, CodingKey {
            case kind
            case keyUuid = "key_uuid"
            case deviceId = "device_id"
            case deviceName = "device_name"
            case publicKey = "public_key"
        }
    }

    struct KeyGrant: Codable, Hashable {
        let kind: Kind
        let keyUuid: String
        let requestMessageUuid: String
        let senderDeviceId: String
        let recipientDeviceId: String
        var content: String

        enum CodingKeys: String, CodingKey {
            case kind
            case keyUuid = "key_uuid"
            case requestMessageUuid = "request_message_uuid"
            case senderDeviceId = "sender_device_id"
            case recipientDeviceId = "recipient_device_id"
            case content
        }
    }

    struct KeyReject: Codable, Hashable {
        let kind: Kind
        let keyUuid: String
        let requestMessageUuid: String
        let senderDeviceId: String
        let recipientDeviceId: String

        enum CodingKeys: String, CodingKey {
            case kind
            case keyUuid = "key_uuid"
            case requestMessageUuid = "request_message_uuid"
            case senderDeviceId = "sender_device_id"
            case recipientDeviceId = "recipient_device_id"
        }
    }

    struct KeyAnnounced: Codable, Hashable {
        let kind: Kind
        let keyUuid: String

        enum CodingKeys: String, CodingKey {
            case kind
            case keyUuid = "key_uuid"
        }
    }

    case markdown(Markdown)
    case e2ee(E2ee)
    case keyRequest(KeyRequest)
    case keyGrant(KeyGrant)
    case keyReject(KeyReject)
    case keyAnnounced(KeyAnnounced)
    case undefined

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let messageKind = try container.decode(MessageKind.self)

        do {
            switch messageKind.kind {
            case .markdown:
                let markdownPayload = try container.decode(Markdown.self)
                self = .markdown(markdownPayload)
            case .e2ee:
                let e2eePayload = try container.decode(E2ee.self)
                self = .e2ee(e2eePayload)
            case .keyRequest:
                let keyRequestPayload = try container.decode(KeyRequest.self)
                self = .keyRequest(keyRequestPayload)
            case .keyGrant:
                let keyGrantPayload = try container.decode(KeyGrant.self)
                self = .keyGrant(keyGrantPayload)
            case .keyReject:
                let keyRejectPayload = try container.decode(KeyReject.self)
                self = .keyReject(keyRejectPayload)
            case .keyAnnounced:
                let keyAnnouncedPayload = try container.decode(KeyAnnounced.self)
                self = .keyAnnounced(keyAnnouncedPayload)
            case .unknown:
                self = .undefined
            }
        } catch {
            self = .undefined
        }
    }

    enum CodingKeys: CodingKey {
        case markdown
        case e2ee
        case keyRequest
        case keyGrant
        case keyReject
        case keyAnnounced
        case undefined
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case let .markdown(markdownPayload):
            try markdownPayload.encode(to: encoder)
        case let .e2ee(e2eePayload):
            try e2eePayload.encode(to: encoder)
        case let .keyRequest(keyRequestPayload):
            try keyRequestPayload.encode(to: encoder)
        case let .keyGrant(keyGrantPayload):
            try keyGrantPayload.encode(to: encoder)
        case let .keyReject(keyRejectPayload):
            try keyRejectPayload.encode(to: encoder)
        case let .keyAnnounced(keyAnnouncedPayload):
            try keyAnnouncedPayload.encode(to: encoder)
        case .undefined:
            throw APIError.encoding
        }
    }
}
