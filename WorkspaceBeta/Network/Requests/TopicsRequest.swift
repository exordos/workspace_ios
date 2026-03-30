//
//  TopicsRequest.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 25.03.2026.
//

import Foundation

struct TopicsRequest: APIRequest {
    typealias Response = OwnUserRequestData
    typealias ResponseError = EmptyDecodableError

    var resource: ResourceType {
        return .relative("api/v1/users/me")
    }

    var method: HTTPMethod {
        return .get
    }

    var requiresApiKey: Bool {
        return true
    }

    init() { }
}

struct TopicsRequestData: Decodable {}

struct TopicsResponseData: Decodable {
    let topics: [TopicResponse]
}

struct TopicResponse: Decodable {
    let maxId: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case maxId = "max_id"
        case name
    }
}
