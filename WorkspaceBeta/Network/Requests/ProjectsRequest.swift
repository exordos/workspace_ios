//
//  ProjectsRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct ProjectsRequest: APIRequest {
    typealias Response = [ProjectResponseData]
    typealias ResponseError = EmptyDecodableError

    var resource: ResourceType {
        return .relative("/api/core/v1/iam/projects/")
    }

    var method: HTTPMethod {
        return .get
    }
}

struct ProjectResponseData: Decodable, Hashable {
    let uuid: String
    let name: String
    let description: String
}
