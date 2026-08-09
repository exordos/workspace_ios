//
//  ToggleTopicDoneRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct ToggleTopicDoneRequest: APIRequest {
    typealias Response = ToggleTopicDoneResponseData
    typealias ResponseError = EmptyDecodableError

    let topicUuid: String

    enum CodingKeys: CodingKey { }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/stream_topics/\(topicUuid)/actions/toggle_done/invoke")
    }

    var method: HTTPMethod {
        return .post
    }

    init(with topicUuid: String) {
        self.topicUuid = topicUuid
    }
}

struct ToggleTopicDoneResponseData: Decodable { }
