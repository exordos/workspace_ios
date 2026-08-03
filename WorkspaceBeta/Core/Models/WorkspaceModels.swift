import Foundation

nonisolated struct WorkspaceServer: Codable, Equatable, Sendable {
    let baseURL: URL
    let realmName: String
    let meetURL: URL?

    var displayName: String {
        realmName.isEmpty ? (baseURL.host ?? "Workspace") : realmName
    }
}

nonisolated struct WorkspaceSession: Codable, Equatable, Sendable {
    let server: WorkspaceServer
    let username: String
    let accessToken: String
    let refreshToken: String
}

nonisolated struct WorkspaceUser: Codable, Equatable, Identifiable, Sendable {
    let email: String?
    let firstName: String?
    let lastName: String?
    let username: String
    let uuid: String
    let statusEmoji: String?
    let statusText: String?
    let status: String
    let avatar: String

    var id: String { uuid }

    var displayName: String {
        let name = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? username : name
    }

    enum CodingKeys: String, CodingKey {
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case uuid
        case statusEmoji = "status_emoji"
        case statusText = "status_text"
        case status
        case avatar
    }
}

nonisolated struct WorkspaceStream: Codable, Hashable, Identifiable, Sendable {
    let uuid: String
    let unreadCount: Int
    let updatedAt: String
    let name: String
    let description: String?
    let isPrivate: Bool
    let color: Int
    let role: String?
    let notificationMode: String?
    let lastMessageUUID: String?
    let defaultTopicUUID: String?
    let directUserUUID: String?
    let avatar: String?

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid
        case unreadCount = "unread_count"
        case updatedAt = "updated_at"
        case name
        case description
        case isPrivate = "private"
        case color
        case role
        case notificationMode = "notification_mode"
        case lastMessageUUID = "last_message_uuid"
        case defaultTopicUUID = "default_topic_uuid"
        case directUserUUID = "direct_user_uuid"
        case avatar
    }
}

nonisolated struct WorkspaceStreamBinding: Codable, Equatable, Identifiable, Sendable {
    let uuid: String
    let streamUUID: String
    let userUUID: String
    let role: String
    let notificationMode: String

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid
        case streamUUID = "stream_uuid"
        case userUUID = "user_uuid"
        case role
        case notificationMode = "notification_mode"
    }
}

nonisolated struct WorkspaceFolder: Codable, Equatable, Identifiable, Sendable {
    let uuid: String
    let title: String
    let unreadCount: Int
    let systemType: String?
    let createdAt: String
    let items: [WorkspaceFolderItem]

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid
        case title
        case unreadCount = "unread_count"
        case systemType = "system_type"
        case createdAt = "created_at"
        case items = "folder_items"
    }
}

nonisolated struct WorkspaceFolderItem: Codable, Equatable, Identifiable, Sendable {
    let uuid: String
    let streamUUID: String
    let chatType: String
    let unreadCount: Int

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid
        case streamUUID = "stream_uuid"
        case chatType = "chat_type"
        case unreadCount = "unread_count"
    }
}

nonisolated struct WorkspaceTopic: Codable, Hashable, Identifiable, Sendable {
    let uuid: String
    let name: String
    let color: Int
    let streamUUID: String
    let updatedAt: String
    let unreadCount: Int
    let isDone: Bool
    let isDefault: Bool
    let lastMessageUUID: String?

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case color
        case streamUUID = "stream_uuid"
        case updatedAt = "updated_at"
        case unreadCount = "unread_count"
        case isDone = "is_done"
        case isDefault = "is_default"
        case lastMessageUUID = "last_message_uuid"
    }
}

nonisolated struct WorkspaceMessage: Codable, Equatable, Identifiable, Sendable {
    let uuid: String
    let updatedAt: String
    let createdAt: String
    let streamUUID: String
    let topicUUID: String
    let userUUID: String
    let authorUUID: String
    var payload: WorkspaceMessagePayload
    let isOwn: Bool
    var reactions: [String: Int]
    let user: WorkspaceUser?

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case streamUUID = "stream_uuid"
        case topicUUID = "topic_uuid"
        case userUUID = "user_uuid"
        case authorUUID = "author_uuid"
        case payload
        case isOwn = "is_own"
        case reactions
        case user
    }
}

nonisolated struct WorkspaceMessagePayload: Codable, Equatable, Sendable {
    let kind: String
    var content: String
}

nonisolated struct WorkspaceMessageReaction: Codable, Equatable, Identifiable, Sendable {
    let uuid: String
    let userUUID: String
    let emojiName: String
    let messageUUID: String

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid
        case userUUID = "user_uuid"
        case emojiName = "emoji_name"
        case messageUUID = "message_uuid"
    }
}

nonisolated struct WorkspaceUpload: Codable, Equatable, Sendable {
    let uuid: String
    let name: String
}
