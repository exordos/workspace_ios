//
//  SendMessageRequest.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 25.03.2026.
//

import Foundation

struct SendMessageRequest: APIRequest {
    typealias Response = SendMessageResponseData
    typealias ResponseError = EmptyDecodableError

    let type: String
    let to: String
    let content: String
    let topic: String?

    var resource: ResourceType {
        return .relative("/api/v1/messages")
    }

    var method: HTTPMethod {
        return .post
    }

    var requiresApiKey: Bool {
        return true
    }

    init(type: String, to: String, content: String, topic: String? = nil) {
        self.type = type
        self.to = to
        self.content = content
        self.topic = topic
    }
}

struct SendMessageResponseData: Decodable {
    let id: Int
}
