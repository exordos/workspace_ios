//
//  TopicData.swift
//  Workspace
//
//

import Foundation
import SwiftData

@Model
class TopicData: Identifiable, Hashable {
    @Attribute(.unique) var uuid: String
    var unreadCount: Int
    var activeUnreadCount: Int
    var name: String
    var isDone: Bool
    var isDefault: Bool
    var color: Int
    var updatedAt: Date
    var notificationMode: TopicNotificationMode


    var stream: StreamData?
    
    @Relationship(deleteRule: .cascade, inverse:\MessageData.topic)
    var messages: [MessageData] = []

    @Relationship(deleteRule: .cascade, inverse:\LastMessageData.topic)
    var lastMessages: [LastMessageData] = []

    init(from topicResponseData: TopicResponseData, stream: StreamData) {
        self.uuid = topicResponseData.uuid
        self.unreadCount = topicResponseData.unreadCount
        self.activeUnreadCount = topicResponseData.activeUnreadCount
        self.name = topicResponseData.name
        self.isDone = topicResponseData.isDone
        self.isDefault = topicResponseData.isDefault
        self.color = topicResponseData.color
        self.updatedAt = topicResponseData.updatedAt
        self.notificationMode = topicResponseData.notificationMode
        self.stream = stream
    }
}

enum TopicNotificationMode: String, Codable {
    case mute
    case `default`
    case follow
    case unmute
}

extension TopicData {
    var lastMessage: LastMessageData? {
        lastMessages.sorted { $0.createdAt > $1.createdAt }.first
    }
}
