//
//  UserProfile.swift
//  WorkspaceBeta
//
//

import Foundation
import SwiftUI
import Combine

class UserProfile: ObservableObject {

    @Published var accessToken: String? {
        didSet {
            try? setToKeychain(value: accessToken, key: .accessTokenKey)
        }
    }

    var refreshToken: String? {
        didSet {
            try? setToKeychain(value: refreshToken, key: .refreshTokenKey)
        }
    }

    var userId: Int {
        didSet {
            UserDefaults.standard.set(userId, forKey: UserProfileUserDefaultsKey.userIdKey.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    var userEmail: String? {
        get {
            return UserDefaults.standard.string(forKey: UserProfileUserDefaultsKey.userEmailKey.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserProfileUserDefaultsKey.userEmailKey.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    var baseUrl: String? {
        get {
            return UserDefaults.standard.string(forKey: UserProfileUserDefaultsKey.baseUrlKey.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserProfileUserDefaultsKey.baseUrlKey.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    init() {
        self.userId = UserDefaults.standard.integer(forKey: UserProfileUserDefaultsKey.userIdKey.rawValue)
        self.accessToken = try? getValueFromKeychain(for: .accessTokenKey)
        self.refreshToken = try? getValueFromKeychain(for: .refreshTokenKey)
    }

    func clearData() {
        DispatchQueue.main.async { [weak self] in
            self?.baseUrl = nil
            self?.userEmail = nil
            self?.accessToken = nil
            self?.refreshToken = nil
            self?.userId = 0
        }
    }

    private func getValueFromKeychain(for key: UserProfileKeichainKey) throws -> String? {
        let item = KeychainItem(service: KeychainItem.defaultService, account: key.rawValue)
        return try item.readValue()
    }

    private func setToKeychain(value: String?, key: UserProfileKeichainKey) throws {
        let item = KeychainItem(service: KeychainItem.defaultService, account: key.rawValue)
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
    case userIdKey = "ru.genesiscorporation.workspace.userIdKey"
    case userEmailKey = "ru.genesiscorporation.workspace.userEmailKey"
    case baseUrlKey = "ru.genesiscorporation.workspace.baseUrlKey"
}

enum UrlRequestArtificialFailureType: String {
    case network
    case somethingWentWrong
}

