//
//  AddStreamRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct AddStreamRequest: APIRequest {
    typealias Response = RefreshTokenResponseData
    typealias ResponseError = EmptyDecodableError

    let name: String
    let description: String
    let directUserUuid: String?
    let sourceName: String
    let source: AddStreamRequestSource

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case directUserUuid = "direct_user_uuid"
        case sourceName = "source_name"
        case source
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/streams/")
    }

    var method: HTTPMethod {
        return .post
    }

    init(with name: String, description: String, directUserUuid: String?) {
        self.name = name
        self.description = description
        self.directUserUuid = directUserUuid
        self.sourceName = "native"
        self.source = .init()
    }
}

struct AddStreamRequestSource: Encodable {
    let kind: String = "native"
}

struct AddStreamResponseData: Decodable {}
