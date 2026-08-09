//
//  AddChatToFolderRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct AddChatToFolderRequest: APIRequest {
    typealias Response = AddChatToFolderResponseData
    typealias ResponseError = EmptyDecodableError

    let chatUuid: String
    let chatType: String
    let folderUuid: String

    enum CodingKeys: String, CodingKey {
        case chatUuid = "chat_uuid"
        case chatType = "chat_type"
    }

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/folders/\(folderUuid)/items/")
    }

    var method: HTTPMethod {
        return .post
    }

    init(chatUuid: String, chatType: String, folderUuid: String) {
        self.chatUuid = chatUuid
        self.chatType = chatType
        self.folderUuid = folderUuid
    }
}

struct AddChatToFolderResponseData: Decodable {}
