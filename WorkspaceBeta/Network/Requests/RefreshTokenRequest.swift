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
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
        case scope
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

    init(with refreshToken: String, scope: String? = nil) {
        self.grantType = "refresh_token"
        self.refreshToken = refreshToken
        self.scope = scope
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
