//
//  ResetAvatarRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct ResetAvatarRequest: APIRequest {
    typealias Response = ResetAvatarResponseData
    typealias ResponseError = EmptyDecodableError

    let userUuid: String

    enum CodingKeys: CodingKey { }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/users/\(userUuid)/actions/avatar_reset/invoke")
    }

    var method: HTTPMethod {
        return .post
    }

    init(with userUuid: String) {
        self.userUuid = userUuid
    }
}

struct ResetAvatarResponseData: Decodable { }
