//
//  SendMessageRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct SendMessageRequest: APIRequest {
    typealias Response = SendMessageResponseData
    typealias ResponseError = EmptyDecodableError

    let streamUuid: String
    let topicUuid: String?
    let payload: MessageRequestDataPayload

    enum CodingKeys: String, CodingKey {
        case streamUuid = "stream_uuid"
        case topicUuid = "topic_uuid"
        case payload
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/messages/")
    }

    var method: HTTPMethod {
        return .post
    }

    init(streamUuid: String, topicUuid: String?, content: String) {
        self.streamUuid = streamUuid
        self.topicUuid = topicUuid
        self.payload = .init(kind: "markdown", content: content)
    }
}

struct MessageRequestDataPayload: Encodable {
    let kind: String
    let content: String
}

struct SendMessageResponseData: Decodable {
    let uuid: String
}
