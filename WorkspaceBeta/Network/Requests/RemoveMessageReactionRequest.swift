//
//  RemoveMessageReactionRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct RemoveMessageReactionRequest: APIRequest {
    typealias Response = RemoveMessageReactionResponseData
    typealias ResponseError = EmptyDecodableError

    let reactionUuid: String

    enum CodingKeys: CodingKey { }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/message_reactions/\(reactionUuid)")
    }

    var method: HTTPMethod {
        return .delete
    }

    init(with reactionUuid: String) {
        self.reactionUuid = reactionUuid
    }
}

struct RemoveMessageReactionResponseData: Decodable { }
