//
//  UserLogInRequest.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 22.02.2026.
//

import Foundation

struct UserLogInRequest: APIRequest {
    typealias Response = UserLogInResponseData
    typealias ResponseError = EmptyDecodableError

    let username: String
    let password: String

    var resource: ResourceType {
        return .relative("/api/v1/fetch_api_key")
    }

    var method: HTTPMethod {
        return .post
    }

    var requiresApiKey: Bool {
        return false
    }

    init(with login: String, password: String) {
        self.username = login
        self.password = password
    }
}

struct UserLogInResponseData: Decodable {
    let apiKey: String
    let userId: Int
    let email: String

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case userId = "user_id"
        case email
    }
}
