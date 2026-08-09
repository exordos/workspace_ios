//
//  FoldersRequest.swift
//  WorkspaceBeta
//
//

import Foundation

struct FoldersRequest: APIRequest {
    typealias Response = [FolderResponseData]
    typealias ResponseError = EmptyDecodableError

    var resource: ResourceType {
        return .relative("/api/workspace/v1/messenger/folders/")
    }

    var method: HTTPMethod {
        return .get
    }
}

struct FolderResponseData: Decodable, Hashable {
    let uuid: String
    var title: String
    let systemType: FolderSystemType
    let createdAt: Date
    var unreadCount: Int
    var folderItems: [FolderItem]?

    enum CodingKeys: String, CodingKey {
        case uuid
        case title
        case systemType = "system_type"
        case createdAt = "created_at"
        case folderItems = "folder_items"
        case unreadCount = "unread_count"
    }
}

struct FolderItem: Decodable, Hashable  {
    let uuid: String
    let streamUuid: String
    let chatType: FolderItemChatType
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case uuid
        case streamUuid = "stream_uuid"
        case chatType = "chat_type"
        case unreadCount = "unread_count"
    }
}

enum FolderItemChatType: String, Decodable {
    case stream
    case `private`
}

enum FolderSystemType: String, Decodable {
    case all
    case created
}
