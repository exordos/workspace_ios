//
//  UserLogInRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct UserLogInRequest: APIRequest {
    typealias Response = UserLogInResponseData
    typealias ResponseError = EmptyDecodableError

    let login: String
    let password: String
    let grantType: String
    let scope: String
    let ttl: String
    let refreshTtl: String

    private let otp: String

    enum CodingKeys: String, CodingKey {
        case login
        case password
        case grantType = "grant_type"
        case scope
        case ttl
        case refreshTtl = "refresh_ttl"
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

    var additionalHeaders: [String : String] {
        return otp.isEmpty ? [:] : ["X-OTP": otp]
    }

    init(with login: String, password: String, otp: String) {
        self.login = login
        self.password = password
        self.grantType = "login+password"
        self.scope = "openid email profile project:fe02e55d-4548-4b3e-a175-fcae928f41b2"
        self.ttl = "3600"
        self.refreshTtl = "172800"
        self.otp = otp
    }
}

struct UserLogInResponseData: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
