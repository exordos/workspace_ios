import Observation
import SwiftUI

struct WorkspaceBottomNavigation: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @Binding var selectedTab: WorkspaceTab

    var body: some View {
        GeometryReader { geometry in
            let itemWidth = max(44, (geometry.size.width - 40) / 5)

            HStack(spacing: 4) {
                ForEach(WorkspaceTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Group {
                            if tab == .profile {
                                profileIcon
                            } else {
                                Image(systemName: selectedTab == tab ? tab.selectedSystemImage : tab.systemImage)
                                    .font(.system(size: 25, weight: .medium))
                            }
                        }
                        .foregroundStyle(selectedTab == tab ? WorkspacePalette.primary : WorkspacePalette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedTab == tab ? WorkspacePalette.surfaceRaised : .clear)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: itemWidth)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                    .accessibilityIdentifier("\(String(describing: tab))Tab")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .frame(height: 66)
        .background(WorkspacePalette.surface)
        .clipShape(.rect(topLeadingRadius: 14, topTrailingRadius: 14))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WorkspacePalette.separator.opacity(0.55))
                .frame(height: 0.5)
        }
        .shadow(color: .black.opacity(0.16), radius: 14, y: -2)
    }

    private var profileIcon: some View {
        Circle()
            .fill(WorkspacePalette.primary.opacity(selectedTab == .profile ? 0.24 : 0.12))
            .frame(width: 34, height: 34)
            .overlay {
                Text(initials)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(selectedTab == .profile ? WorkspacePalette.primary : WorkspacePalette.secondaryText)
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
            .padding(.vertical, 6)

            WorkspaceFolderStrip(
                folders: appModel.folders,
                selectedFolderID: selectedFolderID,
                onSelect: { folderID in
                    selectedFolderID = folderID
                    onOpenMessenger()
                },
                onAdd: { showingCreateFolder = true }
            )

            ScrollView {
                LazyVStack(spacing: 4) {
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
                .padding(.top, 6)
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
        .font(.system(size: 14))
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(WorkspacePalette.input, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct WorkspaceFolderStrip: View {
    let folders: [WorkspaceFolder]
    let selectedFolderID: String?
    let onSelect: (String?) -> Void
    let onAdd: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Все", count: nil, id: nil)
                ForEach(folders) { folder in
                    chip(title: folder.title, count: folder.unreadCount, id: folder.id)
                }
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(WorkspacePalette.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(WorkspacePalette.input, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Новая папка")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private func chip(title: String, count: Int?, id: String?) -> some View {
        let selected = selectedFolderID == id
        return Button {
            onSelect(id)
        } label: {
            HStack(spacing: 5) {
                Text(title)
                if let count, count > 0 {
                    Text(count > 99 ? "99+" : String(count))
                        .font(.caption2.bold())
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(selected ? Color.white : WorkspacePalette.text)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(selected ? WorkspacePalette.primary : WorkspacePalette.input, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct WorkspaceActivityRow: View {
    let destination: WorkspaceActivityDestination
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(destination.tint)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: destination.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)
            Text(destination.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(WorkspacePalette.text)
                .lineLimit(1)
            Spacer(minLength: 8)
            if unreadCount > 0 {
                Text(unreadCount > 999 ? "999+" : String(unreadCount))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(WorkspacePalette.primary, in: Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(WorkspacePalette.secondaryText.opacity(0.65))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 44)
        .background(WorkspacePalette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                List {
                    ForEach(unreadStreams) { stream in
                        Section(stream.isPrivate ? stream.name : "#\(stream.name)") {
                            let unreadTopics = topicsByStream[stream.id, default: []].filter { $0.unreadCount > 0 }
                            if unreadTopics.isEmpty {
                                NavigationLink {
                                    destination(for: stream)
                                } label: {
                                    WorkspaceInboxRow(title: stream.name, unreadCount: stream.unreadCount)
                                }
                            } else {
                                ForEach(unreadTopics) { topic in
                                    NavigationLink {
                                        conversation(stream: stream, topic: topic)
                                    } label: {
                                        WorkspaceInboxRow(title: topic.name, unreadCount: topic.unreadCount)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(WorkspacePalette.background)
        .navigationTitle("Входящие")
        .navigationBarTitleDisplayMode(.inline)
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

private struct WorkspaceInboxRow: View {
    let title: String
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(WorkspacePalette.primary.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(WorkspacePalette.primary)
                }
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(WorkspacePalette.text)
                .lineLimit(2)
            Spacer()
            Text(unreadCount > 99 ? "99+" : String(max(0, unreadCount)))
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(minHeight: 24)
                .background(WorkspacePalette.primary, in: Capsule())
        }
        .padding(.vertical, 3)
    }
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
