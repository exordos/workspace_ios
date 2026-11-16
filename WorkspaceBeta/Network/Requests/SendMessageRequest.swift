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
    let payload: MessageResponsePayload

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

    init(streamUuid: String, topicUuid: String?, payload: MessageResponsePayload) {
        self.streamUuid = streamUuid
        self.topicUuid = topicUuid
        self.payload = payload
    }
}

struct SendMessageResponseData: Decodable {
    let uuid: String
}
