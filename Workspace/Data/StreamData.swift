//
//  StreamData.swift
//  Workspace
//
//

import Foundation
import SwiftData

@Model
class StreamData: Identifiable, Hashable {
    @Attribute(.unique) var uuid: String
    var unreadCount: Int
    var activeUnreadCount: Int
    var passiveUnreadCount: Int
    var name: String
    var isPrivate: Bool
    var color: Int
    var hasEncryption: Bool
    var isArchived: Bool
    var currentEncryptionKeyUuid: String?
    var defaultTopicUuid: String?
    var notificationMode: String
    var role: String

    @Relationship(deleteRule: .cascade, inverse:\TopicData.stream)
    var topics: [TopicData] = []
    
    var folderItems: [FolderItemData] = []

    var directUser: UserData?

    @Relationship(deleteRule: .cascade, inverse:\MessageData.stream)
    var messages: [MessageData] = []

    @Relationship(deleteRule: .cascade, inverse:\LastMessageData.stream)
    var lastMessages: [LastMessageData] = []

    @Relationship(deleteRule: .cascade, inverse:\StreamBindingData.stream)
    var streamBindings: [StreamBindingData] = []

    init(from streamResponseData: StreamResponseData) {
        self.uuid = streamResponseData.uuid
        self.unreadCount = streamResponseData.unreadCount
        self.activeUnreadCount = streamResponseData.activeUnreadCount
        self.passiveUnreadCount = streamResponseData.passiveUnreadCount
        self.name = streamResponseData.name
        self.isPrivate = streamResponseData.isPrivate
        self.color = streamResponseData.color
        self.isArchived = streamResponseData.isArchived
        self.hasEncryption = streamResponseData.hasEncryption
        self.currentEncryptionKeyUuid = streamResponseData.currentEncryptionKeyUuid
        self.defaultTopicUuid = streamResponseData.defaultTopicUuid
        self.notificationMode = streamResponseData.notificationMode
        self.role = streamResponseData.role
    }

    var avatarString: String? {
        guard isPrivate, let avatar = directUser?.avatar else { return nil }

        return avatar
    }
}

extension StreamData {
    var lastMessage: LastMessageData? {
        guard !lastMessages.isEmpty else { return nil }
        
        return lastMessages.sorted { $0.createdAt > $1.createdAt }.first
    }
}
