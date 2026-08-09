//
//  StreamsStreamsRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct StreamsRequest: APIRequest {
    typealias Response = [StreamData]
    typealias ResponseError = EmptyDecodableError

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/streams/")
    }

    var method: HTTPMethod {
        return .get
    }
}


struct StreamData: Decodable, Identifiable, Hashable {
    let uuid: String
    var unreadCount: Int
    let name: String
    let isPrivate: Bool
    let color: Int
    var lastMessageUuid: String?
    var lastMessage: MessageResponseData?
    let defaultTopicUuid: String?
    var notificationMode: String

    var id: String {
        return uuid
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case unreadCount = "unread_count"
        case name
        case isPrivate = "private"
        case color
        case lastMessageUuid = "last_message_uuid"
        case defaultTopicUuid = "default_topic_uuid"
        case notificationMode = "notification_mode"
    }

    var avatarString: String? {
        guard isPrivate, let avatar = lastMessage?.author?.avatar else { return nil }

        return avatar
    }
}
