import CryptoKit
import Foundation

nonisolated struct WorkspacePushDeviceIdentity: Codable, Equatable, Sendable {
    let registrationUUID: String
    let keyUUID: String
    let privateKey: String

    var publicKey: String? {
        guard let privateKeyData = Data(base64URL: privateKey),
              let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
        else { return nil }
        return key.publicKey.rawRepresentation.base64URLEncodedString()
    }

    enum CodingKeys: String, CodingKey {
        case registrationUUID = "registration_uuid"
        case keyUUID = "key_uuid"
        case privateKey = "private_key"
    }
}

nonisolated struct WorkspacePushDeviceIdentityStore: Sendable {
    private let keychain = KeychainItem(
        service: "ru.genesiscorporation.WorkspaceBeta.push",
        account: "device-identity"
    )

    func loadOrCreate() throws -> WorkspacePushDeviceIdentity {
        let decoder = JSONDecoder()
        if let encoded = try keychain.readValue(),
           let data = encoded.data(using: .utf8),
           let identity = try? decoder.decode(WorkspacePushDeviceIdentity.self, from: data),
           identity.publicKey != nil {
            return identity
        }

        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let identity = WorkspacePushDeviceIdentity(
            registrationUUID: UUID().uuidString.lowercased(),
            keyUUID: UUID().uuidString.lowercased(),
            privateKey: privateKey.rawRepresentation.base64URLEncodedString()
        )
        let data = try JSONEncoder().encode(identity)
        guard let encoded = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataEncodingError
        }
        try keychain.saveItem(encoded)
        return identity
    }
}

actor WorkspacePushRegistrationManager {
    private let api: WorkspaceAPI
    private let identityStore: WorkspacePushDeviceIdentityStore
    private var registrationAllowed = false

    init(
        api: WorkspaceAPI,
        identityStore: WorkspacePushDeviceIdentityStore = WorkspacePushDeviceIdentityStore()
    ) {
        self.api = api
        self.identityStore = identityStore
    }

    func register(token: String, session: WorkspaceSession) async {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        registrationAllowed = true

        let delays: [Duration] = [.zero, .seconds(1), .seconds(5), .seconds(30)]
        for delay in delays {
            guard registrationAllowed, !Task.isCancelled else { return }
            if delay != .zero { try? await Task.sleep(for: delay) }
            guard registrationAllowed, !Task.isCancelled else { return }
            do {
                let identity = try identityStore.loadOrCreate()
                guard let publicKey = identity.publicKey else { return }
                _ = try await api.registerPushDevice(
                    session: session,
                    registrationUUID: identity.registrationUUID,
                    token: token,
                    keyUUID: identity.keyUUID,
                    publicKey: publicKey
                )
                return
            } catch {
                continue
            }
        }
    }

    func delete(session: WorkspaceSession) async {
        registrationAllowed = false
        guard let identity = try? identityStore.loadOrCreate() else { return }
        try? await api.deletePushDevice(
            session: session,
            registrationUUID: identity.registrationUUID
        )
    }
}

private nonisolated extension Data {
    init?(base64URL value: String) {
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: base64)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
