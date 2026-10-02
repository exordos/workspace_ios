//
//  UploadFileRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct UploadFileRequest: APIRequest {
    typealias Response = UploadFileResponseData
    typealias ResponseError = EmptyDecodableError

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/files/")
    }

    var method: HTTPMethod {
        return .post
    }
}

struct UploadFileResponseData: Decodable {
    let uuid: String
    let name: String
}
