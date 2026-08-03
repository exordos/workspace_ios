import Observation
import SwiftUI

struct WorkspaceBottomNavigation: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @Binding var selectedTab: WorkspaceTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(WorkspaceTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Group {
                        if tab == .profile {
                            profileIcon
                        } else {
                            Image(systemName: selectedTab == tab ? tab.selectedSystemImage : tab.systemImage)
                                .font(.system(size: 27, weight: .medium))
                                .symbolRenderingMode(.monochrome)
                        }
                    }
                    .foregroundStyle(selectedTab == tab ? Color.white : WorkspacePalette.mobileIcon)
                    .frame(width: 54, height: 54)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selectedTab == tab ? WorkspacePalette.mobileSelection : .clear)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 54)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                .accessibilityIdentifier("\(String(describing: tab))Tab")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 66)
        .background(WorkspacePalette.mobileNavigation)
        .background {
            WorkspacePalette.mobileNavigation
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WorkspacePalette.separator.opacity(0.55))
                .frame(height: 0.5)
        }
    }

    private var profileIcon: some View {
        Circle()
            .fill(selectedTab == .profile ? Color.white.opacity(0.20) : WorkspacePalette.mobileIcon.opacity(0.22))
            .frame(width: 36, height: 36)
            .overlay {
                Text(initials)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(selectedTab == .profile ? Color.white : WorkspacePalette.mobileIcon)
            }
    }

    private var initials: String {
        let name = appModel.currentUser?.displayName ?? appModel.session?.username ?? "W"
        return name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

enum WorkspaceActivityDestination: String, CaseIterable, Hashable, Identifiable {
    case inbox
    case starred
    case pinned
    case mentions
    case reactions
    case drafts
    case feed

    var id: Self { self }

    var title: String {
        switch self {
        case .inbox: "Входящие"
        case .starred: "Избранное"
        case .pinned: "Отмеченные сообщения"
        case .mentions: "Упоминания"
        case .reactions: "Реакции"
        case .drafts: "Черновики"
        case .feed: "Лента"
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: "tray.fill"
        case .starred: "star.fill"
        case .pinned: "bookmark.fill"
        case .mentions: "at"
        case .reactions: "hand.thumbsup.fill"
        case .drafts: "doc.text.fill"
        case .feed: "list.bullet.rectangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .inbox: Color(red: 0.52, green: 0.36, blue: 0.92)
        case .starred: Color(red: 0.22, green: 0.52, blue: 0.92)
        case .pinned: Color(red: 0.90, green: 0.28, blue: 0.31)
        case .mentions: Color(red: 0.93, green: 0.68, blue: 0.16)
        case .reactions: Color(red: 0.24, green: 0.65, blue: 0.40)
        case .drafts: Color(red: 0.83, green: 0.32, blue: 0.68)
        case .feed: WorkspacePalette.primary
        }
    }

    var messageFilter: WorkspaceMessageActivityFilter? {
        switch self {
        case .starred: .starred
        case .pinned: .pinned
        case .mentions: .mentioned
        case .feed: .feed
        default: nil
        }
    }
}

func filteredActivityDestinations(query: String) -> [WorkspaceActivityDestination] {
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return WorkspaceActivityDestination.allCases }
    return WorkspaceActivityDestination.allCases.filter {
        $0.title.localizedCaseInsensitiveContains(normalized)
    }
}

struct WorkspaceMyActivityView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @Binding var selectedFolderID: String?
    let onOpenMessenger: () -> Void
    @State private var searchText = ""
    @State private var showingCreateFolder = false
    @State private var newFolderName = ""

    private var destinations: [WorkspaceActivityDestination] {
        filteredActivityDestinations(query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceCompactSearchField(
                text: $searchText,
                prompt: "Найти",
                accessibilityLabel: "Поиск по моей активности"
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            WorkspaceFolderStrip(
                folders: appModel.folders,
                selectedFolderID: selectedFolderID,
                allUnreadCount: totalUnreadCount,
                onSelect: { folderID in
                    selectedFolderID = folderID
                },
                onAdd: { showingCreateFolder = true }
            )

            Divider().overlay(WorkspacePalette.separator)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if destinations.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.top, 48)
                    } else {
                        ForEach(destinations) { destination in
                            NavigationLink(value: destination) {
                                WorkspaceActivityRow(
                                    destination: destination,
                                    unreadCount: destination == .inbox ? totalUnreadCount : 0
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
        }
        .background(WorkspacePalette.background)
        .navigationTitle("Моя активность")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenMessenger) {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Открыть мессенджер")
                .accessibilityIdentifier("openMessengerButton")
            }
        }
        .navigationDestination(for: WorkspaceActivityDestination.self) { destination in
            WorkspaceActivityDetailView(destination: destination)
        }
        .alert("Новая папка", isPresented: $showingCreateFolder) {
            TextField("Название", text: $newFolderName)
            Button("Создать") {
                let title = newFolderName
                newFolderName = ""
                Task { await appModel.createFolder(title: title) }
            }
            Button("Отмена", role: .cancel) { newFolderName = "" }
        } message: {
            Text("Папка поможет сгруппировать каналы и личные чаты.")
        }
        .refreshable { await appModel.retryLoadingContent() }
    }

    private var totalUnreadCount: Int {
        appModel.streams.reduce(into: 0) { count, stream in
            count += max(0, stream.unreadCount)
        }
    }
}

private struct WorkspaceCompactSearchField: View {
    @Binding var text: String
    let prompt: String
    let accessibilityLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(WorkspacePalette.secondaryText)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(WorkspacePalette.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить поиск")
            }
        }
        .font(.system(size: 16))
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(WorkspacePalette.input, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct WorkspaceFolderStrip: View {
    let folders: [WorkspaceFolder]
    let selectedFolderID: String?
    let allUnreadCount: Int
    let onSelect: (String?) -> Void
    let onAdd: () -> Void

    private var visibleFolders: [WorkspaceFolder] {
        folders.filter {
            let title = $0.title.lowercased()
            return !title.contains("all chat") && !title.contains("все чат")
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                chip(title: "Все чаты", count: allUnreadCount, id: nil)
                ForEach(visibleFolders) { folder in
                    chip(title: localizedTitle(folder.title), count: folder.unreadCount, id: folder.id)
                }
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(WorkspacePalette.mobileIcon)
                        .frame(width: 38, height: 42)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Новая папка")
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 44)
    }

    private func chip(title: String, count: Int?, id: String?) -> some View {
        let selected = selectedFolderID == id
        return Button {
            onSelect(id)
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    Text(title)
                    if let count, count > 0 {
                        Text(count > 99 ? "99+" : String(count))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(WorkspacePalette.unreadBadge, in: Capsule())
                    }
                }
                .font(.system(size: 15, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? WorkspacePalette.text : WorkspacePalette.mobileIcon)
                Rectangle()
                    .fill(selected ? WorkspacePalette.text : .clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func localizedTitle(_ title: String) -> String {
        switch title.lowercased() {
        case "personal", "private", "личные чаты": "Личные"
        case "channels", "каналы": "Каналы"
        default: title
        }
    }
}

private struct WorkspaceActivityRow: View {
    let destination: WorkspaceActivityDestination
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(destination.tint)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: destination.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)
            Text(destination.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(WorkspacePalette.text)
                .lineLimit(1)
            Spacer(minLength: 8)
            if unreadCount > 0 {
                Text(unreadCount > 999 ? "999+" : String(unreadCount))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(minWidth: 26, minHeight: 26)
                    .background(WorkspacePalette.unreadBadge, in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 54)
        .background(WorkspacePalette.mobileCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        unreadCount > 0 ? "\(destination.title), непрочитанных: \(unreadCount)" : destination.title
    }
}

private struct WorkspaceActivityDetailView: View {
    let destination: WorkspaceActivityDestination

    @ViewBuilder
    var body: some View {
        switch destination {
        case .inbox:
            WorkspaceInboxView()
        case .reactions:
            WorkspaceActivityEmptyView(
                title: "Реакции",
                systemImage: "hand.thumbsup",
                message: "Реакции станут доступны после добавления backend API."
            )
        case .drafts:
            WorkspaceActivityEmptyView(
                title: "Черновики",
                systemImage: "doc.text",
                message: "Сохранённые черновики появятся здесь."
            )
        default:
            if let filter = destination.messageFilter {
                WorkspaceActivityTimelineView(destination: destination, filter: filter)
            }
        }
    }
}

private struct WorkspaceActivityEmptyView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WorkspacePalette.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WorkspaceInboxView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @State private var topicsByStream: [String: [WorkspaceTopic]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var unreadStreams: [WorkspaceStream] {
        appModel.streams.filter { stream in
            stream.unreadCount > 0 || topicsByStream[stream.id, default: []].contains { $0.unreadCount > 0 }
        }
    }

    var body: some View {
        Group {
            if isLoading, topicsByStream.isEmpty {
                ProgressView("Загружаем входящие…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if unreadStreams.isEmpty {
                ContentUnavailableView(
                    "Входящие разобраны",
                    systemImage: "checkmark.circle",
                    description: Text("Непрочитанных сообщений сейчас нет.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Text("КАНАЛЫ")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(WorkspacePalette.secondaryText)
                            Rectangle()
                                .fill(WorkspacePalette.separator)
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)

                        ForEach(unreadStreams) { stream in
                            WorkspaceInboxStreamCard(
                                stream: stream,
                                topics: topicsByStream[stream.id, default: []].filter { $0.unreadCount > 0 },
                                streamDestination: { destination(for: stream) },
                                topicDestination: { topic in conversation(stream: stream, topic: topic) }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(WorkspacePalette.background)
        .navigationTitle("Входящие")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Обновить входящие")
            }
        }
        .refreshable { await load() }
        .overlay(alignment: .bottom) {
            if let errorMessage {
                WorkspaceInlineError(message: errorMessage).padding()
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func destination(for stream: WorkspaceStream) -> some View {
        if let session = appModel.session {
            WorkspaceStreamDestinationView(
                api: appModel.workspaceAPI,
                session: session,
                stream: stream,
                currentUser: appModel.currentUser
            )
        }
    }

    @ViewBuilder
    private func conversation(stream: WorkspaceStream, topic: WorkspaceTopic) -> some View {
        if let session = appModel.session {
            WorkspaceConversationView(
                model: WorkspaceConversationModel(
                    api: appModel.workspaceAPI,
                    session: session,
                    stream: stream,
                    topic: topic,
                    currentUser: appModel.currentUser
                )
            )
        }
    }

    private func load() async {
        guard let session = appModel.session else { return }
        let api = appModel.workspaceAPI
        // A topic can remain unread while a provider reports a zero stream
        // counter, so inspect every stream just like the Android inbox model.
        let streams = appModel.streams
        isLoading = true
        errorMessage = nil
        var loaded: [String: [WorkspaceTopic]] = [:]

        await withTaskGroup(of: (String, [WorkspaceTopic]?).self) { group in
            for stream in streams {
                group.addTask {
                    let topics = try? await api.topics(session: session, streamUUID: stream.id)
                    return (stream.id, topics)
                }
            }
            for await (streamID, topics) in group {
                if let topics {
                    loaded[streamID] = topics
                }
            }
        }

        topicsByStream = loaded
        isLoading = false
        if loaded.count != streams.count {
            errorMessage = "Часть входящих пока не загрузилась. Потяните экран вниз, чтобы повторить."
        }
    }
}

private struct WorkspaceInboxStreamCard<StreamDestination: View, TopicDestination: View>: View {
    let stream: WorkspaceStream
    let topics: [WorkspaceTopic]
    @ViewBuilder let streamDestination: () -> StreamDestination
    @ViewBuilder let topicDestination: (WorkspaceTopic) -> TopicDestination

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink {
                streamDestination()
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(inboxColor(stream.color))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text(String(stream.name.prefix(1)).uppercased())
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    Text(stream.isPrivate ? stream.name : "#\(stream.name)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(WorkspacePalette.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    WorkspaceInboxBadge(count: stream.unreadCount)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 58)
            }
            .buttonStyle(.plain)

            if topics.isEmpty {
                Divider().padding(.leading, 58)
                Text("Непрочитанные сообщения канала")
                    .font(.system(size: 14))
                    .foregroundStyle(WorkspacePalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
            } else {
                ForEach(topics) { topic in
                    Divider().padding(.leading, 58)
                    NavigationLink {
                        topicDestination(topic)
                    } label: {
                        WorkspaceInboxTopicRow(topic: topic)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(WorkspacePalette.mobileCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(WorkspacePalette.separator, lineWidth: 1)
        }
    }
}

private struct WorkspaceInboxTopicRow: View {
    let topic: WorkspaceTopic

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(inboxColor(topic.color).opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(inboxColor(topic.color))
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(topic.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(WorkspacePalette.text)
                    .lineLimit(1)
                if !topicTime.isEmpty {
                    Text(topicTime)
                        .font(.system(size: 12))
                        .foregroundStyle(WorkspacePalette.secondaryText)
                }
            }
            Spacer(minLength: 8)
            WorkspaceInboxBadge(count: topic.unreadCount)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
    }

    private var topicTime: String {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let date = fractional.date(from: topic.updatedAt) ?? plain.date(from: topic.updatedAt) else {
            return ""
        }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct WorkspaceInboxBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : String(count))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(minWidth: 22, minHeight: 22)
                .background(WorkspacePalette.unreadBadge, in: Capsule())
        }
    }
}

private func inboxColor(_ value: Int) -> Color {
    Color(
        red: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255
    )
}

private struct WorkspaceActivityTimelineView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    let destination: WorkspaceActivityDestination
    let filter: WorkspaceMessageActivityFilter
    @State private var messages: [WorkspaceMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading, messages.isEmpty {
                ProgressView("Загружаем сообщения…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messages.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: destination.systemImage,
                    description: Text("Здесь появятся подходящие сообщения.")
                )
            } else {
                List(messages) { message in
                    if let stream = appModel.streams.first(where: { $0.id == message.streamUUID }) {
                        NavigationLink {
                            streamDestination(stream)
                        } label: {
                            WorkspaceActivityMessageRow(message: message, stream: stream)
                        }
                        .listRowBackground(WorkspacePalette.surface)
                    } else {
                        WorkspaceActivityMessageRow(message: message, stream: nil)
                            .listRowBackground(WorkspacePalette.surface)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(WorkspacePalette.background)
        .navigationTitle(destination.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .overlay(alignment: .bottom) {
            if let errorMessage {
                WorkspaceInlineError(message: errorMessage).padding()
            }
        }
        .task { await load() }
    }

    private var emptyTitle: String {
        switch destination {
        case .starred: "В избранном пока нет сообщений"
        case .pinned: "Отмеченных сообщений пока нет"
        case .mentions: "Упоминаний пока нет"
        default: "В ленте пока нет сообщений"
        }
    }

    @ViewBuilder
    private func streamDestination(_ stream: WorkspaceStream) -> some View {
        if let session = appModel.session {
            WorkspaceStreamDestinationView(
                api: appModel.workspaceAPI,
                session: session,
                stream: stream,
                currentUser: appModel.currentUser
            )
        }
    }

    private func load() async {
        guard let session = appModel.session else { return }
        isLoading = true
        errorMessage = nil
        do {
            messages = try await appModel.workspaceAPI.activityMessages(session: session, filter: filter)
        } catch {
            errorMessage = "Не удалось обновить \(destination.title.lowercased())."
        }
        isLoading = false
    }
}

private struct WorkspaceActivityMessageRow: View {
    let message: WorkspaceMessage
    let stream: WorkspaceStream?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(streamLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WorkspacePalette.primary)
                    .lineLimit(1)
                Spacer()
                Text(messageTime)
                    .font(.caption2)
                    .foregroundStyle(WorkspacePalette.secondaryText)
            }
            Text(authorLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WorkspacePalette.text)
                .lineLimit(1)
            Text(messageSummary)
                .font(.subheadline)
                .foregroundStyle(WorkspacePalette.secondaryText)
                .lineLimit(3)
        }
        .padding(.vertical, 5)
    }

    private var streamLabel: String {
        guard let stream else { return "Workspace" }
        return stream.isPrivate ? stream.name : "#\(stream.name)"
    }

    private var authorLabel: String {
        message.user?.displayName ?? "Сообщение"
    }

    private var messageSummary: String {
        message.payload.content
            .replacingOccurrences(of: #"\[(.*?)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var messageTime: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: message.createdAt) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

enum WorkspaceComingSoonDestination: Equatable {
    case calendar
    case mail

    var title: String { self == .calendar ? "Календарь" : "Почта" }
    var systemImage: String { self == .calendar ? "calendar" : "envelope.fill" }
    var description: String {
        self == .calendar
            ? "Готовим встречи и расписание в одном месте."
            : "Готовим удобную работу с письмами прямо в Workspace."
    }
}

struct WorkspaceComingSoonView: View {
    let destination: WorkspaceComingSoonDestination

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            ZStack {
                Circle()
                    .stroke(WorkspacePalette.primary.opacity(0.22), lineWidth: 1)
                    .frame(width: 160, height: 160)
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(WorkspacePalette.primary.opacity(0.13))
                    .frame(width: 112, height: 112)
                Image(systemName: destination.systemImage)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(WorkspacePalette.primary)
                    .accessibilityLabel(destination.title)
            }

            Text(destination.title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(WorkspacePalette.primary)
                .padding(.top, 32)
            Text("Уже скоро!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(WorkspacePalette.text)
                .padding(.top, 12)
            Text("В разработке!")
                .font(.title3.weight(.semibold))
                .foregroundStyle(WorkspacePalette.primary)
                .padding(.top, 6)
            Text(destination.description)
                .font(.body)
                .foregroundStyle(WorkspacePalette.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(WorkspacePalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 32)
                .padding(.top, 20)
            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkspacePalette.background)
        .navigationBarHidden(true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(destination == .calendar ? "calendarComingSoon" : "mailComingSoon")
    }
}
