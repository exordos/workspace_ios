//
//  UpdateStreamNotificationModeRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct UpdateStreamNotificationModeRequest: APIRequest {
    typealias Response = UpdateStreamNotificationModeResponseData
    typealias ResponseError = EmptyDecodableError

    let streamUuid: String
    let notificationMode: String

    enum CodingKeys: String, CodingKey {
        case notificationMode = "notification_mode"
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/streams/\(streamUuid)/actions/notifications/invoke")
    }

    var method: HTTPMethod {
        return .post
    }

    init(streamUuid: String, notificationMode: String) {
        self.streamUuid = streamUuid
        self.notificationMode = notificationMode
    }
}

struct UpdateStreamNotificationModeResponseData: Decodable {}
