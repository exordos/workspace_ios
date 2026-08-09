//
//  RefreshTokenRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct RefreshTokenRequest: APIRequest {
    typealias Response = RefreshTokenResponseData
    typealias ResponseError = EmptyDecodableError

    let grantType: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
    }

    var resource: ResourceType {
        return .relative("/api/core/v1/iam/clients/default/actions/get_token/invoke")
    }

    var method: HTTPMethod {
        return .post
    }

    var requiresApiKey: Bool {
        return false
    }

    init(with refreshToken: String) {
        self.grantType = "refresh_token"
        self.refreshToken = refreshToken
    }
}

struct RefreshTokenResponseData: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
