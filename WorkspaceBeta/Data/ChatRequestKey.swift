//
//  ChatRequestKey.swift
//  WorkspaceBeta
//
//

import SwiftData

@Model
class ChatRequestKey {
    var uuid: String
    var publicKey: String

    init(uuid: String, publicKey: String) {
        self.uuid = uuid
        self.publicKey = publicKey
    }
}
