//
//  TopicsRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct TopicsRequest: APIRequest {
    typealias Response = [TopicsResponseData]
    typealias ResponseError = EmptyDecodableError

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/stream_topics/")
    }

    var method: HTTPMethod {
        return .get
    }

    private let streamUuid: String

    enum CodingKeys: String, CodingKey {
        case streamUuid = "stream_uuid"
    }

    init(streamUuid: String) {
        self.streamUuid = streamUuid
    }
}

struct TopicsRequestData: Decodable { }

struct TopicsResponseData: Decodable, Identifiable, Hashable {
    let uuid: String
    let streamUuid: String
    var unreadCount: Int
    var name: String
    var isDone: Bool
    var isDefault: Bool
    var color: Int
    var updatedAt: Date
    var lastMessageUuid: String?
    var lastMessage: MessageResponseData?
    var notificationMode: String

    var id: String {
        return uuid
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case unreadCount = "unread_count"
        case name
        case isDone = "is_done"
        case isDefault = "is_default"
        case color
        case lastMessageUuid = "last_message_uuid"
        case streamUuid = "stream_uuid"
        case updatedAt = "updated_at"
        case notificationMode = "notification_mode"
    }
}
