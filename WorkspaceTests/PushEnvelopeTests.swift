import Foundation
import Testing
@testable import Workspace

@MainActor
struct PushEnvelopeTests {
    @Test func opensWorkspaceTopicSnapshotAndReadUpdate() throws {
        let fixture = try decodeFixture()
        let unread = try #require(fixture.unread.open(using: fixture.registration))
        #expect(unread.activeUnreadCount == 3)
        #expect(unread.epochVersion == 12)
        #expect(fixture.unread.messageUuid != nil)
        let cleared = try #require(fixture.cleared.open(using: fixture.registration))
        #expect(cleared.activeUnreadCount == 0)
        #expect(fixture.cleared.messageUuid == nil)
    }

    @Test func rejectsTamperedRouteAndOtherAccount() throws {
        let fixture = try decodeFixture()
        let encoded = try #require(JSONSerialization.jsonObject(with: fixtureData) as? [String: Any])
        var envelope = try #require(encoded["unread"] as? [String: Any])
        envelope["stream_uuid"] = UUID().uuidString.lowercased()
        let tampered = try #require(PushEnvelope.read(["workspace": envelope]))
        #expect(tampered.open(using: fixture.registration) == nil)

        let other = PushRegistration(
            session: fixture.registration.session,
            organizationUuid: fixture.registration.organizationUuid,
            userUuid: UUID().uuidString.lowercased()
        )
        #expect(fixture.unread.open(using: other) == nil)
    }

    @Test func registrationUsesScopedHTTPSDeviceEndpoint() throws {
        let fixture = try decodeFixture()
        let request = try fixture.registration.request(
            method: .put, accessToken: "synthetic-access", deviceToken: Data([0x00, 0x22, 0xff])
        )
        #expect(request.url?.path == "/api/workspace/v1/push_devices/\(fixture.registration.deviceUuid)")
        #expect(request.httpMethod == "PUT")
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["transport"] as? String == "apns_sandbox")
        #expect(json["platform"] as? String == "ios")
        #expect(json["registration_token"] as? String == "0022ff")
        #expect(json["private_key"] == nil)
    }

    private struct Fixture: Decodable {
        let registration: PushRegistration
        let unread: PushEnvelope
        let cleared: PushEnvelope
    }

    private func decodeFixture() throws -> Fixture {
        try JSONDecoder().decode(Fixture.self, from: fixtureData)
    }

    // Workspace Backend payloads sealed with the public RFC 9180 test keys.
    private var fixtureData: Data {
        Data("""
        {
            "registration": {
                "session": {
                    "serverUuid": "00000000-0000-0000-0000-00000000000b",
                    "projectUuid": "00000000-0000-0000-0000-000000000003",
                    "baseUrl": "https://workspace.example"
                },
                "organizationUuid": "00000000-0000-0000-0000-000000000002",
                "userUuid": "00000000-0000-0000-0000-000000000007",
                "deviceUuid": "00000000-0000-0000-0000-000000000008",
                "keyUuid": "00000000-0000-0000-0000-000000000009",
                "privateKey": "SXtFAmZM/qXVrws5k02sciQqdPhIBFHhrufWpTMgMz0="
            },
            "unread": {
                "uuid": "00000000-0000-0000-0000-000000000001",
                "kind": "notification_topic_update",
                "organization_uuid": "00000000-0000-0000-0000-000000000002",
                "project_uuid": "00000000-0000-0000-0000-000000000003",
                "stream_uuid": "00000000-0000-0000-0000-000000000004",
                "topic_uuid": "00000000-0000-0000-0000-000000000005",
                "message_uuid": "00000000-0000-0000-0000-000000000006",
                "user_uuid": "00000000-0000-0000-0000-000000000007",
                "device_uuid": "00000000-0000-0000-0000-000000000008",
                "content": {
                    "kind": "encrypted",
                    "algorithm": "HPKE-v1-BASE-X25519-HKDF-SHA256-AES-256-GCM",
                    "key_uuid": "00000000-0000-0000-0000-000000000009",
                    "enc": "bJPgmGnfNALXvyMb9UD63TXNVr4U-XF48JVNuUt_wlY",
                    "ciphertext": "XlYlFEQUdIMwl6f7jGrwYVbllxX4IzmVxOBtuGwSQBlHqLmNxX6QeZAcW6GmnKUZmh49ik87-MgSzulEHojvlLxrmqytDd2nmVuQCmSJO6IuJ1sivaXjUJyuJNu6jwlPlYxwtuKEmYXqBiEFE9GbPuxBeHCb2dmS8IBThONOYhaGq3vKmdZawY63TR5tacXoTwlK_Qqj8yoUoZB4HMngZ2zyDLC3hgrVK9F3bv2hYA"
                }
            },
            "cleared": {
                "uuid": "00000000-0000-0000-0000-000000000001",
                "kind": "notification_topic_update",
                "organization_uuid": "00000000-0000-0000-0000-000000000002",
                "project_uuid": "00000000-0000-0000-0000-000000000003",
                "stream_uuid": "00000000-0000-0000-0000-000000000004",
                "topic_uuid": "00000000-0000-0000-0000-000000000005",
                "message_uuid": null,
                "user_uuid": "00000000-0000-0000-0000-000000000007",
                "device_uuid": "00000000-0000-0000-0000-000000000008",
                "content": {
                    "kind": "encrypted",
                    "algorithm": "HPKE-v1-BASE-X25519-HKDF-SHA256-AES-256-GCM",
                    "key_uuid": "00000000-0000-0000-0000-000000000009",
                    "enc": "bJPgmGnfNALXvyMb9UD63TXNVr4U-XF48JVNuUt_wlY",
                    "ciphertext": "XlYlFEQUdIMwl6f7jGrwYVbllxX4IzmVxOBtuGwSQBpHqLmNxX6QeZAcW6GmnKUZmh49ik87-MsSzulEHojvlLxrmqytDd2nmVuQCmSJO6IuJ1sivaXjUJyuJNu6jwlPlYxwtuKEmYXqBiEFE9GbPuxBeHCb2dmS8IBThONOYhaGq3vKmdZawY63TR5tacXoTwlK_Qqj8yoUoZB4HMngHI4SXXLq2e79n2DTaoOing"
                }
            }
        }
        """.utf8)
    }
}
