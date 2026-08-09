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

    enum CodingKeys: String, CodingKey {
        case streamUuid = "stream_uuid"
        case topicUuid = "topic_uuid"
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/messages/")
    }

    var method: HTTPMethod {
        return .get
    }

    init(streamUuid: String, topicUuid: String) {
        self.streamUuid = streamUuid
        self.topicUuid = topicUuid
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


struct MessageResponseData: Decodable, Hashable {
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
}

struct MessageResponsePayload: Decodable, Hashable {

    enum Kind: String, Decodable {
        case markdown
    }

    let kind: Kind
    let content: String
}
