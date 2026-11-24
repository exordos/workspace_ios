import CryptoKit
import Foundation
import Security

struct PushSession: Codable, Hashable {
    let serverUuid: String
    let projectUuid: String
    let baseUrl: String
}

struct PushRegistration: Codable {
    let session: PushSession
    let organizationUuid: String
    let userUuid: String
    let deviceUuid: String
    let keyUuid: String
    let privateKey: Data

    static let storage = KeychainItem(service: KeychainItem.defaultService, account: "workspace-apns-registration-v1")

    init(session: PushSession, organizationUuid: String, userUuid: String) {
        self.session = session
        self.organizationUuid = organizationUuid
        self.userUuid = userUuid
        deviceUuid = UUID().uuidString.lowercased()
        keyUuid = UUID().uuidString.lowercased()
        privateKey = Curve25519.KeyAgreement.PrivateKey().rawRepresentation
    }

    static func read() throws -> PushRegistration? {
        guard let data = try storage.readValue() else { return nil }
        return try JSONDecoder().decode(Self.self, from: data)
    }

    func save() throws {
        try Self.storage.saveItem(JSONEncoder().encode(self), accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
    }

    func request(method: HTTPMethod, accessToken: String, deviceToken: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: "\(session.baseUrl)/api/workspace/v1/push_devices/\(deviceUuid)"),
              url.scheme == "https", url.host != nil else { throw APIError.encoding }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let deviceToken {
            guard let transport = Self.transport else { throw APIError.encoding }
            let publicKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey).publicKey
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "transport": transport,
                "platform": "ios",
                "registration_token": deviceToken.map { String(format: "%02x", $0) }.joined(),
                "encryption": [
                    "kind": "HPKE",
                    "algorithm": PushEnvelope.algorithm,
                    "key_uuid": keyUuid,
                    "public_key": publicKey.rawRepresentation.pushBase64,
                ],
            ])
        }
        return request
    }

    static var transport: String? {
        switch Bundle.main.object(forInfoDictionaryKey: "WorkspaceAPNSEnvironment") as? String {
        case "development": return "apns_sandbox"
        case "production": return "apns"
        default: return nil
        }
    }
}
