//
//  FolderData.swift
//  Workspace
//
//

import Foundation
import SwiftData

@Model
class FolderData: Hashable {
    @Attribute(.unique) var uuid: String
    var title: String
    var systemType: FolderSystemType
    var createdAt: Date
    var unreadCount: Int

    @Relationship(deleteRule: .cascade, inverse:\FolderItemData.folder)
    var folderItems: [FolderItemData] = []

    init(with folderData: FolderResponseData) {
        self.uuid = folderData.uuid
        self.title = folderData.title
        self.systemType = folderData.systemType
        self.createdAt = folderData.createdAt
        self.unreadCount = folderData.unreadCount
    }
}
