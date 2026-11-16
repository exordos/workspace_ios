//
//  EditMessageRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct EditMessageRequest: APIRequest {
    typealias Response = RefreshTokenResponseData
    typealias ResponseError = EmptyDecodableError

    let messageId: String
    let payload: MessagePayload

    enum CodingKeys: String, CodingKey {
        case payload
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/messages/\(messageId)")
    }

    var method: HTTPMethod {
        return .put
    }

    init(with messageId: String, payload: MessagePayload) {
        self.messageId = messageId
        self.payload = payload
    }
}

struct EditMessageResponseData: Decodable { }
