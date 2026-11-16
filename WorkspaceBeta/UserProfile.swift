//
//  UserProfile.swift
//  WorkspaceBeta
//
//

import Foundation
import SwiftUI
import Combine
import SwiftData
import CryptoKit

class UserProfile: ObservableObject {

    var accessToken: String? {
        didSet {
            try? setAccessToken(accessToken, for: selectedServerUuid)
        }
    }

    @Published var serverConfigs: [ServerConfig]

    let context: ModelContext

    var refreshToken: String? {
        didSet {
            try? setRefreshToken(refreshToken, for: selectedServerUuid)
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

    var deviceId: String

    var chatRequestPublicKey: Data {
        didSet {

        }
    }

    var chatRequestPrivateKey: Data {
        didSet {

        }
    }

    init(context: ModelContext) {
        self.context = context
        let serverConfigs = try? context.fetch(FetchDescriptor<ServerConfig>())
        self.serverConfigs = serverConfigs ?? []
        self.selectedServerUuid = UserDefaults.standard.string(forKey: UserProfileUserDefaultsKey.selectedServerConfigKey.rawValue) ?? serverConfigs?.first?.uuid
        let chatRequestPublicKey = try? UserProfile.getValueFromKeychain(for: UserProfileKeichainKey.chatRequestPublicKeyKey.rawValue)
        let chatRequestPrivateKey = try? UserProfile.getValueFromKeychain(for: UserProfileKeichainKey.chatRequestPrivateKeyKey.rawValue)
        if let chatRequestPublicKey, let chatRequestPrivateKey {
            self.chatRequestPublicKey = chatRequestPublicKey
            self.chatRequestPrivateKey = chatRequestPrivateKey
        } else {
            let privateKey = Curve25519.KeyAgreement.PrivateKey()
            let publicKey = privateKey.publicKey
            self.chatRequestPrivateKey = privateKey.rawRepresentation
            self.chatRequestPublicKey = publicKey.rawRepresentation
            try? UserProfile.setValueToKeychain(value: privateKey.rawRepresentation, key: UserProfileKeichainKey.chatRequestPrivateKeyKey.rawValue)
            try? UserProfile.setValueToKeychain(value: publicKey.rawRepresentation, key: UserProfileKeichainKey.chatRequestPublicKeyKey.rawValue)
        }
        if let deviceId = UserDefaults.standard.string(forKey: UserProfileUserDefaultsKey.deviceKey.rawValue) {
            self.deviceId = deviceId
        } else {
            let newDeviceId = UUID().uuidString.lowercased()
            self.deviceId = newDeviceId
            UserDefaults.standard.setValue(newDeviceId, forKey: UserProfileUserDefaultsKey.deviceKey.rawValue)
            UserDefaults.standard.synchronize()
        }
        if let selectedServerUuid = selectedServerUuid {
            self.accessToken = accessToken(for: selectedServerUuid)
            self.refreshToken = refreshToken(for: selectedServerUuid)
        }
    }

    func setAccessToken(_ accessToken: String?, for serverUuid: String?) throws {
        guard let serverUuid else { return }
        try setStringValueToKeychain(value: accessToken, key: UserProfileKeichainKey.accessTokenKey.rawValue + serverUuid)
    }

    func setRefreshToken(_ accessToken: String?, for serverUuid: String?) throws {
        guard let serverUuid else { return }
        try setStringValueToKeychain(value: refreshToken, key: UserProfileKeichainKey.refreshTokenKey.rawValue + serverUuid)
    }

    func accessToken(for serverUuid: String) -> String? {
        return try? getStringValueFromKeychain(for: (UserProfileKeichainKey.accessTokenKey.rawValue + serverUuid))
    }

    func refreshToken(for serverUuid: String) -> String? {
        return try? getStringValueFromKeychain(for: (UserProfileKeichainKey.refreshTokenKey.rawValue + serverUuid))
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

    func removeCurrentTokenPair() {
        DispatchQueue.main.async { [weak self] in
            self?.accessToken = nil
            self?.refreshToken = nil
            self?.selectedServer?.projectUuid = nil
        }
    }

    func didReceiveKeyGrantMessage(with payload: MessageResponsePayload.KeyGrant, streamUuid: String, userUuid: String) {
        guard let selectedServer, selectedServer.encryptedChatKeys.first(where: {$0.uuid == payload.keyUuid }) == nil, payload.recipientDeviceId == deviceId else { return }
        guard let encryptedContent = Data(base64Encoded: payload.content) else { return }
        do {
            let decryptedData = try decryptGroupKeyGrant(envelope: encryptedContent, streamUuid: streamUuid, context: payload)

            addNewGroupKey(decryptedData, keyUuid: payload.keyUuid, userUuid: userUuid, streamUuid: streamUuid)
        } catch {
            print(error)
        }
    }

    func createGroupKey(keyUuid: String, userUuid: String, streamUuid: String) {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes {
            return Data(Array($0))
        }
        addNewGroupKey(keyData, keyUuid: keyUuid, userUuid: userUuid, streamUuid: streamUuid)
    }

    func addNewGroupKey(_ keyData: Data, keyUuid: String, userUuid: String, streamUuid: String) {
        guard let selectedServer else { return }

        let encryptedChatKeychainId = "\(UserProfileKeichainKey.encryptedChatKey).\(keyUuid).\(userUuid).\(streamUuid)"
        try? UserProfile.setValueToKeychain(value: keyData, key: encryptedChatKeychainId)
        let encryptedChatKey = EncryptedChatKey(uuid: keyUuid, streamUuid: streamUuid)
        selectedServer.encryptedChatKeys.append(encryptedChatKey)
    }

    func keyData(keyUuid: String, userUuid: String, streamUuid: String) -> Data? {
        let encryptedChatKeychainId = "\(UserProfileKeichainKey.encryptedChatKey).\(keyUuid).\(userUuid).\(streamUuid)"
        return try? UserProfile.getValueFromKeychain(for: encryptedChatKeychainId)
    }

    private static func getValueFromKeychain(for key: String) throws -> Data? {
        let item = KeychainItem(service: KeychainItem.defaultService, account: key)
        return try item.readValue()
    }

    private func getStringValueFromKeychain(for key: String) throws -> String? {
        let item = KeychainItem(service: KeychainItem.defaultService, account: key)
        return try item.readStringValue()
    }

    private func setStringValueToKeychain(value: String?, key: String) throws {
        let item = KeychainItem(service: KeychainItem.defaultService, account: key)
        guard let value = value else {
            try item.deleteItem()
            return
        }
        try item.saveStringItem(value)
    }

    private static func setValueToKeychain(value: Data?, key: String) throws {
        let item = KeychainItem(service: KeychainItem.defaultService, account: key)
        guard let value = value else {
            try item.deleteItem()
            return
        }
        try item.saveItem(value)
    }

    private func validKey(_ key: Data) throws {
        guard key.count == keyBytes else {
            throw ChatCryptoError.invalidKey
        }
    }
    private func contextJson(_ parts: [String]) throws -> Data {
        try JSONSerialization.data(withJSONObject: parts, options: [])
    }
    /// Constant-time compare (same idea as `MessageDigest.isEqual`).
    private func constantTimeEqual<D: DataProtocol, E: DataProtocol>(_ lhs: D, _ rhs: E) -> Bool {
        let left = Data(lhs)
        let right = Data(rhs)
        guard left.count == right.count else { return false }
        return zip(left, right).reduce(into: 0) { $0 |= Int($1.0 ^ $1.1) } == 0
    }

    let keyBytes = 32
    let tagBytes = 16
    static let grantMagic = Data([87, 83, 67, 71, 1]) // WSCG v1
    func toBase64(_ bytes: Data) -> String {
        bytes.base64EncodedString()
    }
    func decryptGroupKeyGrant(
            envelope: Data,
            streamUuid: String,
            context: MessageResponsePayload.KeyGrant
        ) throws -> Data {
            try validKey(chatRequestPrivateKey)
            try validKey(chatRequestPublicKey)
            let info = try grantInfo(context, streamUuid: streamUuid)
            let magicCount = UserProfile.grantMagic.count
            let expectedSize = magicCount + keyBytes * 2 + tagBytes
            guard envelope.count == expectedSize,
                  constantTimeEqual(envelope.prefix(magicCount), UserProfile.grantMagic)
            else {
                throw ChatCryptoError.invalidCiphertext
            }
            do {
                let derivedPublic = try Curve25519.KeyAgreement.PrivateKey(
                    rawRepresentation: chatRequestPrivateKey
                ).publicKey.rawRepresentation
                guard constantTimeEqual(derivedPublic, chatRequestPublicKey) else {
                    throw CryptoKitError.incorrectParameterSize
                }
                let encapsulatedKey = envelope.subdata(in: magicCount..<(magicCount + keyBytes))
                let ciphertext = envelope.subdata(in: (magicCount + keyBytes)..<envelope.count)
                var aad = Data()
                aad.append(info)
                aad.append(UserProfile.grantMagic)
                aad.append(chatRequestPublicKey)
                return try HpkeBase.open(
                    recipientPrivate: chatRequestPrivateKey,
                    recipientPublic: chatRequestPublicKey,
                    enc: encapsulatedKey,
                    info: info,
                    aad: aad,
                    ciphertext: ciphertext
                )
            } catch {
                throw ChatCryptoError.invalidCiphertext
            }
        }
    func grantInfo(_ context: MessageResponsePayload.KeyGrant, streamUuid: String) throws -> Data {
            let fields = [
                streamUuid,
                context.keyUuid,
                context.requestMessageUuid,
                context.senderDeviceId,
                context.recipientDeviceId,
            ]
            if fields.contains(where: \.isEmpty) {
                throw ChatCryptoError.invalidContext
            }
            return try contextJson([
                "workspace-chat-crypto-v1",
                "grant",
                streamUuid,
                context.keyUuid,
                context.requestMessageUuid,
                context.senderDeviceId,
                context.recipientDeviceId,
            ])
        }
}

enum HpkeBase {
    /// DHKEM(X25519, HKDF-SHA256) + HKDF-SHA256 + ChaCha20-Poly1305 (RFC 9180)
    private static let kemID: UInt16 = 0x0020
    private static let kdfID: UInt16 = 0x0001
    private static let aeadID: UInt16 = 0x0003 // ChaCha20Poly1305
    private static let nSecret = 32
    private static let nK = 32
    private static let nN = 12
    static func open(
        recipientPrivate: Data,
        recipientPublic: Data,
        enc: Data,
        info: Data,
        aad: Data,
        ciphertext: Data
    ) throws -> Data {
        var shared = try sharedSecret(
            recipientPrivate: recipientPrivate,
            peerPublic: enc,
            enc: enc,
            recipientPublic: recipientPublic
        )
        defer { shared.resetBytes(in: 0..<shared.count) }
        return try crypt(sharedSecret: shared, info: info) { key, nonce in
            try ChaChaAead.decrypt(key: key, nonce: nonce, ciphertext: ciphertext, aad: aad)
        }
    }

    static func seal(
        recipientPublic: Data,
        ephemeralPrivate: Data,
        info: Data,
        aad: Data,
        plaintext: Data
    ) throws -> (enc: Data, ciphertext: Data) {
        let skE = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: ephemeralPrivate)
        let enc = Data(skE.publicKey.rawRepresentation)
        var shared = try sharedSecret(
            recipientPrivate: ephemeralPrivate,
            peerPublic: recipientPublic,
            enc: enc,
            recipientPublic: recipientPublic
        )
        defer { shared.resetBytes(in: 0..<shared.count) }
        let ciphertext = try crypt(sharedSecret: shared, info: info) { key, nonce in
            try ChaChaAead.encrypt(key: key, nonce: nonce, plaintext: plaintext, aad: aad)
        }
        return (enc, ciphertext)
    }

    /// DHKEM.Decap: DH(skR, enc), kem_context = enc || pkR
    private static func sharedSecret(
        recipientPrivate: Data,
        peerPublic: Data,
        enc: Data,
        recipientPublic: Data
    ) throws -> Data {
        let skR = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: recipientPrivate)
        let pkE = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublic)
        let dh = try skR.sharedSecretFromKeyAgreement(with: pkE)
        var kemContext = Data()
        kemContext.append(enc)
        kemContext.append(recipientPublic)
        let kemSuiteID = Data("KEM".utf8) + i2osp(Int(kemID), 2)
        return dh.withUnsafeBytes { dhBytes in
            extractAndExpand(
                dh: Data(dhBytes),
                kemContext: kemContext,
                suiteID: kemSuiteID
            )
        }
    }
    private static func extractAndExpand(dh: Data, kemContext: Data, suiteID: Data) -> Data {
        let eaePrk = labeledExtract(salt: Data(), label: "eae_prk", ikm: dh, suiteID: suiteID)
        return labeledExpand(prk: eaePrk, label: "shared_secret", info: kemContext, length: nSecret, suiteID: suiteID)
    }
    /// HPKE Base key schedule, then a single AEAD op (seq = 0 → nonce = base_nonce).
    private static func crypt(
        sharedSecret: Data,
        info: Data,
        _ body: (SymmetricKey, Data) throws -> Data
    ) throws -> Data {
        let suiteID = hpkeSuiteID()
        let psk = Data()
        let pskID = Data()
        let pskIDHash = labeledExtract(salt: Data(), label: "psk_id_hash", ikm: pskID, suiteID: suiteID)
        let infoHash = labeledExtract(salt: Data(), label: "info_hash", ikm: info, suiteID: suiteID)
        var keyScheduleContext = Data([0x00]) // mode_base
        pskIDHash.withUnsafeBytes { keyScheduleContext.append(contentsOf: $0) }
        infoHash.withUnsafeBytes { keyScheduleContext.append(contentsOf: $0) }
        let secret = labeledExtract(salt: sharedSecret, label: "secret", ikm: psk, suiteID: suiteID)
        let key = SymmetricKey(data: labeledExpand(prk: secret, label: "key", info: keyScheduleContext, length: nK, suiteID: suiteID))
        let nonce = labeledExpand(prk: secret, label: "base_nonce", info: keyScheduleContext, length: nN, suiteID: suiteID)
        return try body(key, nonce)
    }
    private static func hpkeSuiteID() -> Data {
        Data("HPKE".utf8) + i2osp(Int(kemID), 2) + i2osp(Int(kdfID), 2) + i2osp(Int(aeadID), 2)
    }
}
enum ChaChaAead {
    /// `ciphertext` is ct || tag (16-byte Poly1305 tag).
    static func decrypt(key: SymmetricKey, nonce: Data, ciphertext: Data, aad: Data) throws -> Data {
        guard ciphertext.count >= 16 else { throw ChatCryptoError.invalidCiphertext }
        let tag = ciphertext.suffix(16)
        let ct = ciphertext.prefix(ciphertext.count - 16)
        let box = try ChaChaPoly.SealedBox(
            nonce: ChaChaPoly.Nonce(data: nonce),
            ciphertext: ct,
            tag: tag
        )
        return try ChaChaPoly.open(box, using: key, authenticating: aad)
    }

    static func encrypt(key: SymmetricKey, nonce: Data, plaintext: Data, aad: Data) throws -> Data {
        let sealed = try ChaChaPoly.seal(
            plaintext,
            using: key,
            nonce: ChaChaPoly.Nonce(data: nonce),
            authenticating: aad
        )
        var out = Data()
        out.append(sealed.ciphertext)
        out.append(sealed.tag)
        return out
    }
}
func contextJson(_ parts: [String]) throws -> Data {
    // kotlinx.serialization Json.encodeToString(List<String>) → compact UTF-8 JSON array
    try JSONSerialization.data(withJSONObject: parts, options: [])
}
// MARK: RFC 9180 labeled HKDF-SHA256
private func labeledExtract(salt: Data, label: String, ikm: Data, suiteID: Data) -> SymmetricKey {
    var labeledIKM = Data("HPKE-v1".utf8)
    labeledIKM.append(suiteID)
    labeledIKM.append(Data(label.utf8))
    labeledIKM.append(ikm)
    let prk: HashedAuthenticationCode<SHA256> = HKDF<SHA256>.extract(
            inputKeyMaterial: SymmetricKey(data: labeledIKM),
            salt: salt
        )
        return prk.withUnsafeBytes { SymmetricKey(data: Data($0)) }
}



enum ChatCryptoError: Error {
    case invalidCiphertext
    case invalidContext
    case invalidKey
    case unavailable
}

private func labeledExpand(prk: SymmetricKey, label: String, info: Data, length: Int, suiteID: Data) -> Data {
    var labeledInfo = i2osp(length, 2)
    labeledInfo.append(Data("HPKE-v1".utf8))
    labeledInfo.append(suiteID)
    labeledInfo.append(Data(label.utf8))
    labeledInfo.append(info)
    let okm = HKDF<SHA256>.expand(pseudoRandomKey: prk, info: labeledInfo, outputByteCount: length)
    return okm.withUnsafeBytes { Data($0) }
}
private func i2osp(_ n: Int, _ len: Int) -> Data {
    var value = n
    var bytes = Data(count: len)
    for i in stride(from: len - 1, through: 0, by: -1) {
        bytes[i] = UInt8(value & 0xff)
        value >>= 8
    }
    return bytes
}


enum UserProfileKeichainKey: String {
    case accessTokenKey
    case refreshTokenKey
    case chatRequestPublicKeyKey
    case chatRequestPrivateKeyKey
    case encryptedChatKey
}

enum UserProfileUserDefaultsKey: String {
    case selectedServerConfigKey = "com.exordos.workspace.currentServerKey"
    case deviceKey = "com.exordos.workspace.deviceKey"
}
