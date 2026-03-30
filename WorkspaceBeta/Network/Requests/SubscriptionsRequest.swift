//
//  SubscriptionsRequest.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 25.03.2026.
//

import Foundation

struct SubscriptionsRequest: APIRequest {
    typealias Response = SubscriptionRequestData
    typealias ResponseError = EmptyDecodableError

    var resource: ResourceType {
        return .relative("api/v1/users/me/subscriptions")
    }

    var method: HTTPMethod {
        return .get
    }

    var requiresApiKey: Bool {
        return true
    }

    init() { }
}

struct SubscriptionRequestData: Decodable {}

struct SubscriptionsResponseData: Decodable {
    let subscriptions: [SubscriptionData]
}

struct SubscriptionData: Decodable {
    let streamId: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case streamId = "stream_id"
        case name = "name"
    }
}
