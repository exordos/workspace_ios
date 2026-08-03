import Foundation
import Observation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class WorkspaceTopicListModel {
    let stream: WorkspaceStream
    private let api: WorkspaceAPI
    private let session: WorkspaceSession

    private(set) var topics: [WorkspaceTopic] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private var didLoad = false

    init(api: WorkspaceAPI, session: WorkspaceSession, stream: WorkspaceStream) {
        self.api = api
        self.session = session
        self.stream = stream
    }

    func load(force: Bool = false) async {
        guard !isLoading, force || !didLoad else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            topics = try await api.topics(session: session, streamUUID: stream.id)
                .sorted { lhs, rhs in
                    if lhs.unreadCount != rhs.unreadCount { return lhs.unreadCount > rhs.unreadCount }
                    return lhs.updatedAt > rhs.updatedAt
                }
            didLoad = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Не удалось загрузить темы"
        }
    }

    func apply(_ event: WorkspaceRealtimeEvent?) {
        if case .deletedTopic(let deleted) = event,
           deleted.streamUUID == nil || deleted.streamUUID == stream.id {
            topics.removeAll { $0.id == deleted.uuid }
            return
        }
        guard case .topic(let action, let topic) = event,
              topic.streamUUID == stream.id
        else { return }

        switch action {
        case .created:
            if !topics.contains(where: { $0.id == topic.id }) { topics.append(topic) }
        case .updated:
            if let index = topics.firstIndex(where: { $0.id == topic.id }) { topics[index] = topic }
        case .deleted:
            topics.removeAll { $0.id == topic.id }
        }
    }
}

nonisolated struct WorkspacePendingAttachment: Equatable, Sendable {
    let data: Data
    let filename: String
    let mimeType: String
}

@MainActor
@Observable
final class WorkspaceConversationModel {
    let stream: WorkspaceStream
    let topic: WorkspaceTopic
    let session: WorkspaceSession
    let currentUser: WorkspaceUser?
    let api: WorkspaceAPI

    private(set) var messages: [WorkspaceMessage] = []
    private(set) var myReactions: [WorkspaceMessageReaction] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var errorMessage: String?
    private(set) var editingMessage: WorkspaceMessage?
    private(set) var quotedMessage: WorkspaceMessage?
    private(set) var pendingAttachment: WorkspacePendingAttachment?
    var draft = ""

    private var didLoad = false

    init(
        api: WorkspaceAPI,
        session: WorkspaceSession,
        stream: WorkspaceStream,
        topic: WorkspaceTopic,
        currentUser: WorkspaceUser?
    ) {
        self.api = api
        self.session = session
        self.stream = stream
        self.topic = topic
        self.currentUser = currentUser
    }

    func load(force: Bool = false) async {
        guard !isLoading, force || !didLoad else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            messages = try await api.messages(
                session: session,
                streamUUID: stream.id,
                topicUUID: topic.id
            ).sorted { $0.createdAt < $1.createdAt }
            didLoad = true

            if let currentUser {
                myReactions = (try? await api.reactions(session: session, userUUID: currentUser.id)) ?? []
            }
            if let lastMessage = messages.last {
                _ = try? await api.markRead(session: session, messageUUID: lastMessage.id)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Не удалось загрузить сообщения"
        }
    }

    func startEditing(_ message: WorkspaceMessage) {
        guard message.isOwn else { return }
        quotedMessage = nil
        editingMessage = message
        pendingAttachment = nil
        draft = message.payload.content
    }

    func quote(_ message: WorkspaceMessage) {
        editingMessage = nil
        quotedMessage = message
    }

    func cancelContext() {
        editingMessage = nil
        quotedMessage = nil
        pendingAttachment = nil
        draft = ""
    }

    func setAttachment(_ attachment: WorkspacePendingAttachment?) {
        pendingAttachment = attachment
    }

    func send() async {
        guard !isSending else { return }
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty || pendingAttachment != nil else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        if let editingMessage {
            await edit(editingMessage, content: draft)
            return
        }

        let originalDraft = draft
        let originalQuote = quotedMessage
        let originalAttachment = pendingAttachment

        do {
            var content = ""
            if let quotedMessage = originalQuote {
                let authorName = quotedMessage.user?.displayName ?? quotedMessage.authorUUID
                content += "[\(authorName)](urn:user:\(quotedMessage.authorUUID)) [said](urn:message:\(quotedMessage.id))\n```quote\n\(quotedMessage.payload.content)\n```\n"
            }
            if !trimmedDraft.isEmpty { content += trimmedDraft }

            if let attachment = originalAttachment {
                let upload = try await api.uploadFile(
                    session: session,
                    streamUUID: stream.id,
                    data: attachment.data,
                    filename: attachment.filename,
                    mimeType: attachment.mimeType
                )
                if !content.isEmpty { content += "\n" }
                content += "[\(upload.name)](urn:image:\(upload.uuid))"
            }

            let temporaryID = "local-\(UUID().uuidString)"
            let now = ISO8601DateFormatter().string(from: Date())
            let optimistic = WorkspaceMessage(
                uuid: temporaryID,
                updatedAt: now,
                createdAt: now,
                streamUUID: stream.id,
                topicUUID: topic.id,
                userUUID: currentUser?.id ?? "",
                authorUUID: currentUser?.id ?? "",
                payload: WorkspaceMessagePayload(kind: "markdown", content: content),
                isOwn: true,
                reactions: [:],
                user: currentUser
            )
            messages.append(optimistic)
            draft = ""
            quotedMessage = nil
            pendingAttachment = nil

            do {
                let response = try await api.sendMessage(
                    session: session,
                    streamUUID: stream.id,
                    topicUUID: topic.id,
                    content: content
                )
                if let index = messages.firstIndex(where: { $0.id == temporaryID }) {
                    messages[index] = optimistic.replacingIdentifiers(
                        uuid: response.uuid,
                        topicUUID: response.topicUUID
                    )
                }
            } catch {
                messages.removeAll { $0.id == temporaryID }
                throw error
            }
        } catch {
            draft = originalDraft
            quotedMessage = originalQuote
            pendingAttachment = originalAttachment
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Сообщение не отправлено"
        }
    }

    func startCall() async -> WorkspaceCall? {
        guard !isSending, let serverURL = session.server.meetURL else {
            if session.server.meetURL == nil { errorMessage = "Сервис звонков не настроен" }
            return nil
        }

        let call = WorkspaceCall(
            serverURL: serverURL,
            room: WorkspaceCallRoomNameGenerator.generate()
        )
        guard let invitationURL = call.invitationURL else {
            errorMessage = "Не удалось создать ссылку звонка"
            return nil
        }

        isSending = true
        errorMessage = nil
        defer { isSending = false }

        let temporaryID = "local-\(UUID().uuidString)"
        let now = ISO8601DateFormatter().string(from: Date())
        let optimistic = WorkspaceMessage(
            uuid: temporaryID,
            updatedAt: now,
            createdAt: now,
            streamUUID: stream.id,
            topicUUID: topic.id,
            userUUID: currentUser?.id ?? "",
            authorUUID: currentUser?.id ?? "",
            payload: WorkspaceMessagePayload(kind: "markdown", content: invitationURL.absoluteString),
            isOwn: true,
            reactions: [:],
            user: currentUser
        )
        messages.append(optimistic)

        do {
            let response = try await api.sendMessage(
                session: session,
                streamUUID: stream.id,
                topicUUID: topic.id,
                content: invitationURL.absoluteString
            )
            if let index = messages.firstIndex(where: { $0.id == temporaryID }) {
                messages[index] = optimistic.replacingIdentifiers(
                    uuid: response.uuid,
                    topicUUID: response.topicUUID
                )
            }
            return call
        } catch {
            messages.removeAll { $0.id == temporaryID }
            errorMessage = "Не удалось начать звонок"
            return nil
        }
    }

    func toggleReaction(message: WorkspaceMessage, emoji: String) async {
        guard !message.id.hasPrefix("local-") else { return }
        do {
            if let existing = myReactions.first(where: {
                $0.messageUUID == message.id && $0.emojiName == emoji
            }) {
                try await api.removeReaction(session: session, reactionUUID: existing.id)
                myReactions.removeAll { $0.id == existing.id }
                updateReactionCount(messageID: message.id, emoji: emoji, delta: -1)
            } else {
                let reaction = try await api.addReaction(
                    session: session,
                    messageUUID: message.id,
                    emoji: emoji
                )
                myReactions.append(reaction)
                updateReactionCount(messageID: message.id, emoji: emoji, delta: 1)
            }
        } catch {
            errorMessage = "Не удалось изменить реакцию"
        }
    }

    func hasMyReaction(messageID: String, emoji: String) -> Bool {
        myReactions.contains { $0.messageUUID == messageID && $0.emojiName == emoji }
    }

    func apply(_ event: WorkspaceRealtimeEvent?) {
        switch event {
        case .message(let action, let message)
            where message.streamUUID == stream.id && message.topicUUID == topic.id:
            applyMessage(action: action, message: message)
        case .reaction(let action, let reaction):
            guard messages.contains(where: { $0.id == reaction.messageUUID }) else { return }
            if action == .created {
                if reaction.userUUID == currentUser?.id,
                   !myReactions.contains(where: { $0.id == reaction.id }) {
                    myReactions.append(reaction)
                }
                updateReactionCount(messageID: reaction.messageUUID, emoji: reaction.emojiName, delta: 1)
            }
        case .deletedReaction(let deleted):
            guard let reaction = myReactions.first(where: { $0.id == deleted.uuid }) else { return }
            myReactions.removeAll { $0.id == deleted.uuid }
            updateReactionCount(messageID: reaction.messageUUID, emoji: reaction.emojiName, delta: -1)
        case .deletedMessage(let deleted):
            guard deleted.streamUUID == nil || deleted.streamUUID == stream.id else { return }
            guard deleted.topicUUID == nil || deleted.topicUUID == topic.id else { return }
            messages.removeAll { $0.id == deleted.uuid }
        default:
            break
        }
    }

    private func edit(_ message: WorkspaceMessage, content: String) async {
        do {
            _ = try await api.editMessage(
                session: session,
                messageUUID: message.id,
                content: content
            )
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].payload.content = content
            }
            draft = ""
            editingMessage = nil
        } catch {
            errorMessage = "Изменения не сохранены"
        }
    }

    private func updateReactionCount(messageID: String, emoji: String, delta: Int) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        let nextCount = max(0, (messages[index].reactions[emoji] ?? 0) + delta)
        if nextCount == 0 {
            messages[index].reactions.removeValue(forKey: emoji)
        } else {
            messages[index].reactions[emoji] = nextCount
        }
    }

    private func applyMessage(action: WorkspaceRealtimeAction, message: WorkspaceMessage) {
        switch action {
        case .created:
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = message
            } else {
                messages.append(message)
                messages.sort { $0.createdAt < $1.createdAt }
            }
        case .updated:
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                let preservedUser = message.user ?? messages[index].user
                messages[index] = WorkspaceMessage(
                    uuid: message.uuid,
                    updatedAt: message.updatedAt,
                    createdAt: message.createdAt,
                    streamUUID: message.streamUUID,
                    topicUUID: message.topicUUID,
                    userUUID: message.userUUID,
                    authorUUID: message.authorUUID,
                    payload: message.payload,
                    isOwn: message.isOwn,
                    reactions: message.reactions,
                    user: preservedUser
                )
            }
        case .deleted:
            messages.removeAll { $0.id == message.id }
        }
    }
}

private nonisolated extension WorkspaceMessage {
    func replacingIdentifiers(uuid: String, topicUUID: String) -> WorkspaceMessage {
        WorkspaceMessage(
            uuid: uuid,
            updatedAt: updatedAt,
            createdAt: createdAt,
            streamUUID: streamUUID,
            topicUUID: topicUUID,
            userUUID: userUUID,
            authorUUID: authorUUID,
            payload: payload,
            isOwn: isOwn,
            reactions: reactions,
            user: user
        )
    }
}

struct WorkspaceStreamDestinationView: View {
    let api: WorkspaceAPI
    let session: WorkspaceSession
    let stream: WorkspaceStream
    let currentUser: WorkspaceUser?

    var body: some View {
        if stream.isPrivate, let topicUUID = stream.defaultTopicUUID {
            WorkspaceConversationView(
                model: WorkspaceConversationModel(
                    api: api,
                    session: session,
                    stream: stream,
                    topic: WorkspaceTopic(
                        uuid: topicUUID,
                        name: stream.name,
                        color: stream.color,
                        streamUUID: stream.id,
                        updatedAt: stream.updatedAt,
                        unreadCount: stream.unreadCount,
                        isDone: false,
                        isDefault: true,
                        lastMessageUUID: stream.lastMessageUUID
                    ),
                    currentUser: currentUser
                )
            )
        } else {
            WorkspaceTopicListView(
                model: WorkspaceTopicListModel(api: api, session: session, stream: stream),
                api: api,
                session: session,
                currentUser: currentUser
            )
        }
    }
}

private struct WorkspaceTopicListView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @State var model: WorkspaceTopicListModel
    let api: WorkspaceAPI
    let session: WorkspaceSession
    let currentUser: WorkspaceUser?

    var body: some View {
        List {
            if model.isLoading, model.topics.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(WorkspacePalette.background)
            } else if model.topics.isEmpty {
                ContentUnavailableView(
                    "Тем пока нет",
                    systemImage: "text.bubble",
                    description: Text("Новые темы появятся здесь.")
                )
                .listRowBackground(WorkspacePalette.background)
            } else {
                ForEach(model.topics) { topic in
                    NavigationLink(value: topic) {
                        WorkspaceTopicRow(topic: topic)
                    }
                    .listRowBackground(WorkspacePalette.surface)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(WorkspacePalette.background)
        .navigationTitle(model.stream.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    WorkspaceStreamInfoView(
                        api: api,
                        session: session,
                        stream: model.stream
                    )
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("Информация о канале")
            }
        }
        .refreshable { await model.load(force: true) }
        .navigationDestination(for: WorkspaceTopic.self) { topic in
            WorkspaceConversationView(
                model: WorkspaceConversationModel(
                    api: api,
                    session: session,
                    stream: model.stream,
                    topic: topic,
                    currentUser: currentUser
                )
            )
        }
        .overlay(alignment: .bottom) {
            if let errorMessage = model.errorMessage {
                WorkspaceInlineError(message: errorMessage).padding()
            }
        }
        .task { await model.load() }
        .onChange(of: appModel.realtimeRevision) { _, _ in
            model.apply(appModel.latestRealtimeEvent)
        }
    }
}

private struct WorkspaceTopicRow: View {
    let topic: WorkspaceTopic

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(topicColor)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(topic.name)
                        .font(.body.weight(topic.unreadCount > 0 ? .semibold : .regular))
                        .foregroundStyle(WorkspacePalette.text)
                        .lineLimit(1)
                    if topic.isDone {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(WorkspacePalette.online)
                            .accessibilityLabel("Тема завершена")
                    }
                }
                Text(topic.isDefault ? "Основная тема" : "Обсуждение")
                    .font(.caption)
                    .foregroundStyle(WorkspacePalette.secondaryText)
            }
            Spacer()
            if topic.unreadCount > 0 {
                Text(topic.unreadCount > 99 ? "99+" : String(topic.unreadCount))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 24)
                    .background(WorkspacePalette.primary, in: Capsule())
            }
        }
        .padding(.vertical, 5)
    }

    private var topicColor: Color {
        Color(
            red: Double((topic.color >> 16) & 0xFF) / 255,
            green: Double((topic.color >> 8) & 0xFF) / 255,
            blue: Double(topic.color & 0xFF) / 255
        )
    }
}

struct WorkspaceConversationView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @State var model: WorkspaceConversationModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var activeCall: WorkspaceCall?
    @FocusState private var composerFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if model.isLoading, model.messages.isEmpty {
                        ProgressView().padding(.top, 40)
                    } else if model.messages.isEmpty {
                        ContentUnavailableView(
                            "Сообщений пока нет",
                            systemImage: "bubble.left",
                            description: Text("Начните обсуждение первым.")
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(model.messages) { message in
                            WorkspaceMessageBubble(
                                model: model,
                                message: message,
                                onJoinCall: { activeCall = $0 }
                            )
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(WorkspacePalette.background)
            .onChange(of: model.messages.count) { _, _ in
                guard let id = model.messages.last?.id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .bottom) }
            }
            .task {
                await model.load()
                if let id = model.messages.last?.id {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
        .navigationTitle(model.topic.isDefault ? model.stream.name : model.topic.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    WorkspaceStreamInfoView(
                        api: model.api,
                        session: model.session,
                        stream: model.stream
                    )
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel(model.stream.isPrivate ? "Информация о собеседнике" : "Информация о канале")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        if let call = await model.startCall() { activeCall = call }
                    }
                } label: {
                    Image(systemName: "phone.fill")
                        .foregroundStyle(WorkspacePalette.online)
                }
                .disabled(model.isSending || model.session.server.meetURL == nil)
                .accessibilityLabel("Начать звонок")
                .accessibilityIdentifier("startCallButton")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            WorkspaceMessageComposer(
                model: model,
                selectedPhoto: $selectedPhoto,
                composerFocused: $composerFocused
            )
        }
        .overlay(alignment: .top) {
            if let errorMessage = model.errorMessage {
                WorkspaceInlineError(message: errorMessage)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
        }
        .onChange(of: appModel.realtimeRevision) { _, _ in
            model.apply(appModel.latestRealtimeEvent)
        }
        .fullScreenCover(item: $activeCall) { call in
            WorkspaceCallScreen(call: call) { activeCall = nil }
                .ignoresSafeArea()
        }
    }
}

private struct WorkspaceMessageBubble: View {
    let model: WorkspaceConversationModel
    let message: WorkspaceMessage
    let onJoinCall: (WorkspaceCall) -> Void

    private var parsed: WorkspaceAttachmentParser.Result {
        WorkspaceAttachmentParser.parse(message.payload.content)
    }

    private var call: WorkspaceCall? {
        WorkspaceCall.parse(message.payload.content, meetURL: model.session.server.meetURL)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isOwn { Spacer(minLength: 48) }

            if !message.isOwn {
                Circle()
                    .fill(WorkspacePalette.primary.opacity(0.16))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Text(String(senderName.prefix(1)).uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(WorkspacePalette.primary)
                    }
                    .accessibilityHidden(true)
            }

            VStack(alignment: message.isOwn ? .trailing : .leading, spacing: 4) {
                if !message.isOwn {
                    Text(senderName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WorkspacePalette.secondaryText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    if let call {
                        Button {
                            onJoinCall(call)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "phone.fill")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Звонок").font(.subheadline.bold())
                                    Text(call.room)
                                        .font(.caption)
                                        .foregroundStyle(WorkspacePalette.text)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.up.right")
                            }
                            .foregroundStyle(WorkspacePalette.online)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Присоединиться к звонку \(call.room)")
                    } else if !parsed.caption.isEmpty {
                        WorkspaceMarkdownText(markdown: parsed.caption)
                    }
                    if call == nil {
                        ForEach(parsed.attachments) { attachment in
                            WorkspaceAuthorizedImage(
                                api: model.api,
                                session: model.session,
                                attachment: attachment
                            )
                        }
                    }
                    HStack(spacing: 5) {
                        Spacer(minLength: 0)
                        Text(messageTime)
                            .font(.caption2)
                            .foregroundStyle(WorkspacePalette.secondaryText)
                        if message.isOwn {
                            Image(systemName: message.id.hasPrefix("local-") ? "clock" : "checkmark")
                                .font(.caption2)
                                .foregroundStyle(WorkspacePalette.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    message.isOwn ? WorkspacePalette.primary.opacity(0.16) : WorkspacePalette.surface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .contextMenu {
                    Button {
                        model.quote(message)
                    } label: {
                        Label("Цитировать", systemImage: "quote.bubble")
                    }
                    if message.isOwn {
                        Button {
                            model.startEditing(message)
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }
                    }
                    Divider()
                    ForEach(["👍", "❤️", "😂"], id: \.self) { emoji in
                        Button(emoji) {
                            Task { await model.toggleReaction(message: message, emoji: emoji) }
                        }
                    }
                }

                if !message.reactions.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(message.reactions.keys.sorted(), id: \.self) { emoji in
                            let selected = model.hasMyReaction(messageID: message.id, emoji: emoji)
                            Button {
                                Task { await model.toggleReaction(message: message, emoji: emoji) }
                            } label: {
                                HStack(spacing: 3) {
                                    Text(emoji)
                                    if let count = message.reactions[emoji], count > 1 {
                                        Text(String(count)).font(.caption2)
                                    }
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(selected ? WorkspacePalette.primary.opacity(0.16) : WorkspacePalette.surface, in: Capsule())
                                .overlay {
                                    Capsule().stroke(selected ? WorkspacePalette.primary : WorkspacePalette.separator)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !message.isOwn { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity)
    }

    private var senderName: String {
        message.user?.displayName ?? (message.isOwn ? "Вы" : "Участник")
    }

    private var messageTime: String {
        guard let date = ISO8601DateFormatter().date(from: message.createdAt) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct WorkspaceCallScreen: View {
    let call: WorkspaceCall
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
            JitsiMeetViewWrapper(
                serverURL: call.serverURL,
                room: call.room,
                readyToClose: close
            )
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.6), in: Circle())
            }
            .padding(.top, 12)
            .padding(.trailing, 12)
            .accessibilityLabel("Закрыть звонок")
        }
    }
}

private struct WorkspaceMessageComposer: View {
    let model: WorkspaceConversationModel
    @Binding var selectedPhoto: PhotosPickerItem?
    var composerFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 0) {
            if let editingMessage = model.editingMessage {
                contextBanner(icon: "pencil", title: "Редактирование", body: editingMessage.payload.content)
            } else if let quotedMessage = model.quotedMessage {
                contextBanner(icon: "quote.bubble", title: "Цитата", body: quotedMessage.payload.content)
            }
            if let attachment = model.pendingAttachment {
                HStack {
                    Label(attachment.filename, systemImage: "photo")
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        model.setAttachment(nil)
                        selectedPhoto = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
                .foregroundStyle(WorkspacePalette.secondaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(WorkspacePalette.surface)
            }

            HStack(alignment: .bottom, spacing: 8) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "paperclip")
                        .frame(width: 34, height: 34)
                }
                .disabled(model.isSending || model.editingMessage != nil)
                .accessibilityLabel("Прикрепить изображение")

                TextField("Сообщение", text: Bindable(model).draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused(composerFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(WorkspacePalette.input, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityIdentifier("messageComposer")

                Button {
                    Task { await model.send() }
                } label: {
                    Group {
                        if model.isSending {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(WorkspacePalette.primary, in: Circle())
                }
                .disabled(
                    model.isSending ||
                    (model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.pendingAttachment == nil)
                )
                .accessibilityLabel(model.editingMessage == nil ? "Отправить" : "Сохранить")
                .accessibilityIdentifier("sendMessageButton")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                let type = item.supportedContentTypes.first ?? .jpeg
                let extensionName = type.preferredFilenameExtension ?? "jpg"
                model.setAttachment(
                    WorkspacePendingAttachment(
                        data: data,
                        filename: "image.\(extensionName)",
                        mimeType: type.preferredMIMEType ?? "image/jpeg"
                    )
                )
            }
        }
    }

    private func contextBanner(icon: String, title: String, body: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(WorkspacePalette.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.bold())
                Text(body).font(.caption).lineLimit(1)
            }
            Spacer()
            Button {
                model.cancelContext()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .accessibilityLabel("Отменить")
        }
        .foregroundStyle(WorkspacePalette.secondaryText)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(WorkspacePalette.surface)
    }
}

private struct WorkspaceMarkdownText: View {
    let markdown: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: markdown) {
            Text(attributed)
                .font(.body)
                .foregroundStyle(WorkspacePalette.text)
                .textSelection(.enabled)
        } else {
            Text(markdown)
                .font(.body)
                .foregroundStyle(WorkspacePalette.text)
                .textSelection(.enabled)
        }
    }
}

private struct WorkspaceAuthorizedImage: View {
    let api: WorkspaceAPI
    let session: WorkspaceSession
    let attachment: WorkspaceMessageAttachment
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if failed {
                Label(attachment.filename, systemImage: "photo.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(WorkspacePalette.secondaryText)
            } else {
                HStack {
                    ProgressView()
                    Text(attachment.filename).font(.caption).lineLimit(1)
                }
                .foregroundStyle(WorkspacePalette.secondaryText)
            }
        }
        .task(id: attachment.fileUUID) {
            do {
                let data = try await api.fileData(session: session, fileUUID: attachment.fileUUID)
                image = UIImage(data: data)
                failed = image == nil
            } catch {
                failed = true
            }
        }
        .accessibilityLabel("Изображение \(attachment.filename)")
    }
}

nonisolated struct WorkspaceMessageAttachment: Equatable, Identifiable, Sendable {
    let filename: String
    let fileUUID: String

    var id: String { fileUUID }
}

nonisolated enum WorkspaceAttachmentParser {
    nonisolated struct Result: Equatable, Sendable {
        let caption: String
        let attachments: [WorkspaceMessageAttachment]
    }

    static func parse(_ markdown: String) -> Result {
        let pattern = #"!?\[([^\]]*)\]\((urn:image:[^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Result(caption: markdown, attachments: [])
        }
        let fullRange = NSRange(markdown.startIndex..., in: markdown)
        let matches = regex.matches(in: markdown, range: fullRange)
        let attachments = matches.compactMap { match -> WorkspaceMessageAttachment? in
            guard let filenameRange = Range(match.range(at: 1), in: markdown),
                  let urnRange = Range(match.range(at: 2), in: markdown)
            else { return nil }
            return WorkspaceMessageAttachment(
                filename: String(markdown[filenameRange]),
                fileUUID: String(markdown[urnRange]).replacingOccurrences(of: "urn:image:", with: "")
            )
        }
        let caption = regex.stringByReplacingMatches(
            in: markdown,
            range: fullRange,
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return Result(caption: caption, attachments: attachments)
    }
}
