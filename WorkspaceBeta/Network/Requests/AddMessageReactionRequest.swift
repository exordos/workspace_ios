//
//  AddMessageReactionRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct AddMessageReactionRequest: APIRequest {
    typealias Response = AddMessageReactionResponseData
    typealias ResponseError = EmptyDecodableError

    let messageUuid: String
    let emojiName: String

    enum CodingKeys: String, CodingKey {
        case messageUuid = "message_uuid"
        case emojiName = "emoji_name"
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/message_reactions/")
    }

    var method: HTTPMethod {
        return .post
    }

    init(with messageUuid: String, emojiName: String) {
        self.messageUuid = messageUuid
        self.emojiName = emojiName
    }
}

struct AddMessageReactionResponseData: Decodable { }
