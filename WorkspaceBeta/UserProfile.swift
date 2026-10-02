//
//  UserProfile.swift
//  WorkspaceBeta
//
//

import Foundation
import SwiftUI
import Combine
import SwiftData

class UserProfile: ObservableObject {

    var accessToken: String? {
        didSet {
            if let accessToken {
                try? setAccessToken(accessToken, for: selectedServerUuid)
            }
        }
    }

    @Published var serverConfigs: [ServerConfig]

    let context: ModelContext

    var refreshToken: String? {
        didSet {
            if let refreshToken {
                try? setRefreshToken(refreshToken, for: selectedServerUuid)
            }
        }
    }

    var selectedServer: ServerConfig? {
        guard let selectedServerUuid else { return nil }
        return serverConfigs.first { $0.uuid == selectedServerUuid }
    }

    var selectedServerUuid: String? {
        didSet {
            UserDefaults.standard.set(selectedServerUuid, forKey: UserProfileUserDefaultsKey.selectedServerConfigKey.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    init(context: ModelContext) {
        self.context = context
        let serverConfigs = try? context.fetch(FetchDescriptor<ServerConfig>())
        self.serverConfigs = serverConfigs ?? []
        self.selectedServerUuid = UserDefaults.standard.string(forKey: UserProfileUserDefaultsKey.selectedServerConfigKey.rawValue)
        if let selectedServerUuid = selectedServerUuid {
            self.accessToken = accessToken(for: selectedServerUuid)
            self.refreshToken = refreshToken(for: selectedServerUuid)
        }
    }

    func setAccessToken(_ accessToken: String, for serverUuid: String?) throws {
        guard let serverUuid else { return }
        try setToKeychain(value: accessToken, key: UserProfileKeichainKey.accessTokenKey.rawValue + serverUuid)
    }

    func setRefreshToken(_ accessToken: String, for serverUuid: String?) throws {
        guard let serverUuid else { return }
        try setToKeychain(value: refreshToken, key: UserProfileKeichainKey.refreshTokenKey.rawValue + serverUuid)
    }

    func accessToken(for serverUuid: String) -> String? {
        return try? getValueFromKeychain(for: (UserProfileKeichainKey.accessTokenKey.rawValue + serverUuid))
    }

    func refreshToken(for serverUuid: String) -> String? {
        return try? getValueFromKeychain(for: (UserProfileKeichainKey.refreshTokenKey.rawValue + serverUuid))
    }

    func addServerConfig(_ serverConfig: ServerConfig) {
        context.insert(serverConfig)
        serverConfigs.append(serverConfig)
        selectServer(with: serverConfig.uuid)
    }

    func selectServer(with serverUuid: String) {
        selectedServerUuid = serverUuid
    }

    func removeCurrentConfig() {
        guard let selectedServer else { return }
        context.delete(selectedServer)
        try? context.save()
        let selectedServerIndex = serverConfigs.firstIndex(of: selectedServer)
        if let selectedServerIndex {
            serverConfigs.remove(at: selectedServerIndex)
        }
        selectedServerUuid = serverConfigs.first?.uuid
    }

    func clearData() {
        DispatchQueue.main.async { [weak self] in
            self?.selectedServerUuid = nil
            self?.accessToken = nil
            self?.refreshToken = nil
        }
    }

    private func getValueFromKeychain(for key: String) throws -> String? {
        let item = KeychainItem(service: KeychainItem.defaultService, account: key)
        return try item.readValue()
    }

    private func setToKeychain(value: String?, key: String) throws {
        let item = KeychainItem(service: KeychainItem.defaultService, account: key)
        guard let value = value else {
            try item.deleteItem()
            return
        }
        try item.saveItem(value)
    }
}

enum UserProfileKeichainKey: String {
    case accessTokenKey
    case refreshTokenKey
}

enum UserProfileUserDefaultsKey: String {
    case selectedServerConfigKey = "com.exordos.workspace.currentServerKey"
}

@Model
class ServerConfig {
    var uuid: String
    var baseUrl: String
    var imageUrl: String
    var name: String
    var needsToRelogin: Bool
    var projectUuid: String?

    init(uuid: String, baseUrl: String, imageUrl: String, name: String, needsToRelogin: Bool = false, projectUuid: String? = nil) {
        self.uuid = uuid
        self.baseUrl = baseUrl
        self.imageUrl = imageUrl
        self.name = name
        self.needsToRelogin = needsToRelogin
        self.projectUuid = projectUuid
    }
}
