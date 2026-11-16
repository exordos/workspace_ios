//
//  MessageReactionsRequest.swift
//  Workspace
//
//

import Foundation

struct MessageReactionsRequest: APIRequest {
    typealias Response = [MessageReactionResponseData]
    typealias ResponseError = EmptyDecodableError

    let userUuid: String

    enum CodingKeys: String, CodingKey {
        case userUuid = "user_uuid"
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/message_reactions/")
    }

    var method: HTTPMethod {
        return .get
    }

    init(userUuid: String) {
        self.userUuid = userUuid
    }
}


struct MessageReactionResponseData: Decodable {
    let uuid: String
    let userUuid: String
    let emojiName: String
    let messageUuid: String

    enum CodingKeys: String, CodingKey {
        case uuid
        case userUuid = "user_uuid"
        case emojiName = "emoji_name"
        case messageUuid = "message_uuid"
    }
}
