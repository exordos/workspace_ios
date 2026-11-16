//
//  MessageReactionData.swift
//  WorkspaceBeta
//
//

import Foundation
import SwiftData

@Model
class MessageReactionData {
    @Attribute(.unique) var uuid: String
    var emojiName: String
    var messageUuid: String

    var user: UserData?

    init(with messageReaction: MessageReactionResponseData, user: UserData) {
        self.uuid = messageReaction.uuid
        self.emojiName = messageReaction.emojiName
        self.user = user
        self.messageUuid = messageReaction.messageUuid
    }
}
