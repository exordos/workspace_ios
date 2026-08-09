//
//  UpdateTopicNotificationModeRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct UpdateTopicNotificationModeRequest: APIRequest {
    typealias Response = UpdateTopicNotificationModeResponseData
    typealias ResponseError = EmptyDecodableError

    let topicUuid: String
    let notificationMode: String

    enum CodingKeys: String, CodingKey {
        case notificationMode = "notification_mode"
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/stream_topics/\(topicUuid)/actions/notifications/invoke")
    }

    var method: HTTPMethod {
        return .post
    }

    init(topicUuid: String, notificationMode: String) {
        self.topicUuid = topicUuid
        self.notificationMode = notificationMode
    }
}

struct UpdateTopicNotificationModeResponseData: Decodable {}
