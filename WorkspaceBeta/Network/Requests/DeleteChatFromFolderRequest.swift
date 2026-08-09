//
//  DeleteChatFromFolderRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct DeleteChatFromFolderRequest: APIRequest {
    typealias Response = DeleteChatFromFolderResponseData
    typealias ResponseError = EmptyDecodableError

    let folderUuid: String
    let folderChatUuid: String

    enum CodingKeys: CodingKey { }

    var resource: ResourceType {
        return .relative("/workspace/v1/folders/\(folderUuid)/items/\(folderChatUuid)")
    }

    var method: HTTPMethod {
        return .delete
    }

    init(with folderUuid: String, folderChatUuid: String) {
        self.folderUuid = folderUuid
        self.folderChatUuid = folderChatUuid
    }
}

struct DeleteChatFromFolderResponseData: Decodable { }
