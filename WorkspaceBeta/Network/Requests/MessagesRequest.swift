//
//  MessagesRequest.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 25.03.2026.
//

import Foundation

struct MessagesRequest: APIRequest {
    typealias Response = MessagesResponseData
    typealias ResponseError = EmptyDecodableError

    let anchor: String
    let numBefore: String
    let numAfter: String
    let narrow: String
    let applyMarkdown: String

    enum CodingKeys: String, CodingKey {
        case anchor
        case numBefore = "num_before"
        case numAfter = "num_after"
        case narrow
        case applyMarkdown = "apply_markdown"
    }

    var resource: ResourceType {
        return .relative("/api/v1/messages")
    }

    var method: HTTPMethod {
        return .get
    }

    init(anchor: String,
         numBefore: String,
         numAfter: String,
         narrow: String,
         applyMarkdown: String) {
        self.anchor = anchor
        self.numBefore = numBefore
        self.numAfter = numAfter
        self.narrow = narrow
        self.applyMarkdown = applyMarkdown
    }
}

struct MessagesResponseData: Decodable {
    let messages: [MessageData]
}

enum MessageData: Decodable {
    case direct(DirectMessageData)
    case channel(ChannelMessageData)

    enum CodingKeys: String, CodingKey {
        case type
    }

    enum MessageType: String, Decodable {
        case `private`
        case channel
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .private:
            let value = try DirectMessageData(from: decoder)
            self = .direct(value)
        case .channel:
            let value = try ChannelMessageData(from: decoder)
            self = .channel(value)
        }
    }
}

struct DirectMessageData: Decodable {
    let id: Int
    let senderFullName: String
    let senderId: Int
    let content: String
    let timestamp: Int
    let avatarUrl: String
    let subject: String
    let displayRecipient: [DisplayRecipient]


    enum CodingKeys: String, CodingKey {
        case id
        case senderFullName = "sender_full_name"
        case senderId = "sender_id"
        case content
        case timestamp
        case avatarUrl = "avatar_url"
        case subject
        case displayRecipient = "display_recipient"
    }
}

struct DisplayRecipient: Decodable, Hashable {
    let id: Int
    let email: String
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
    }
}

struct ChannelMessageData: Decodable {
    let id: Int
    let senderFullName: String
    let senderId: Int
    let content: String
    let timestamp: Int
    let avatarUrl: String
    let subject: String
    let displayRecipient: String

    enum CodingKeys: String, CodingKey {
        case id
        case senderFullName = "sender_full_name"
        case senderId = "sender_id"
        case content
        case timestamp
        case avatarUrl = "avatar_url"
        case subject
        case displayRecipient = "display_recipient"
    }
}
