//
//  WorkspaceBetaTests.swift
//  WorkspaceBetaTests
//
//  Created by Evgenii Vedenin on 19.02.2026.
//

import CryptoKit
import Foundation
import Testing
@testable import WorkspaceBeta

struct WorkspaceBetaTests {
    @Test("Server URLs default to HTTPS and remove a trailing slash")
    func normalizesServerURL() throws {
        let url = try WorkspaceAPI.normalizedServerURL(from: " workspace.exordos.com/ ")
        #expect(url.absoluteString == "https://workspace.exordos.com")
    }

    @Test("Non-HTTPS Workspace URLs are rejected")
    func rejectsInsecureServerURL() {
        #expect(throws: WorkspaceAPIError.self) {
            try WorkspaceAPI.normalizedServerURL(from: "http://workspace.example.com")
        }
    }

    @Test("Initial invalid_client response requests classic OTP")
    func classifiesOTPChallenge() {
        #expect(
            LoginErrorClassifier.isOTPChallenge(
                statusCode: 401,
                responseBody: #"{"error":"invalid_client"}"#,
                otpProvided: false
            )
        )
        #expect(
            !LoginErrorClassifier.isOTPChallenge(
                statusCode: 401,
                responseBody: #"{"error":"invalid_client"}"#,
                otpProvided: true
            )
        )
    }

    @Test("A wrong OTP has a specific public error")
    func wrongOTPMessage() {
        let message = LoginErrorClassifier.publicMessage(
            statusCode: 401,
            responseBody: "",
            otpProvided: true
        )
        #expect(message.contains("OTP"))
    }

    @Test("Authentication OTP input keeps exactly six digits")
    func normalizesAuthenticationOTP() {
        #expect(WorkspaceAuthenticationRules.normalizedOTP("1a2 3-45678") == "123456")
        #expect(WorkspaceAuthenticationRules.normalizedOTP("12") == "12")
    }

    @Test("The public Workspace uses the Android organization title")
    func formatsAuthenticationOrganizationTitle() throws {
        let publicServer = WorkspaceServer(
            baseURL: try #require(URL(string: "https://workspace.exordos.com")),
            realmName: "Genesis Corporation Workspace",
            meetURL: nil
        )
        let customServer = WorkspaceServer(
            baseURL: try #require(URL(string: "https://workspace.example.com")),
            realmName: "Example Workspace",
            meetURL: nil
        )

        #expect(WorkspaceAuthenticationRules.organizationTitle(for: publicServer) == "Exordos Workspace")
        #expect(WorkspaceAuthenticationRules.organizationTitle(for: customServer) == "Example Workspace")
    }

    @Test("Workspace image URNs are separated from their message caption")
    func parsesWorkspaceImageAttachment() {
        let parsed = WorkspaceAttachmentParser.parse("Caption\n[photo.jpg](urn:image:file-uuid)")
        #expect(parsed.caption == "Caption")
        #expect(parsed.attachments == [
            WorkspaceMessageAttachment(filename: "photo.jpg", fileUUID: "file-uuid")
        ])
    }

    @Test("Jitsi invitations are accepted only for the configured server")
    func parsesWorkspaceCallInvitation() throws {
        let meetURL = try #require(URL(string: "https://meet.example.com"))
        let call = try #require(
            WorkspaceCall.parse("https://meet.example.com/calmBlueHarbor", meetURL: meetURL)
        )
        #expect(call.room == "calmBlueHarbor")
        #expect(
            WorkspaceCall.parse("https://other.example.com/calmBlueHarbor", meetURL: meetURL) == nil
        )
    }

    @Test("Generated Jitsi room names are URL path components")
    func generatesSafeWorkspaceCallRoom() {
        let room = WorkspaceCallRoomNameGenerator.generate()
        #expect(!room.isEmpty)
        #expect(!room.contains("/"))
        #expect(room.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) })
    }

    @Test("Push payloads preserve Android notification navigation semantics")
    func parsesPushRoutes() {
        #expect(
            WorkspacePushPayload(userInfo: [
                "kind": "private_chat_message",
                "sender_id": "user-uuid",
            ]) == .route(.direct(userUUID: "user-uuid"))
        )
        #expect(
            WorkspacePushPayload(userInfo: [
                "kind": "stream_chat_message",
                "stream": "stream-uuid",
                "topic": "topic-uuid",
            ]) == .route(.topic(stream: "stream-uuid", topic: "topic-uuid"))
        )
        #expect(
            WorkspacePushPayload(userInfo: [
                "kind": "remove_notification_message",
                "message_ids": "42, 51",
            ]) == .cancel(messageIdentifiers: ["42", "51"])
        )
    }

    @Test("Push identity exports an unpadded 32-byte X25519 public key")
    func exportsPushPublicKey() throws {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let identity = WorkspacePushDeviceIdentity(
            registrationUUID: UUID().uuidString,
            keyUUID: UUID().uuidString,
            privateKey: privateKey.rawRepresentation
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        )
        let encoded = try #require(identity.publicKey)
        #expect(!encoded.contains("="))

        var base64 = encoded.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        #expect(Data(base64Encoded: base64)?.count == 32)
    }

    @Test("The mobile shell keeps the agreed five-tab order")
    func mobileShellTabOrder() {
        #expect(WorkspaceTab.allCases.map(\.title) == [
            "Моя активность",
            "Мессенджер",
            "Календарь",
            "Почта",
            "Профиль",
        ])
        #expect(WorkspaceTab.allCases.map(\.selectedSystemImage) == [
            "house.fill",
            "bubble.left.and.bubble.right.fill",
            "calendar",
            "envelope.fill",
            "person.crop.circle.fill",
        ])
    }

    @Test("My Activity search follows the Android destination contract")
    func filtersMyActivityDestinations() {
        #expect(filteredActivityDestinations(query: "  упом  ") == [.mentions])
        #expect(filteredActivityDestinations(query: "нет такого").isEmpty)
        #expect(filteredActivityDestinations(query: "").count == 7)
    }

    @Test("Activity message filters map to the backend query contract")
    func mapsActivityMessageFilters() {
        #expect(WorkspaceMessageActivityFilter.feed.queryItem == nil)
        #expect(WorkspaceMessageActivityFilter.starred.queryItem?.name == "starred")
        #expect(WorkspaceMessageActivityFilter.pinned.queryItem?.value == "true")
        #expect(WorkspaceMessageActivityFilter.mentioned.queryItem?.name == "mentioned")
    }
}
