import Foundation
import Observation

enum WorkspaceAppPhase: Hashable {
    case restoring
    case signedOut
    case signedIn
}

@MainActor
@Observable
final class WorkspaceAppModel {
    private let api: WorkspaceAPI
    private let sessionStore: WorkspaceSessionStore
    private let realtimeClient: WorkspaceRealtimeClient
    private let pushRegistrationManager: WorkspacePushRegistrationManager
    private var realtimeTask: Task<Void, Never>?
    private var pushTokenTask: Task<Void, Never>?
    private var pushRouteTask: Task<Void, Never>?

    private(set) var phase: WorkspaceAppPhase = .restoring
    private(set) var selectedServer: WorkspaceServer?
    private(set) var session: WorkspaceSession?
    private(set) var currentUser: WorkspaceUser?
    private(set) var streams: [WorkspaceStream] = []
    private(set) var folders: [WorkspaceFolder] = []
    private(set) var users: [WorkspaceUser] = []
    private(set) var isWorking = false
    private(set) var needsOTP = false
    private(set) var errorMessage: String?
    private(set) var latestRealtimeEvent: WorkspaceRealtimeEvent?
    private(set) var realtimeRevision = 0
    private(set) var pendingPushRoute: WorkspacePushRoute?
    private(set) var pushRouteRevision = 0

    var workspaceAPI: WorkspaceAPI { api }

    init(
        api: WorkspaceAPI = WorkspaceAPI(),
        sessionStore: WorkspaceSessionStore? = nil
    ) {
        self.api = api
        self.sessionStore = sessionStore ?? WorkspaceSessionStore()
        realtimeClient = WorkspaceRealtimeClient(api: api)
        pushRegistrationManager = WorkspacePushRegistrationManager(api: api)
        Task { [weak self] in
            guard let self else { return }
            await api.setSessionRefreshObserver { [weak self] refreshedSession in
                await self?.acceptRefreshedSession(refreshedSession)
            }
        }
        pushTokenTask = Task { [weak self] in
            let updates = WorkspacePushNotifications.shared.tokenUpdates()
            for await token in updates {
                guard let self, let session = self.session else { continue }
                await self.pushRegistrationManager.register(token: token, session: session)
            }
        }
        pushRouteTask = Task { [weak self] in
            let updates = WorkspacePushNotifications.shared.routeUpdates()
            for await route in updates {
                guard let self else { return }
                self.pendingPushRoute = route
                self.pushRouteRevision &+= 1
            }
        }
    }

    func restore() async {
        guard phase == .restoring else { return }

        do {
            guard let storedSession = try sessionStore.load() else {
                phase = .signedOut
                return
            }

            let refreshedSession = try await api.refresh(storedSession)
            try sessionStore.save(refreshedSession)
            session = refreshedSession
            selectedServer = refreshedSession.server
            phase = .signedIn
            await loadWorkspaceContent()
            startRealtime(session: refreshedSession)
            activatePush(session: refreshedSession)
        } catch {
            try? sessionStore.clear()
            clearAuthenticatedState()
            phase = .signedOut
        }
    }

    func selectServer(_ input: String) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            selectedServer = try await api.serverSettings(for: input)
            return true
        } catch {
            errorMessage = publicMessage(for: error)
            return false
        }
    }

    func usePublicServer() async -> Bool {
        await selectServer("https://workspace.exordos.com")
    }

    func clearSelectedServer() {
        guard !isWorking else { return }
        selectedServer = nil
        needsOTP = false
        errorMessage = nil
    }

    func returnToCredentials() {
        guard !isWorking else { return }
        needsOTP = false
        errorMessage = nil
    }

    func signIn(username: String, password: String, otp: String?) async -> Bool {
        guard let selectedServer, !isWorking else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let normalizedOTP = otp?.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let newSession = try await api.login(
                server: selectedServer,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                otp: normalizedOTP
            )
            try sessionStore.save(newSession)
            session = newSession
            needsOTP = false
            phase = .signedIn
            await loadWorkspaceContent()
            startRealtime(session: newSession)
            activatePush(session: newSession)
            return true
        } catch WorkspaceAPIError.http(let statusCode, let body) {
            if LoginErrorClassifier.isOTPChallenge(
                statusCode: statusCode,
                responseBody: body,
                otpProvided: normalizedOTP?.isEmpty == false
            ) {
                needsOTP = true
                return false
            }
            errorMessage = LoginErrorClassifier.publicMessage(
                statusCode: statusCode,
                responseBody: body,
                otpProvided: normalizedOTP?.isEmpty == false
            )
            return false
        } catch {
            errorMessage = publicMessage(for: error)
            return false
        }
    }

    func retryLoadingContent() async {
        await loadWorkspaceContent()
    }

    func createDirectChat(with user: WorkspaceUser) async throws -> WorkspaceStream {
        guard let session else { throw WorkspaceAPIError.unexpectedResponse }
        let stream = try await api.createDirectStream(session: session, userUUID: user.id)
        if let index = streams.firstIndex(where: { $0.id == stream.id }) {
            streams[index] = stream
        } else {
            streams.insert(stream, at: 0)
        }
        return stream
    }

    func createFolder(title: String) async {
        guard let session else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let folder = try await api.createFolder(session: session, title: trimmed)
            if !folders.contains(where: { $0.id == folder.id }) { folders.append(folder) }
        } catch {
            errorMessage = "Не удалось создать папку"
        }
    }

    func deleteFolder(_ folder: WorkspaceFolder) async {
        guard let session, folder.systemType == nil || folder.systemType == "created" else { return }
        do {
            try await api.deleteFolder(session: session, folderUUID: folder.id)
            folders.removeAll { $0.id == folder.id }
        } catch {
            errorMessage = "Не удалось удалить папку"
        }
    }

    func toggle(_ stream: WorkspaceStream, in folder: WorkspaceFolder) async {
        guard let session else { return }
        do {
            if let item = folder.items.first(where: { $0.streamUUID == stream.id }) {
                try await api.deleteFolderItem(session: session, itemUUID: item.id)
            } else {
                _ = try await api.addFolderItem(
                    session: session,
                    folderUUID: folder.id,
                    streamUUID: stream.id,
                    chatType: stream.isPrivate ? "private" : "stream"
                )
            }
            folders = try await api.folders(session: session)
        } catch {
            errorMessage = "Не удалось обновить папку"
        }
    }

    func signOut() {
        let signedOutSession = session
        realtimeTask?.cancel()
        realtimeTask = nil
        Task { await realtimeClient.stop() }
        if let signedOutSession { Task { await api.discardSession(signedOutSession) } }
        if let signedOutSession {
            Task { await pushRegistrationManager.delete(session: signedOutSession) }
        }
        try? sessionStore.clear()
        clearAuthenticatedState()
        selectedServer = nil
        phase = .signedOut
    }

    func dismissError() {
        errorMessage = nil
    }

    func consumePendingPushRoute() {
        pendingPushRoute = nil
    }

    private func loadWorkspaceContent() async {
        guard let session else { return }
        errorMessage = nil

        async let userResult = api.currentUser(session: session)
        async let streamsResult = api.streams(session: session)
        async let foldersResult = api.folders(session: session)
        async let usersResult = api.users(session: session)

        do {
            let (user, streams, folders, users) = try await (
                userResult,
                streamsResult,
                foldersResult,
                usersResult
            )
            currentUser = user
            self.streams = streams.sorted { lhs, rhs in
                if lhs.unreadCount != rhs.unreadCount { return lhs.unreadCount > rhs.unreadCount }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            self.folders = folders
            self.users = users
        } catch {
            errorMessage = "Workspace открыт, но список чатов пока не загрузился. Потяните экран вниз, чтобы повторить"
        }
    }

    private func clearAuthenticatedState() {
        session = nil
        currentUser = nil
        streams = []
        folders = []
        users = []
        needsOTP = false
        errorMessage = nil
        latestRealtimeEvent = nil
        realtimeRevision = 0
    }

    private func acceptRefreshedSession(_ refreshedSession: WorkspaceSession) {
        guard let session,
              session.server.baseURL == refreshedSession.server.baseURL,
              session.username == refreshedSession.username
        else { return }
        self.session = refreshedSession
        try? sessionStore.save(refreshedSession)
    }

    private func startRealtime(session: WorkspaceSession) {
        realtimeTask?.cancel()
        realtimeTask = Task { [weak self] in
            guard let self else { return }
            let events = await realtimeClient.events(session: session)
            for await event in events {
                guard !Task.isCancelled else { break }
                apply(event)
            }
        }
    }

    private func activatePush(session: WorkspaceSession) {
        Task { [weak self] in
            guard let token = await WorkspacePushNotifications.shared.activate(), let self else { return }
            await pushRegistrationManager.register(token: token, session: session)
        }
    }

    private func apply(_ event: WorkspaceRealtimeEvent) {
        latestRealtimeEvent = event
        realtimeRevision &+= 1

        switch event {
        case .stream(let action, let stream):
            apply(action: action, value: stream, to: &streams)
        case .folder(let action, let folder):
            apply(action: action, value: folder, to: &folders)
        case .user(let action, let user) where user.id == currentUser?.id:
            currentUser = action == .deleted ? nil : user
            apply(action: action, value: user, to: &users)
        case .user(let action, let user):
            apply(action: action, value: user, to: &users)
        case .deletedFolder(let deleted):
            folders.removeAll { $0.id == deleted.uuid }
        case .deletedStream(let deleted):
            streams.removeAll { $0.id == deleted.uuid }
            folders = folders.map { folder in
                WorkspaceFolder(
                    uuid: folder.uuid,
                    title: folder.title,
                    unreadCount: folder.unreadCount,
                    systemType: folder.systemType,
                    createdAt: folder.createdAt,
                    items: folder.items.filter { $0.streamUUID != deleted.uuid }
                )
            }
        case .deletedUser(let deleted):
            if currentUser?.id == deleted.uuid { currentUser = nil }
            users.removeAll { $0.id == deleted.uuid }
        default:
            break
        }
    }

    private func apply<Value: Identifiable>(
        action: WorkspaceRealtimeAction,
        value: Value,
        to values: inout [Value]
    ) where Value.ID: Equatable {
        switch action {
        case .created:
            if !values.contains(where: { $0.id == value.id }) { values.append(value) }
        case .updated:
            if let index = values.firstIndex(where: { $0.id == value.id }) {
                values[index] = value
            }
        case .deleted:
            values.removeAll { $0.id == value.id }
        }
    }

    private func publicMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Что-то пошло не так. Попробуйте ещё раз"
    }
}
