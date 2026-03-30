//
//  UserProfile.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 19.02.2026.
//

import Foundation
import SwiftUI
import Combine

class UserProfile: ObservableObject {

    @Published var apiKey: String? {
        didSet {
            try? setToKeychain(value: apiKey, key: .apiKeyKey)
        }
    }

    var userId: Int? {
        get {
            return UserDefaults.standard.integer(forKey: UserProfileUserDefaultsKey.userIdKey.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserProfileUserDefaultsKey.userIdKey.rawValue)
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
        self.apiKey = try? getValueFromKeychain(for: .apiKeyKey)
    }

    func clearData() {
        DispatchQueue.main.async { [weak self] in
            self?.baseUrl = nil
            self?.userId = nil
            self?.userEmail = nil
            self?.apiKey = nil
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
    case apiKeyKey
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

