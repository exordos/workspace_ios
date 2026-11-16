//
//  FolderItemData.swift
//  Workspace
//
//

import Foundation
import SwiftData

@Model
class FolderItemData: Hashable  {
    @Attribute(.unique) var uuid: String
    var chatType: FolderItemChatType
    var unreadCount: Int

    var stream: StreamData?

    var folder: FolderData?

    init(with folderItem: FolderItem, stream: StreamData, folder: FolderData) {
        self.uuid = folderItem.uuid
        self.chatType = folderItem.chatType
        self.unreadCount = folderItem.unreadCount
        self.stream = stream
        self.folder = folder
    }
}
