import Foundation

nonisolated enum WorkspaceRealtimeAction: String, Equatable, Sendable {
    case created
    case updated
    case deleted
}

nonisolated struct WorkspaceDeletedReaction: Decodable, Sendable {
    let uuid: String
    let userUUID: String

    enum CodingKeys: String, CodingKey {
        case uuid
        case userUUID = "user_uuid"
    }
}

nonisolated struct WorkspaceDeletedObject: Decodable, Sendable {
    let uuid: String
    let streamUUID: String?
    let topicUUID: String?

    enum CodingKeys: String, CodingKey {
        case uuid
        case streamUUID = "stream_uuid"
        case topicUUID = "topic_uuid"
    }
}

nonisolated enum WorkspaceRealtimeEvent: Sendable {
    case message(WorkspaceRealtimeAction, WorkspaceMessage)
    case user(WorkspaceRealtimeAction, WorkspaceUser)
    case folder(WorkspaceRealtimeAction, WorkspaceFolder)
    case stream(WorkspaceRealtimeAction, WorkspaceStream)
    case topic(WorkspaceRealtimeAction, WorkspaceTopic)
    case reaction(WorkspaceRealtimeAction, WorkspaceMessageReaction)
    case deletedReaction(WorkspaceDeletedReaction)
    case deletedMessage(WorkspaceDeletedObject)
    case deletedUser(WorkspaceDeletedObject)
    case deletedFolder(WorkspaceDeletedObject)
    case deletedStream(WorkspaceDeletedObject)
    case deletedTopic(WorkspaceDeletedObject)
}

actor WorkspaceRealtimeClient {
    private let api: WorkspaceAPI
    private let urlSession: URLSession
    private let decoder = JSONDecoder()
    private var connectionTask: Task<Void, Never>?
    private var webSocketTask: URLSessionWebSocketTask?
    private var latestEpoch = 0
    private var epochGeneration = ""

    init(api: WorkspaceAPI, urlSession: URLSession = .shared) {
        self.api = api
        self.urlSession = urlSession
    }

    func events(session: WorkspaceSession) -> AsyncStream<WorkspaceRealtimeEvent> {
        AsyncStream { continuation in
            connectionTask?.cancel()
            connectionTask = Task { [weak self] in
                await self?.run(session: session, continuation: continuation)
            }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.stop() }
            }
        }
    }

    func stop() {
        connectionTask?.cancel()
        connectionTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        latestEpoch = 0
        epochGeneration = ""
    }

    private func run(
        session: WorkspaceSession,
        continuation: AsyncStream<WorkspaceRealtimeEvent>.Continuation
    ) async {
        var retryNanoseconds: UInt64 = 1_000_000_000

        while !Task.isCancelled {
            do {
                if epochGeneration.isEmpty {
                    let epoch = try await api.epoch(session: session)
                    latestEpoch = epoch.version
                    epochGeneration = epoch.generation
                }
                try await receiveEvents(session: session, continuation: continuation)
                retryNanoseconds = 1_000_000_000
            } catch is CancellationError {
                break
            } catch {
                webSocketTask?.cancel(with: .goingAway, reason: nil)
                webSocketTask = nil
            }

            guard !Task.isCancelled else { break }
            try? await Task.sleep(nanoseconds: retryNanoseconds)
            retryNanoseconds = min(retryNanoseconds * 2, 30_000_000_000)
        }
        continuation.finish()
    }

    private func receiveEvents(
        session: WorkspaceSession,
        continuation: AsyncStream<WorkspaceRealtimeEvent>.Continuation
    ) async throws {
        let activeSession = await api.currentSession(for: session)
        guard var components = URLComponents(
            url: activeSession.server.baseURL.appending(path: "/api/workspace/v1/events/ws"),
            resolvingAgainstBaseURL: false
        ) else {
            throw WorkspaceAPIError.invalidServerURL
        }
        components.scheme = "wss"
        components.queryItems = [
            URLQueryItem(name: "last_epoch_version", value: String(latestEpoch)),
            URLQueryItem(name: "epoch_generation", value: epochGeneration),
        ]
        guard let url = components.url else { throw WorkspaceAPIError.invalidServerURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(
            "workspace.events.v1, bearer.\(activeSession.accessToken)",
            forHTTPHeaderField: "Sec-WebSocket-Protocol"
        )
        let task = urlSession.webSocketTask(with: request)
        webSocketTask = task
        task.resume()

        while !Task.isCancelled {
            let message = try await task.receive()
            switch message {
            case .string(let text):
                do {
                    if let event = try process(text) {
                        continuation.yield(event)
                    }
                } catch {
                    continue
                }
            case .data:
                continue
            @unknown default:
                continue
            }
        }
    }

    private func process(_ text: String) throws -> WorkspaceRealtimeEvent? {
        guard let data = text.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        if object["type"] as? String == "ready" {
            if let generation = object["epoch_generation"] as? String {
                epochGeneration = generation
            }
            if let version = integer(object["epoch_version"]) {
                latestEpoch = max(latestEpoch, version)
            }
            return nil
        }

        let eventEpoch = integer(object["epoch_version"])
        if let eventEpoch, eventEpoch <= latestEpoch { return nil }
        defer {
            if let eventEpoch { latestEpoch = max(latestEpoch, eventEpoch) }
        }

        guard let actionValue = object["action"] as? String,
              let action = WorkspaceRealtimeAction(rawValue: actionValue),
              let objectType = object["object_type"] as? String,
              let payload = object["payload"],
              JSONSerialization.isValidJSONObject(payload)
        else { return nil }

        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        if action == .deleted, objectType != "message_reaction" {
            let deleted = try decoder.decode(WorkspaceDeletedObject.self, from: payloadData)
            switch objectType {
            case "message": return .deletedMessage(deleted)
            case "user": return .deletedUser(deleted)
            case "folder": return .deletedFolder(deleted)
            case "stream": return .deletedStream(deleted)
            case "topic": return .deletedTopic(deleted)
            default: return nil
            }
        }
        switch objectType {
        case "message":
            return .message(action, try decoder.decode(WorkspaceMessage.self, from: payloadData))
        case "user":
            return .user(action, try decoder.decode(WorkspaceUser.self, from: payloadData))
        case "folder":
            return .folder(action, try decoder.decode(WorkspaceFolder.self, from: payloadData))
        case "stream":
            return .stream(action, try decoder.decode(WorkspaceStream.self, from: payloadData))
        case "topic":
            return .topic(action, try decoder.decode(WorkspaceTopic.self, from: payloadData))
        case "message_reaction" where action == .deleted:
            return .deletedReaction(try decoder.decode(WorkspaceDeletedReaction.self, from: payloadData))
        case "message_reaction":
            return .reaction(action, try decoder.decode(WorkspaceMessageReaction.self, from: payloadData))
        default:
            return nil
        }
    }

    private func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}
