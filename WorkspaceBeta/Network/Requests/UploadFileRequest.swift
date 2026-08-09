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
        return .relative("/user_uploads")
    }

    var method: HTTPMethod {
        return .post
    }
}

struct UploadFileResponseData: Decodable {
    let url: String
    let filename: String
}
