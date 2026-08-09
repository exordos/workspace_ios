//
//  AddFolderRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct AddFolderRequest: APIRequest {
    typealias Response = AddFolderResponseData
    typealias ResponseError = EmptyDecodableError

    let title: String

    var resource: ResourceType {
        return .relative("/api/core/v1/iam/clients/default/actions/get_token/invoke")
    }

    var method: HTTPMethod {
        return .post
    }

    init(title: String) {
        self.title = title
    }
}

struct AddFolderResponseData: Decodable {
    let uuid: String
}
