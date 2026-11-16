//
//  UserData.swift
//  Workspace
//
//

import Foundation
import SwiftData

@Model
class UserData: Hashable, Identifiable {
    @Attribute(.unique) var uuid: String
    var avatar: String
    var email: String?
    var firstName: String?
    var lastName: String?
    var status: String
    var statusEmoji: String?
    var statusText: String?
    var username: String

    var messages: [MessageData] = []

    @Relationship(deleteRule: .cascade, inverse:\LastMessageData.author)
    var lastMessages: [LastMessageData] = []

    @Relationship(deleteRule: .cascade, inverse:\StreamData.directUser)
    var directStream: StreamData?
    
    var messageReactions: [MessageReactionData] = []

    @Relationship(deleteRule: .cascade, inverse:\StreamBindingData.user)
    var streamBindings: [StreamBindingData] = []

    init(with userResponseData: UserResponseData) {
        self.avatar = userResponseData.avatar
        self.email = userResponseData.email
        self.firstName = userResponseData.firstName
        self.lastName = userResponseData.lastName
        self.uuid = userResponseData.uuid
        self.status = userResponseData.status
        self.statusEmoji = userResponseData.statusEmoji
        self.statusText = userResponseData.statusText
        self.username = userResponseData.username
    }

    var displayableName: String {
        var displayableName: String = ""

        if let firstName {
            displayableName += firstName
        }

        if let lastName {
            if !displayableName.isEmpty {
                displayableName += " "
            }
            displayableName += lastName
        }

        if displayableName.isEmpty {
            displayableName += username
        }

        return displayableName
    }

    var statusString: String {
        switch status {
        case "active":
            "В сети"
        default:
            "Не в сети"
        }
    }
}
