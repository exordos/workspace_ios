//
//  ServerSettingsRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct ServerSettingsRequest: APIRequest {
    typealias Response = ServerSettingsResponseData
    typealias ResponseError = EmptyDecodableError

    var resource: ResourceType  {
        return .absolute("\(possibleBaseUrl)/api/workspace/v1/messenger/server_settings/")
    }

    var method: HTTPMethod {
        return .get
    }

    var requiresApiKey: Bool {
        return false
    }

    private let possibleBaseUrl: String

    func encode(to encoder: Encoder) throws {
        _ = encoder.container(keyedBy: CodingKeys.self)
    }

    enum CodingKeys: CodingKey { }

    init(with possibleBaseUrl: String) {
        self.possibleBaseUrl = possibleBaseUrl
    }
}

struct ServerSettingsRequestData: Decodable {}

struct ServerSettingsResponseData: Decodable {
    let isEmailAuthEnabled: Bool
    let realmName: String
    let meetUrl: String

    enum CodingKeys: String, CodingKey {
        case isEmailAuthEnabled = "email_auth_enabled"
        case realmName = "realm_name"
        case meetUrl = "meet_url"
    }
}
