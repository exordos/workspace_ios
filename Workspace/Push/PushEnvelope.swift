import CryptoKit
import Foundation

struct PushEnvelope: Decodable, Hashable {
    static let algorithm = "HPKE-v1-BASE-X25519-HKDF-SHA256-AES-256-GCM"

    struct Content: Decodable, Hashable {
        let kind: String
        let algorithm: String
        let keyUuid: String
        let enc: String
        let ciphertext: String

        enum CodingKeys: String, CodingKey {
            case kind, algorithm, enc, ciphertext
            case keyUuid = "key_uuid"
        }
    }

    struct Snapshot: Decodable {
        let kind: String
        let unreadCount: Int
        let activeUnreadCount: Int
        let passiveUnreadCount: Int
        let epochVersion: Int64
        let epochGeneration: UUID

        enum CodingKeys: String, CodingKey {
            case kind
            case unreadCount = "unread_count"
            case activeUnreadCount = "active_unread_count"
            case passiveUnreadCount = "passive_unread_count"
            case epochVersion = "epoch_version"
            case epochGeneration = "epoch_generation"
        }
    }

    let uuid: String
    let kind: String
    let organizationUuid: String
    let projectUuid: String
    let streamUuid: String
    let topicUuid: String
    let messageUuid: String?
    let userUuid: String
    let deviceUuid: String
    let content: Content

    enum CodingKeys: String, CodingKey {
        case uuid, kind, content
        case organizationUuid = "organization_uuid"
        case projectUuid = "project_uuid"
        case streamUuid = "stream_uuid"
        case topicUuid = "topic_uuid"
        case messageUuid = "message_uuid"
        case userUuid = "user_uuid"
        case deviceUuid = "device_uuid"
    }

    static func read(_ userInfo: [AnyHashable: Any]) -> PushEnvelope? {
        guard let envelope = userInfo["workspace"] as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: envelope) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    func open(using registration: PushRegistration) -> Snapshot? {
        guard kind == "notification_topic_update",
              content.kind == "encrypted", content.algorithm == Self.algorithm,
              organizationUuid == registration.organizationUuid,
              projectUuid == registration.session.projectUuid,
              userUuid == registration.userUuid,
              deviceUuid == registration.deviceUuid,
              content.keyUuid == registration.keyUuid,
              UUID(uuidString: uuid) != nil,
              UUID(uuidString: streamUuid) != nil,
              UUID(uuidString: topicUuid) != nil,
              messageUuid == nil || UUID(uuidString: messageUuid ?? "") != nil,
              let enc = Data(pushBase64: content.enc),
              let ciphertext = Data(pushBase64: content.ciphertext) else { return nil }

        let fields: [Any] = [
            uuid, kind, organizationUuid, projectUuid, streamUuid, topicUuid,
            messageUuid.map { $0 as Any } ?? NSNull(), userUuid, deviceUuid, content.keyUuid,
        ]
        do {
            let aad = try JSONSerialization.data(withJSONObject: fields)
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: registration.privateKey)
            var recipient = try HPKE.Recipient(
                privateKey: privateKey,
                ciphersuite: .init(kem: .Curve25519_HKDF_SHA256, kdf: .HKDF_SHA256, aead: .AES_GCM_256),
                info: Data("workspace-mobile-push".utf8),
                encapsulatedKey: enc
            )
            let plaintext = try recipient.open(ciphertext, authenticating: aad)
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: plaintext)
            guard snapshot.kind == "topic",
                  snapshot.activeUnreadCount >= 0,
                  snapshot.activeUnreadCount <= snapshot.unreadCount,
                  snapshot.passiveUnreadCount == snapshot.unreadCount - snapshot.activeUnreadCount,
                  (messageUuid == nil) == (snapshot.unreadCount == 0) else { return nil }
            return snapshot
        } catch {
            return nil
        }
    }
}

extension Data {
    var pushBase64: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(pushBase64 value: String) {
        let standard = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = String(repeating: "=", count: (4 - standard.utf8.count % 4) % 4)
        guard let decoded = Data(base64Encoded: standard + padding), decoded.pushBase64 == value else { return nil }
        self = decoded
    }
}
