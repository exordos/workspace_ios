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
    let payload: MessageRequestDataPayload

    enum CodingKeys: String, CodingKey {
        case payload
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/messages/\(messageId)")
    }

    var method: HTTPMethod {
        return .put
    }

    init(with messageId: String, content: String) {
        self.messageId = messageId
        self.payload = .init(kind: "markdown", content: content)
    }
}

struct EditMessageRequestData: Encodable {
    let payload: MessageRequestDataPayload
}

struct EditMessageResponseData: Decodable { }
