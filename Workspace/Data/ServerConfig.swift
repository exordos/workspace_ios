//
//  ServerConfig.swift
//  Workspace
//
//

import SwiftData

@Model
class ServerConfig {
    var uuid: String
    var baseUrl: String
    var imageUrl: String
    var name: String
    var needsToRelogin: Bool
    var projectUuid: String?

    var encryptedChatKeys: [EncryptedChatKey] = []

    init(uuid: String, baseUrl: String, imageUrl: String, name: String, needsToRelogin: Bool = false, projectUuid: String? = nil) {
        self.uuid = uuid
        self.baseUrl = baseUrl
        self.imageUrl = imageUrl
        self.name = name
        self.needsToRelogin = needsToRelogin
        self.projectUuid = projectUuid
    }
}
