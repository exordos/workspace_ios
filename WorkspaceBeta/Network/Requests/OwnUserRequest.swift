//
//  OwnUserRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct OwnUserRequest: APIRequest {
    typealias Response = UserResponseData
    typealias ResponseError = EmptyDecodableError

    var resource: ResourceType {
        return .relative("/api/workspace/v1/me/")
    }

    var method: HTTPMethod {
        return .get
    }
}

struct OwnUserRequestData: Decodable {}
