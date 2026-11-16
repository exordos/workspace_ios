//
//  AddStreamRequest.swift
//  Workspace
//
//

import Foundation

struct AddStreamRequest: APIRequest {
    typealias Response = StreamResponseData
    typealias ResponseError = EmptyDecodableError

    let name: String
    let description: String
    let directUserUuid: String?
    let isEncrypted: Bool
    let currentEncryptionKeyUuid: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case directUserUuid = "direct_user_uuid"
        case isEncrypted = "encryption"
        case currentEncryptionKeyUuid = "current_encryption_key_uuid"
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/streams/")
    }

    var method: HTTPMethod {
        return .post
    }

    init(with name: String, description: String, directUserUuid: String?, isEncrypted: Bool, currentEncryptionKeyUuid: String?) {
        self.name = name
        self.description = description
        self.directUserUuid = directUserUuid
        self.isEncrypted = isEncrypted
        self.currentEncryptionKeyUuid = currentEncryptionKeyUuid
    }
}

struct AddStreamResponseData: Decodable {}
