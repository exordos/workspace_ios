//
//  MarkMessagesReadRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct MarkMessagesReadRequest: APIRequest {
    typealias Response = MarkMessagesReadResponseData
    typealias ResponseError = EmptyDecodableError

    let messageUuid: String

    enum CodingKeys: CodingKey {}

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/messages/\(messageUuid)/actions/read_up_to/invoke")
    }

    var method: HTTPMethod {
        return .post
    }

    init(with messageUuid: String) {
        self.messageUuid = messageUuid
    }
}

struct MarkMessagesReadResponseData: Decodable { }
