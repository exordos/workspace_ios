import SwiftUI

struct WorkspaceMainView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @State private var selectedTab = WorkspaceTab.activity
    @State private var chatPath = NavigationPath()
    @State private var selectedFolderID: String?

    var body: some View {
        selectedContent
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectedTab != .messenger || chatPath.isEmpty {
                WorkspaceBottomNavigation(selectedTab: $selectedTab)
            }
        }
        .background(WorkspacePalette.background)
        .tint(WorkspacePalette.text)
        .task(id: WorkspacePushNavigationKey(
            phase: appModel.phase,
            revision: appModel.pushRouteRevision
        )) {
            await openPendingPushRoute()
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .activity:
            NavigationStack {
                WorkspaceMyActivityView(
                    selectedFolderID: $selectedFolderID,
                    onOpenMessenger: { selectedTab = .messenger }
                )
            }
        case .messenger:
            NavigationStack(path: $chatPath) {
                WorkspaceMessengerView(selectedFolderID: $selectedFolderID)
            }
        case .calendar:
            NavigationStack {
                WorkspaceComingSoonView(destination: .calendar)
            }
        case .mail:
            NavigationStack {
                WorkspaceComingSoonView(destination: .mail)
            }
        case .profile:
            NavigationStack {
                WorkspaceProfileView()
            }
        }
    }

    private func openPendingPushRoute() async {
        guard appModel.phase == .signedIn,
              let route = appModel.pendingPushRoute,
              let session = appModel.session
        else { return }

        switch route {
        case .direct(let userUUID):
            var stream = appModel.streams.first { $0.directUserUUID == userUUID }
            if stream == nil, let user = appModel.users.first(where: { $0.id == userUUID }) {
                stream = try? await appModel.createDirectChat(with: user)
            }
            if let stream {
                selectedTab = .messenger
                chatPath = NavigationPath()
                chatPath.append(stream)
            }
        case .topic(let streamIdentifier, let topicIdentifier):
            guard let stream = appModel.streams.first(where: {
                $0.id == streamIdentifier || $0.name == streamIdentifier
            }) else { break }

            let topics = try? await appModel.workspaceAPI.topics(
                session: session,
                streamUUID: stream.id
            )
            selectedTab = .messenger
            chatPath = NavigationPath()
            if let topic = topics?.first(where: {
                $0.id == topicIdentifier || $0.name == topicIdentifier
            }) {
                chatPath.append(WorkspacePushConversationDestination(stream: stream, topic: topic))
            } else {
                chatPath.append(stream)
            }
        }
        appModel.consumePendingPushRoute()
    }
}

enum WorkspaceTab: CaseIterable, Hashable {
    case activity
    case messenger
    case calendar
    case mail
    case profile

    var title: String {
        switch self {
        case .activity: "Моя активность"
        case .messenger: "Мессенджер"
        case .calendar: "Календарь"
        case .mail: "Почта"
        case .profile: "Профиль"
        }
    }

    var assetName: String? {
        switch self {
        case .activity: "workspaceActivityTab"
        case .messenger: "workspaceMessengerTab"
        case .calendar: "workspaceCalendarTab"
        case .mail: "workspaceMailTab"
        case .profile: nil
        }
    }

    var iconSize: CGSize {
        switch self {
        case .activity: CGSize(width: 21, height: 24)
        case .messenger: CGSize(width: 27, height: 24)
        case .calendar: CGSize(width: 24, height: 27)
        case .mail: CGSize(width: 27, height: 21)
        case .profile: CGSize(width: 36, height: 36)
        }
    }
}

private struct WorkspacePushNavigationKey: Hashable {
    let phase: WorkspaceAppPhase
    let revision: Int
}

private struct WorkspacePushConversationDestination: Hashable {
    let stream: WorkspaceStream
    let topic: WorkspaceTopic
}

private struct WorkspaceMessengerView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @Binding var selectedFolderID: String?
    @State private var selectedStreamID: String?
    @State private var searchText = ""
    @State private var topics: [WorkspaceTopic] = []
    @State private var bindings: [WorkspaceStreamBinding] = []
    @State private var loadingStreamID: String?
    @State private var errorMessage: String?
    @State private var showingNewChat = false
    @State private var showingCreateFolder = false
    @State private var newFolderName = ""

    private var filteredStreams: [WorkspaceStream] {
        var result = appModel.streams
        if let selectedFolderID,
           let folder = appModel.folders.first(where: { $0.id == selectedFolderID }) {
            let streamIDs = Set(folder.items.map(\.streamUUID))
            result = result.filter { streamIDs.contains($0.id) }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                    $0.description?.localizedCaseInsensitiveContains(query) == true
            }
        }
        return result
    }

    private var selectedStream: WorkspaceStream? {
        filteredStreams.first { $0.id == selectedStreamID } ?? filteredStreams.first
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceMessengerHeader(
                title: selectedStream?.name ?? "Мессенджер",
                subtitle: streamSubtitle,
                onCompose: { showingNewChat = true }
            )

            WorkspaceMessengerSearchField(text: $searchText)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            WorkspaceMessengerFolderTabs(
                folders: appModel.folders,
                selectedFolderID: selectedFolderID,
                allUnreadCount: totalUnreadCount,
                onSelect: { selectedFolderID = $0 },
                onAdd: { showingCreateFolder = true }
            )

            Divider().overlay(WorkspacePalette.separator)

            if filteredStreams.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    WorkspaceStreamRail(
                        streams: filteredStreams,
                        selectedStreamID: selectedStream?.id,
                        onSelect: { selectedStreamID = $0.id }
                    )
                    .frame(width: 72)

                    Divider().overlay(WorkspacePalette.separator)

                    if let selectedStream {
                        WorkspaceMessengerTopics(
                            stream: selectedStream,
                            topics: topics,
                            isLoading: loadingStreamID == selectedStream.id,
                            errorMessage: errorMessage
                        )
                        .id(selectedStream.id)
                    }
                }
            }
        }
        .background(WorkspacePalette.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: WorkspaceStream.self) { stream in
            if let session = appModel.session {
                WorkspaceStreamDestinationView(
                    api: appModel.workspaceAPI,
                    session: session,
                    stream: stream,
                    currentUser: appModel.currentUser
                )
            }
        }
        .navigationDestination(for: WorkspacePushConversationDestination.self) { destination in
            if let session = appModel.session {
                WorkspaceConversationView(
                    model: WorkspaceConversationModel(
                        api: appModel.workspaceAPI,
                        session: session,
                        stream: destination.stream,
                        topic: destination.topic,
                        currentUser: appModel.currentUser
                    )
                )
            }
        }
        .sheet(isPresented: $showingNewChat) {
            WorkspaceNewChatView()
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
        .task {
            guard let session = appModel.session else { return }
            bindings = (try? await appModel.workspaceAPI.streamBindings(session: session)) ?? []
        }
        .task(id: selectedStream?.id) {
            await loadTopics(for: selectedStream)
        }
        .onAppear {
            if selectedStreamID == nil { selectedStreamID = filteredStreams.first?.id }
        }
        .onChange(of: filteredStreams.map(\.id)) { _, streamIDs in
            if selectedStreamID.map({ streamIDs.contains($0) }) != true {
                selectedStreamID = streamIDs.first
            }
        }
        .onChange(of: appModel.realtimeRevision) { _, _ in
            Task { await loadTopics(for: selectedStream, force: true) }
        }
    }

    private var totalUnreadCount: Int {
        appModel.streams.reduce(0) { $0 + max(0, $1.unreadCount) }
    }

    private var streamSubtitle: String {
        guard let stream = selectedStream else { return "Каналы и личные чаты" }
        if stream.isPrivate {
            guard let userID = stream.directUserUUID,
                  let user = appModel.users.first(where: { $0.id == userID })
            else { return "Личный чат" }
            return user.status == "offline" ? "Не в сети" : "В сети"
        }
        let streamBindings = bindings.filter { $0.streamUUID == stream.id }
        let userIDs = Set(streamBindings.map(\.userUUID))
        let onlineCount = appModel.users.filter {
            userIDs.contains($0.id) && $0.status != "offline"
        }.count
        guard !streamBindings.isEmpty else { return "Канал" }
        return "\(streamBindings.count) участников, \(onlineCount) в сети"
    }

    private func loadTopics(for stream: WorkspaceStream?, force: Bool = false) async {
        guard let stream, let session = appModel.session else {
            topics = []
            return
        }
        if !force, loadingStreamID == stream.id { return }
        loadingStreamID = stream.id
        errorMessage = nil
        do {
            let loaded = try await appModel.workspaceAPI.topics(
                session: session,
                streamUUID: stream.id
            )
            guard selectedStream?.id == stream.id else { return }
            topics = loaded.sorted { lhs, rhs in
                if lhs.unreadCount != rhs.unreadCount { return lhs.unreadCount > rhs.unreadCount }
                return lhs.updatedAt > rhs.updatedAt
            }
        } catch {
            guard selectedStream?.id == stream.id else { return }
            topics = []
            errorMessage = "Не удалось загрузить темы"
        }
        if loadingStreamID == stream.id { loadingStreamID = nil }
    }
}

private struct WorkspaceMessengerHeader: View {
    let title: String
    let subtitle: String
    let onCompose: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 2) {
                Text(title)
                    .font(WorkspaceTypography.navigation(size: 16))
                    .foregroundStyle(WorkspacePalette.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(WorkspaceTypography.content(size: 12))
                    .foregroundStyle(WorkspacePalette.secondaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 58)

            HStack {
                Spacer()
                Button(action: onCompose) {
                    Image("workspaceCompose")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(WorkspacePalette.secondaryText)
                        .frame(width: 48, height: 48)
                }
                .accessibilityLabel("Новое сообщение")
                .accessibilityIdentifier("newMessageButton")
            }
        }
        .frame(height: 50)
    }
}

private struct WorkspaceMessengerSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image("workspaceSearch")
                .resizable()
                .renderingMode(.template)
                .frame(width: 24, height: 24)
                .foregroundStyle(WorkspacePalette.mobileIcon)
            TextField("Найти", text: $text)
                .font(WorkspaceTypography.navigation(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(WorkspacePalette.mobileIcon)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить поиск")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background(WorkspacePalette.input, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Поиск")
    }
}

private struct WorkspaceMessengerFolderTabs: View {
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
            HStack(spacing: 6) {
                tab(title: "Все чаты", count: allUnreadCount, id: nil)
                ForEach(visibleFolders) { folder in
                    tab(title: localizedFolderTitle(folder.title), count: folder.unreadCount, id: folder.id)
                }
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(WorkspaceTypography.navigation(size: 20))
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

    private func tab(title: String, count: Int, id: String?) -> some View {
        let selected = selectedFolderID == id
        return Button {
            onSelect(id)
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(WorkspaceTypography.navigation(size: 14, weight: .medium))
                        .foregroundStyle(selected ? WorkspacePalette.text : WorkspacePalette.mobileIcon)
                    if count > 0 {
                        WorkspaceUnreadBadge(count: count, compact: true)
                    }
                }
                Rectangle()
                    .fill(selected ? WorkspacePalette.text : .clear)
                    .frame(height: 2)
            }
        }
        .padding(.horizontal, 6)
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func localizedFolderTitle(_ title: String) -> String {
        switch title.lowercased() {
        case "personal", "private", "личные чаты": "Личные"
        case "channels", "каналы": "Каналы"
        default: title
        }
    }
}

private struct WorkspaceStreamRail: View {
    let streams: [WorkspaceStream]
    let selectedStreamID: String?
    let onSelect: (WorkspaceStream) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(streams) { stream in
                    Button {
                        onSelect(stream)
                    } label: {
                        WorkspaceMobileAvatar(stream: stream, size: 44)
                            .frame(width: 58, height: 58)
                            .background(
                                selectedStreamID == stream.id ? WorkspacePalette.mobileCard : .clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(stream.name)
                    .accessibilityAddTraits(selectedStreamID == stream.id ? .isSelected : [])
                }
            }
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
    }
}

private struct WorkspaceMessengerTopics: View {
    let stream: WorkspaceStream
    let topics: [WorkspaceTopic]
    let isLoading: Bool
    let errorMessage: String?

    private var defaultTopic: WorkspaceTopic? { topics.first(where: \.isDefault) }
    private var visibleTopics: [WorkspaceTopic] { topics.filter { !$0.isDefault } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if stream.isPrivate {
                    NavigationLink(value: stream) {
                        WorkspaceMessengerAllTopicsRow(title: stream.name, subtitle: "Личный чат")
                    }
                    .buttonStyle(.plain)
                } else if let defaultTopic {
                    NavigationLink(value: WorkspacePushConversationDestination(stream: stream, topic: defaultTopic)) {
                        WorkspaceMessengerAllTopicsRow(title: "Все темы", subtitle: "Общий поток канала")
                    }
                    .buttonStyle(.plain)
                } else {
                    WorkspaceMessengerAllTopicsRow(title: "Все темы", subtitle: "Общий поток канала")
                }

                if isLoading, topics.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 34)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(WorkspacePalette.danger)
                        .padding(20)
                } else if visibleTopics.isEmpty, !stream.isPrivate {
                    Text("Тем пока нет")
                        .font(.subheadline)
                        .foregroundStyle(WorkspacePalette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                } else {
                    ForEach(visibleTopics) { topic in
                        NavigationLink(value: WorkspacePushConversationDestination(stream: stream, topic: topic)) {
                            WorkspaceMessengerTopicRow(topic: topic)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .background(WorkspacePalette.background)
    }
}

private struct WorkspaceMessengerAllTopicsRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(WorkspacePalette.surfaceRaised)
                .frame(width: 40, height: 40)
                .overlay {
                    Image("workspaceActivityTab")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 18, height: 21)
                        .foregroundStyle(WorkspacePalette.primary)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(WorkspaceTypography.content(size: 14, weight: .medium))
                    .foregroundStyle(WorkspacePalette.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(WorkspaceTypography.content(size: 12))
                    .foregroundStyle(WorkspacePalette.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 64)
        .background(WorkspacePalette.mobileCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct WorkspaceMessengerTopicRow: View {
    let topic: WorkspaceTopic

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(workspaceColor(topic.color))
                .frame(width: 3, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("# \(topic.name)")
                        .font(WorkspaceTypography.content(size: 14, weight: .medium))
                        .foregroundStyle(WorkspacePalette.text)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(topicTime)
                        .font(WorkspaceTypography.content(size: 12))
                        .foregroundStyle(WorkspacePalette.secondaryText)
                }
                HStack(spacing: 6) {
                    Text(topic.isDone ? "Завершено" : "Обсуждение")
                        .foregroundStyle(WorkspacePalette.primary)
                    Spacer()
                }
                .font(WorkspaceTypography.content(size: 12))
            }
            Spacer(minLength: 6)
            if topic.unreadCount > 0 {
                WorkspaceUnreadBadge(count: topic.unreadCount, compact: true)
            }
            Image("workspaceNotification")
                .resizable()
                .renderingMode(.template)
                .frame(width: 13, height: 16)
                .foregroundStyle(WorkspacePalette.mobileIcon)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 64)
        .background(WorkspacePalette.mobileCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var topicTime: String {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let date = fractional.date(from: topic.updatedAt) ?? plain.date(from: topic.updatedAt) else {
            return ""
        }
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.day().month())
    }
}

private struct WorkspaceMobileAvatar: View {
    let stream: WorkspaceStream
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(workspaceColor(stream.color))
                .frame(width: size, height: size)
                .overlay {
                    Text(String(stream.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(.white)
                }
            if stream.unreadCount > 0 {
                WorkspaceUnreadBadge(count: stream.unreadCount, compact: true)
                    .offset(x: 4, y: 3)
            }
        }
    }
}

private struct WorkspaceUnreadBadge: View {
    let count: Int
    var compact = false

    var body: some View {
        Text(count > 99 ? "99+" : String(max(0, count)))
            .font(WorkspaceTypography.content(size: 12))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 4 : 6)
            .frame(minWidth: compact ? 15 : 22, minHeight: compact ? 15 : 22)
            .background(WorkspacePalette.unreadBadge, in: Capsule())
    }
}

private func workspaceColor(_ value: Int) -> Color {
    Color(
        red: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255
    )
}

private struct WorkspaceNewChatView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var creatingUserID: String?
    @State private var errorMessage: String?

    private var users: [WorkspaceUser] {
        let others = appModel.users.filter { $0.id != appModel.currentUser?.id }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return others }
        return others.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.username.localizedCaseInsensitiveContains(query) ||
            $0.email?.localizedCaseInsensitiveContains(query) == true
        }
    }

    var body: some View {
        NavigationStack {
            List(users) { user in
                Button {
                    creatingUserID = user.id
                    errorMessage = nil
                    Task {
                        do {
                            _ = try await appModel.createDirectChat(with: user)
                            dismiss()
                        } catch {
                            creatingUserID = nil
                            errorMessage = "Не удалось открыть личный чат"
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(WorkspacePalette.primary.opacity(0.16))
                            .frame(width: 42, height: 42)
                            .overlay {
                                Text(String(user.displayName.prefix(1)).uppercased())
                                    .font(.headline)
                                    .foregroundStyle(WorkspacePalette.primary)
                            }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.displayName)
                                .foregroundStyle(WorkspacePalette.text)
                            Text(user.email ?? "@\(user.username)")
                                .font(.caption)
                                .foregroundStyle(WorkspacePalette.secondaryText)
                        }
                        Spacer()
                        if creatingUserID == user.id { ProgressView() }
                    }
                }
                .disabled(creatingUserID != nil)
                .listRowBackground(WorkspacePalette.surface)
            }
            .overlay {
                if users.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(WorkspacePalette.background)
            .navigationTitle("Новое сообщение")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Имя или email")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let errorMessage {
                    WorkspaceInlineError(message: errorMessage).padding()
                }
            }
        }
    }
}

private struct WorkspaceProfileView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @State private var confirmSignOut = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Circle()
                        .fill(WorkspacePalette.primary.opacity(0.16))
                        .frame(width: 64, height: 64)
                        .overlay {
                            Text(initials)
                                .font(.title2.bold())
                                .foregroundStyle(WorkspacePalette.primary)
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appModel.currentUser?.displayName ?? appModel.session?.username ?? "Workspace")
                            .font(.title3.bold())
                            .foregroundStyle(WorkspacePalette.text)
                        if let username = appModel.currentUser?.username {
                            Text("@\(username)")
                                .foregroundStyle(WorkspacePalette.secondaryText)
                        }
                        if let status = appModel.currentUser?.statusText, !status.isEmpty {
                            Text("\(appModel.currentUser?.statusEmoji ?? "") \(status)")
                                .font(.subheadline)
                                .foregroundStyle(WorkspacePalette.secondaryText)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Организация") {
                LabeledContent("Workspace", value: appModel.session?.server.displayName ?? "—")
                if let host = appModel.session?.server.baseURL.host {
                    LabeledContent("Сервер", value: host)
                }
                if let email = appModel.currentUser?.email {
                    LabeledContent("Email", value: email)
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmSignOut = true
                } label: {
                    Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .accessibilityIdentifier("signOutButton")
            }
        }
        .scrollContentBackground(.hidden)
        .background(WorkspacePalette.background)
        .navigationTitle("Профиль")
        .confirmationDialog("Выйти из Workspace?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Выйти", role: .destructive) { appModel.signOut() }
            Button("Отмена", role: .cancel) {}
        }
    }

    private var initials: String {
        let name = appModel.currentUser?.displayName ?? appModel.session?.username ?? "W"
        return name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

#Preview("Main") {
    WorkspaceMainView()
        .environment(WorkspaceAppModel())
}
