//
//  OwnUserRequest.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 25.03.2026.
//

import Foundation

struct OwnUserRequest: APIRequest {
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

struct OwnUserRequestData: Decodable {}

struct OwnUserResponseData: Decodable {
    let avatarUrl: String
    let email: String
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
        case fullName = "full_name"
        case email
    }
}
