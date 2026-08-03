import Foundation

actor WorkspaceAPI {
    private enum Constants {
        static let userAgent = "Workspace/ios/0.1.0"
        static let projectScope = "project:fe02e55d-4548-4b3e-a175-fcae928f41b2"
    }

    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var cachedSessions: [String: WorkspaceSession] = [:]
    private var refreshTasks: [String: Task<WorkspaceSession, Error>] = [:]
    private var sessionRefreshObserver: (@Sendable (WorkspaceSession) async -> Void)?

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    func setSessionRefreshObserver(
        _ observer: @escaping @Sendable (WorkspaceSession) async -> Void
    ) {
        sessionRefreshObserver = observer
    }

    func cacheSession(_ session: WorkspaceSession) {
        cachedSessions[sessionKey(session)] = session
    }

    func discardSession(_ session: WorkspaceSession) {
        cachedSessions.removeValue(forKey: sessionKey(session))
    }

    func currentSession(for session: WorkspaceSession) -> WorkspaceSession {
        activeSession(for: session)
    }

    static func normalizedServerURL(from input: String) throws -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WorkspaceAPIError.invalidServerURL }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: candidate),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false
        else {
            throw WorkspaceAPIError.invalidServerURL
        }

        components.scheme = "https"
        components.query = nil
        components.fragment = nil
        if components.path == "/" { components.path = "" }
        guard let url = components.url else { throw WorkspaceAPIError.invalidServerURL }
        return url
    }

    func serverSettings(for input: String) async throws -> WorkspaceServer {
        let baseURL = try Self.normalizedServerURL(from: input)
        let response: ServerSettingsResponse = try await send(
            baseURL: baseURL,
            path: "/api/workspace/v1/messenger/server_settings/"
        )
        return WorkspaceServer(
            baseURL: baseURL,
            realmName: response.realmName,
            meetURL: response.meetURL.flatMap(URL.init(string:))
        )
    }

    func login(
        server: WorkspaceServer,
        username: String,
        password: String,
        otp: String?
    ) async throws -> WorkspaceSession {
        let body = LoginRequestBody(
            login: username,
            password: password,
            grantType: "login+password",
            scope: "openid email profile \(Constants.projectScope)",
            ttl: "3600",
            refreshTTL: "172800"
        )
        var headers: [String: String] = [:]
        if let otp, !otp.isEmpty { headers["X-OTP"] = otp }

        let response: TokenResponse = try await send(
            baseURL: server.baseURL,
            path: "/api/core/v1/iam/clients/default/actions/get_token/invoke",
            method: "POST",
            body: try encoder.encode(body),
            additionalHeaders: headers
        )
        let session = WorkspaceSession(
            server: server,
            username: username,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken
        )
        cacheSession(session)
        return session
    }

    func refresh(_ session: WorkspaceSession) async throws -> WorkspaceSession {
        let body = RefreshRequestBody(grantType: "refresh_token", refreshToken: session.refreshToken)
        let response: TokenResponse = try await send(
            baseURL: session.server.baseURL,
            path: "/api/core/v1/iam/clients/default/actions/get_token/invoke",
            method: "POST",
            body: try encoder.encode(body)
        )
        let refreshed = WorkspaceSession(
            server: session.server,
            username: session.username,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken
        )
        cacheSession(refreshed)
        if let sessionRefreshObserver { await sessionRefreshObserver(refreshed) }
        return refreshed
    }

    func currentUser(session: WorkspaceSession) async throws -> WorkspaceUser {
        try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/me/"
        )
    }

    func streams(session: WorkspaceSession) async throws -> [WorkspaceStream] {
        try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/streams/"
        )
    }

    func folders(session: WorkspaceSession) async throws -> [WorkspaceFolder] {
        try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/folders/"
        )
    }

    func users(session: WorkspaceSession) async throws -> [WorkspaceUser] {
        try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/users/"
        )
    }

    func streamBindings(session: WorkspaceSession) async throws -> [WorkspaceStreamBinding] {
        try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/stream_bindings/"
        )
    }

    func setStreamNotificationMode(
        session: WorkspaceSession,
        streamUUID: String,
        mode: String
    ) async throws -> WorkspaceStream {
        try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/streams/\(streamUUID)/actions/notifications/invoke",
            method: "POST",
            body: try encoder.encode(NotificationModeBody(notificationMode: mode))
        )
    }

    func setTopicNotificationMode(
        session: WorkspaceSession,
        topicUUID: String,
        mode: String
    ) async throws -> WorkspaceTopic {
        try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/stream_topics/\(topicUUID)/actions/notifications/invoke",
            method: "POST",
            body: try encoder.encode(NotificationModeBody(notificationMode: mode))
        )
    }

    func registerPushDevice(
        session: WorkspaceSession,
        registrationUUID: String,
        token: String,
        keyUUID: String,
        publicKey: String
    ) async throws -> WorkspacePushDeviceResponse {
        let body = PushDeviceBody(
            transport: "fcm",
            platform: "ios",
            registrationToken: token,
            encryption: PushDeviceEncryptionBody(
                kind: "HPKE",
                algorithm: "HPKE-v1-BASE-X25519-HKDF-SHA256-AES-256-GCM",
                keyUUID: keyUUID,
                publicKey: publicKey
            )
        )
        return try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/push_devices/\(registrationUUID)",
            method: "PUT",
            body: try encoder.encode(body)
        )
    }

    func deletePushDevice(session: WorkspaceSession, registrationUUID: String) async throws {
        try await sendNoContentAuthorized(
            session: session,
            path: "/api/workspace/v1/push_devices/\(registrationUUID)",
            method: "DELETE"
        )
    }

    func createDirectStream(
        session: WorkspaceSession,
        userUUID: String
    ) async throws -> WorkspaceStream {
        let request = CreateStreamBody(
            name: "Direct",
            description: "Private workspace",
            directUserUUID: userUUID,
            sourceName: "native",
            source: CreateStreamSource(kind: "native")
        )
        return try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/streams/",
            method: "POST",
            body: try encoder.encode(request)
        )
    }

    func createFolder(session: WorkspaceSession, title: String) async throws -> WorkspaceFolder {
        try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/folders/",
            method: "POST",
            body: try encoder.encode(FolderBody(title: title))
        )
    }

    func deleteFolder(session: WorkspaceSession, folderUUID: String) async throws {
        try await sendNoContentAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/folders/\(folderUUID)",
            method: "DELETE"
        )
    }

    func addFolderItem(
        session: WorkspaceSession,
        folderUUID: String,
        streamUUID: String,
        chatType: String
    ) async throws -> WorkspaceFolderItem {
        let request = FolderItemBody(
            folderUUID: folderUUID,
            streamUUID: streamUUID,
            chatType: chatType
        )
        return try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/folder_items/",
            method: "POST",
            body: try encoder.encode(request)
        )
    }

    func deleteFolderItem(session: WorkspaceSession, itemUUID: String) async throws {
        try await sendNoContentAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/folder_items/\(itemUUID)",
            method: "DELETE"
        )
    }

    func epoch(session: WorkspaceSession) async throws -> WorkspaceEpoch {
        try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/epoch/"
        )
    }

    func topics(session: WorkspaceSession, streamUUID: String) async throws -> [WorkspaceTopic] {
        try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/stream_topics/",
            queryItems: [URLQueryItem(name: "stream_uuid", value: streamUUID)]
        )
    }

    func messages(
        session: WorkspaceSession,
        streamUUID: String,
        topicUUID: String?
    ) async throws -> [WorkspaceMessage] {
        var queryItems = [URLQueryItem(name: "stream_uuid", value: streamUUID)]
        if let topicUUID, !topicUUID.isEmpty {
            queryItems.append(URLQueryItem(name: "topic_uuid", value: topicUUID))
        }
        return try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/messages/",
            queryItems: queryItems
        )
    }

    func sendMessage(
        session: WorkspaceSession,
        streamUUID: String,
        topicUUID: String?,
        content: String
    ) async throws -> SendMessageResponse {
        let request = SendMessageBody(
            streamUUID: streamUUID,
            topicUUID: topicUUID,
            payload: WorkspaceMessagePayload(kind: "markdown", content: content)
        )
        return try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/messages/",
            method: "POST",
            body: try encoder.encode(request)
        )
    }

    func editMessage(
        session: WorkspaceSession,
        messageUUID: String,
        content: String
    ) async throws -> EditMessageResponse {
        let request = EditMessageBody(
            payload: WorkspaceMessagePayload(kind: "markdown", content: content)
        )
        return try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/messages/\(messageUUID)",
            method: "PUT",
            body: try encoder.encode(request)
        )
    }

    func markRead(session: WorkspaceSession, messageUUID: String) async throws -> MarkReadResponse {
        try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/messages/\(messageUUID)/actions/read_up_to/invoke",
            method: "POST"
        )
    }

    func reactions(session: WorkspaceSession, userUUID: String) async throws -> [WorkspaceMessageReaction] {
        try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/message_reactions/",
            queryItems: [URLQueryItem(name: "user_uuid", value: userUUID)]
        )
    }

    func addReaction(
        session: WorkspaceSession,
        messageUUID: String,
        emoji: String
    ) async throws -> WorkspaceMessageReaction {
        let request = AddReactionBody(messageUUID: messageUUID, emojiName: emoji)
        return try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/message_reactions/",
            method: "POST",
            body: try encoder.encode(request)
        )
    }

    func removeReaction(session: WorkspaceSession, reactionUUID: String) async throws {
        try await sendNoContentAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/message_reactions/\(reactionUUID)",
            method: "DELETE"
        )
    }

    func uploadFile(
        session: WorkspaceSession,
        streamUUID: String,
        data: Data,
        filename: String,
        mimeType: String
    ) async throws -> WorkspaceUpload {
        let boundary = "WorkspaceBoundary-\(UUID().uuidString)"
        var body = Data()
        body.appendMultipartField(name: "stream_uuid", value: streamUUID, boundary: boundary)
        body.appendMultipartFile(
            name: "file",
            filename: filename,
            mimeType: mimeType,
            data: data,
            boundary: boundary
        )
        body.append("--\(boundary)--\r\n")

        return try await sendAuthorized(
            session: session,
            path: "/api/workspace/v1/messenger/files/",
            method: "POST",
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
    }

    func fileData(session: WorkspaceSession, fileUUID: String) async throws -> Data {
        try await authorizedData(
            session: session,
            path: "/api/workspace/v1/messenger/files/\(fileUUID)/actions/download"
        )
    }

    private func sendAuthorized<Response: Decodable>(
        session: WorkspaceSession,
        path: String,
        method: String = "GET",
        body: Data? = nil,
        queryItems: [URLQueryItem] = [],
        contentType: String? = nil
    ) async throws -> Response {
        let activeSession = activeSession(for: session)
        do {
            return try await send(
                baseURL: activeSession.server.baseURL,
                path: path,
                method: method,
                body: body,
                queryItems: queryItems,
                contentType: contentType,
                additionalHeaders: ["Authorization": "Bearer \(activeSession.accessToken)"]
            )
        } catch WorkspaceAPIError.http(let statusCode, _) where statusCode == 401 {
            let refreshed = try await refreshedSession(afterUnauthorized: activeSession)
            return try await send(
                baseURL: refreshed.server.baseURL,
                path: path,
                method: method,
                body: body,
                queryItems: queryItems,
                contentType: contentType,
                additionalHeaders: ["Authorization": "Bearer \(refreshed.accessToken)"]
            )
        }
    }

    private func sendNoContentAuthorized(
        session: WorkspaceSession,
        path: String,
        method: String
    ) async throws {
        let activeSession = activeSession(for: session)
        do {
            try await sendNoContent(
                session: activeSession,
                path: path,
                method: method
            )
        } catch WorkspaceAPIError.http(let statusCode, _) where statusCode == 401 {
            let refreshed = try await refreshedSession(afterUnauthorized: activeSession)
            try await sendNoContent(session: refreshed, path: path, method: method)
        }
    }

    private func sendNoContent(
        session: WorkspaceSession,
        path: String,
        method: String
    ) async throws {
        guard let url = URL(string: path, relativeTo: session.server.baseURL)?.absoluteURL else {
            throw WorkspaceAPIError.invalidServerURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await urlSession.data(for: request)
        } catch {
            throw WorkspaceAPIError.transport(error.localizedDescription)
        }
        guard let response = response as? HTTPURLResponse else {
            throw WorkspaceAPIError.unexpectedResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw WorkspaceAPIError.http(statusCode: response.statusCode, body: "")
        }
    }

    private func authorizedData(session: WorkspaceSession, path: String) async throws -> Data {
        let activeSession = activeSession(for: session)
        do {
            return try await data(session: activeSession, path: path)
        } catch WorkspaceAPIError.http(let statusCode, _) where statusCode == 401 {
            let refreshed = try await refreshedSession(afterUnauthorized: activeSession)
            return try await data(session: refreshed, path: path)
        }
    }

    private func data(session: WorkspaceSession, path: String) async throws -> Data {
        guard let url = URL(string: path, relativeTo: session.server.baseURL)?.absoluteURL else {
            throw WorkspaceAPIError.invalidServerURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await urlSession.data(for: request)
        } catch {
            throw WorkspaceAPIError.transport(error.localizedDescription)
        }
        guard let response = response as? HTTPURLResponse else {
            throw WorkspaceAPIError.unexpectedResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw WorkspaceAPIError.http(
                statusCode: response.statusCode,
                body: String(decoding: responseData, as: UTF8.self)
            )
        }
        return responseData
    }

    private func activeSession(for requested: WorkspaceSession) -> WorkspaceSession {
        cachedSessions[sessionKey(requested)] ?? requested
    }

    private func refreshedSession(afterUnauthorized session: WorkspaceSession) async throws -> WorkspaceSession {
        let key = sessionKey(session)
        if let cached = cachedSessions[key], cached.accessToken != session.accessToken {
            return cached
        }
        if let task = refreshTasks[key] { return try await task.value }

        let task = Task { try await self.refresh(session) }
        refreshTasks[key] = task
        do {
            let refreshed = try await task.value
            refreshTasks.removeValue(forKey: key)
            return refreshed
        } catch {
            refreshTasks.removeValue(forKey: key)
            throw error
        }
    }

    private func sessionKey(_ session: WorkspaceSession) -> String {
        "\(session.server.baseURL.absoluteString)|\(session.username)"
    }

    private func send<Response: Decodable>(
        baseURL: URL,
        path: String,
        method: String = "GET",
        body: Data? = nil,
        queryItems: [URLQueryItem] = [],
        contentType: String? = nil,
        additionalHeaders: [String: String] = [:]
    ) async throws -> Response {
        guard let relativeURL = URL(string: path, relativeTo: baseURL)?.absoluteURL,
              var components = URLComponents(url: relativeURL, resolvingAgainstBaseURL: false)
        else {
            throw WorkspaceAPIError.invalidServerURL
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw WorkspaceAPIError.invalidServerURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue(contentType ?? "application/json", forHTTPHeaderField: "Content-Type")
        }
        additionalHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw WorkspaceAPIError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkspaceAPIError.unexpectedResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw WorkspaceAPIError.http(
                statusCode: httpResponse.statusCode,
                body: String(decoding: data, as: UTF8.self)
            )
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw WorkspaceAPIError.decoding(error.localizedDescription)
        }
    }
}

nonisolated struct SendMessageResponse: Decodable, Sendable {
    let uuid: String
    let topicUUID: String

    enum CodingKeys: String, CodingKey {
        case uuid
        case topicUUID = "topic_uuid"
    }
}

nonisolated struct EditMessageResponse: Decodable, Sendable {
    let uuid: String
}

nonisolated struct MarkReadResponse: Decodable, Sendable {
    let messages: [Int]
}

nonisolated struct WorkspaceEpoch: Decodable, Sendable {
    let version: Int
    let generation: String

    enum CodingKeys: String, CodingKey {
        case version = "epoch_version"
        case generation = "epoch_generation"
    }
}

nonisolated struct WorkspacePushDeviceResponse: Decodable, Sendable {
    let uuid: String
}

private nonisolated struct SendMessageBody: Encodable {
    let streamUUID: String
    let topicUUID: String?
    let payload: WorkspaceMessagePayload

    enum CodingKeys: String, CodingKey {
        case streamUUID = "stream_uuid"
        case topicUUID = "topic_uuid"
        case payload
    }
}

private nonisolated struct EditMessageBody: Encodable {
    let payload: WorkspaceMessagePayload
}

private nonisolated struct AddReactionBody: Encodable {
    let messageUUID: String
    let emojiName: String

    enum CodingKeys: String, CodingKey {
        case messageUUID = "message_uuid"
        case emojiName = "emoji_name"
    }
}

private nonisolated struct CreateStreamBody: Encodable {
    let name: String
    let description: String
    let directUserUUID: String?
    let sourceName: String
    let source: CreateStreamSource

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case directUserUUID = "direct_user_uuid"
        case sourceName = "source_name"
        case source
    }
}

private nonisolated struct CreateStreamSource: Encodable {
    let kind: String
}

private nonisolated struct FolderBody: Encodable {
    let title: String
}

private nonisolated struct FolderItemBody: Encodable {
    let folderUUID: String
    let streamUUID: String
    let chatType: String

    enum CodingKeys: String, CodingKey {
        case folderUUID = "folder_uuid"
        case streamUUID = "stream_uuid"
        case chatType = "chat_type"
    }
}

private nonisolated struct NotificationModeBody: Encodable {
    let notificationMode: String

    enum CodingKeys: String, CodingKey {
        case notificationMode = "notification_mode"
    }
}

private nonisolated struct PushDeviceBody: Encodable {
    let transport: String
    let platform: String
    let registrationToken: String
    let encryption: PushDeviceEncryptionBody

    enum CodingKeys: String, CodingKey {
        case transport
        case platform
        case registrationToken = "registration_token"
        case encryption
    }
}

private nonisolated struct PushDeviceEncryptionBody: Encodable {
    let kind: String
    let algorithm: String
    let keyUUID: String
    let publicKey: String

    enum CodingKeys: String, CodingKey {
        case kind
        case algorithm
        case keyUUID = "key_uuid"
        case publicKey = "public_key"
    }
}

private nonisolated extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func appendMultipartFile(
        name: String,
        filename: String,
        mimeType: String,
        data: Data,
        boundary: String
    ) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        append(data)
        append("\r\n")
    }
}

nonisolated enum WorkspaceAPIError: Error, LocalizedError, Sendable {
    case invalidServerURL
    case transport(String)
    case unexpectedResponse
    case http(statusCode: Int, body: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            "Введите корректный HTTPS-адрес Workspace"
        case .transport:
            "Не удалось подключиться к серверу. Проверьте соединение"
        case .unexpectedResponse:
            "Сервер вернул некорректный ответ"
        case .http(let statusCode, _):
            "Сервер вернул ошибку \(statusCode)"
        case .decoding:
            "Не удалось прочитать ответ сервера"
        }
    }
}

private nonisolated struct ServerSettingsResponse: Decodable {
    let realmName: String
    let meetURL: String?

    enum CodingKeys: String, CodingKey {
        case realmName = "realm_name"
        case meetURL = "meet_url"
    }
}

private nonisolated struct LoginRequestBody: Encodable {
    let login: String
    let password: String
    let grantType: String
    let scope: String
    let ttl: String
    let refreshTTL: String

    enum CodingKeys: String, CodingKey {
        case login
        case password
        case grantType = "grant_type"
        case scope
        case ttl
        case refreshTTL = "refresh_ttl"
    }
}

private nonisolated struct RefreshRequestBody: Encodable {
    let grantType: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
    }
}

private nonisolated struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
