//
//  KeychainItem.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 19.02.2026.
//

import Foundation

enum KeychainError: Error {
    case noItem
    case unexpectedItemData
    case dataEncodingError
    case unhandledError(status: OSStatus)
}

struct KeychainItem {

    static let defaultService = "ru.genesiscorporation.WorkspaceBeta"

    let service: String

    private(set) var account: String

    let accessGroup: String?

    init(service: String, account: String, accessGroup: String? = nil) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }

    func updateToAccessibleAfterFirstUnlock() throws {
        var attributesToUpdate = [String: AnyObject]()
        attributesToUpdate[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let query = keychainQuery(with: service, account: account, accessGroup: accessGroup)
        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        guard status != errSecItemNotFound else { return }

        guard status == noErr else { throw KeychainError.unhandledError(status: status) }
    }

    func readValue() throws -> String? {
        do {
            return try readItem()
        } catch KeychainError.noItem {
            return nil
        }
    }

    func saveItem(_ item: String) throws {
        guard let encodedItem = item.data(using: String.Encoding.utf8) else {
            throw KeychainError.unexpectedItemData
        }

        do {

            try _ = readItem()

            var attributesToUpdate = [String: AnyObject]()
            attributesToUpdate[kSecValueData as String] = encodedItem as AnyObject?
            attributesToUpdate[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let query = keychainQuery(with: service, account: account, accessGroup: accessGroup)
            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

            guard status == noErr else { throw KeychainError.unhandledError(status: status) }
        } catch KeychainError.noItem {

            var newItem = keychainQuery(with: service, account: account, accessGroup: accessGroup)
            newItem[kSecValueData as String] = encodedItem as AnyObject?
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let status = SecItemAdd(newItem as CFDictionary, nil)

            guard status == noErr else { throw KeychainError.unhandledError(status: status) }
        }
    }

    func deleteItem() throws {

        let query = keychainQuery(with: service, account: account, accessGroup: accessGroup)
        let status = SecItemDelete(query as CFDictionary)

        guard status == noErr || status == errSecItemNotFound else { throw KeychainError.unhandledError(status: status) }
    }

    // MARK: Convenience

    private func readItem() throws -> String {

        var query = keychainQuery(with: service, account: account, accessGroup: accessGroup)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = kCFBooleanTrue
        query[kSecReturnData as String] = kCFBooleanTrue

        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        guard status != errSecItemNotFound else { throw KeychainError.noItem }
        guard status == noErr else { throw KeychainError.unhandledError(status: status) }

        guard let existingItem = queryResult as? [String: AnyObject],
            let passwordData = existingItem[kSecValueData as String] as? Data,
            let password = String(data: passwordData, encoding: String.Encoding.utf8)
            else {
                throw KeychainError.unexpectedItemData
        }

        return password
    }

    private func keychainQuery(with service: String, account: String? = nil, accessGroup: String? = nil) -> [String: AnyObject] {
        var query = [String: AnyObject]()
        query[kSecClass as String] = kSecClassGenericPassword
        query[kSecAttrService as String] = service as AnyObject?

        if let account = account {
            query[kSecAttrAccount as String] = account as AnyObject?
        }

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup as AnyObject?
        }

        return query
    }
}

