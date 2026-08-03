import Foundation

nonisolated struct WorkspaceSessionStore {
    private let keychainItem = KeychainItem(
        service: KeychainItem.defaultService,
        account: "workspace.session.v1"
    )

    func load() throws -> WorkspaceSession? {
        guard let value = try keychainItem.readValue(), let data = value.data(using: .utf8) else {
            return nil
        }
        return try JSONDecoder().decode(WorkspaceSession.self, from: data)
    }

    func save(_ session: WorkspaceSession) throws {
        let data = try JSONEncoder().encode(session)
        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataEncodingError
        }
        try keychainItem.saveItem(value)
    }

    func clear() throws {
        try keychainItem.deleteItem()
    }
}
