//
//  EncryptedChatKey.swift
//  WorkspaceBeta
//
//

import SwiftData
import Foundation

@Model
class EncryptedChatKey {
    var uuid: String
    var streamUuid: String
    var name: String
    var creationDate: Date

    var serverConfig: ServerConfig?

    init(uuid: String, streamUuid: String,  name: String? = nil, serverConfig: ServerConfig? = nil) {
        self.uuid = uuid
        self.streamUuid = streamUuid
        self.serverConfig = serverConfig
        self.name = name ?? uuid
        self.creationDate = Date()
    }
}
