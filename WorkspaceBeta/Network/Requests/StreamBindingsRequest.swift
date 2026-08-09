//
//  StreamBindingsRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct StreamBindingsRequest: APIRequest {
    typealias Response = [StreamBindingResponseData]
    typealias ResponseError = EmptyDecodableError


    let streamUuid: String

    enum CodingKeys: String, CodingKey {
        case streamUuid = "stream_uuid"
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/stream_bindings/")
    }

    var method: HTTPMethod {
        return .get
    }

    init(with streamUuid: String) {
        self.streamUuid = streamUuid
    }
}


struct StreamBindingResponseData: Decodable {
    let uuid: String
    var role: String
    let streamUuid: String
    let userUuid: String

    var id: String {
        return uuid
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case role
        case streamUuid = "stream_uuid"
        case userUuid = "user_uuid"
    }
}
