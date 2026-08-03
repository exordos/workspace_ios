import SwiftUI

struct WorkspaceMainView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @State private var selectedTab = WorkspaceTab.chats
    @State private var chatPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $chatPath) {
                WorkspaceChatListView()
            }
            .tabItem { Label("Чаты", systemImage: "bubble.left.and.bubble.right") }
            .tag(WorkspaceTab.chats)

            NavigationStack {
                WorkspaceProfileView()
            }
            .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
            .tag(WorkspaceTab.profile)
        }
        .tint(WorkspacePalette.primary)
        .task(id: WorkspacePushNavigationKey(
            phase: appModel.phase,
            revision: appModel.pushRouteRevision
        )) {
            await openPendingPushRoute()
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
                selectedTab = .chats
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
            selectedTab = .chats
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

private enum WorkspaceTab: Hashable {
    case chats
    case profile
}

private struct WorkspacePushNavigationKey: Hashable {
    let phase: WorkspaceAppPhase
    let revision: Int
}

private struct WorkspacePushConversationDestination: Hashable {
    let stream: WorkspaceStream
    let topic: WorkspaceTopic
}

private struct WorkspaceChatListView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @State private var searchText = ""
    @State private var selectedFolderID: String?
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

    var body: some View {
        List {
            if !appModel.folders.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            folderChip(title: "Все", unreadCount: appModel.streams.reduce(0) { $0 + $1.unreadCount }, id: nil)
                            ForEach(appModel.folders) { folder in
                                folderChip(title: folder.title, unreadCount: folder.unreadCount, id: folder.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 0))
                    .listRowBackground(WorkspacePalette.background)
                }
            }

            if filteredStreams.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "Чатов пока нет" : "Ничего не найдено",
                    systemImage: searchText.isEmpty ? "bubble.left" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "Новые каналы и личные сообщения появятся здесь." : "Попробуйте изменить запрос.")
                )
                .listRowBackground(WorkspacePalette.background)
            } else {
                Section {
                    ForEach(filteredStreams) { stream in
                        NavigationLink(value: stream) {
                            WorkspaceStreamRow(stream: stream)
                        }
                        .listRowBackground(WorkspacePalette.surface)
                        .contextMenu {
                            if !appModel.folders.isEmpty {
                                Menu("Папки") {
                                    ForEach(appModel.folders) { folder in
                                        let included = folder.items.contains { $0.streamUUID == stream.id }
                                        Button {
                                            Task { await appModel.toggle(stream, in: folder) }
                                        } label: {
                                            Label(
                                                folder.title,
                                                systemImage: included ? "checkmark.circle.fill" : "circle"
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(WorkspacePalette.background)
        .navigationTitle("Чаты")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingNewChat = true
                    } label: {
                        Label("Новое сообщение", systemImage: "person.badge.plus")
                    }
                    Button {
                        showingCreateFolder = true
                    } label: {
                        Label("Новая папка", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Создать")
            }
        }
        .searchable(text: $searchText, prompt: "Поиск")
        .refreshable { await appModel.retryLoadingContent() }
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
        .overlay(alignment: .bottom) {
            if let error = appModel.errorMessage {
                WorkspaceInlineError(message: error)
                    .padding()
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
    }

    private func folderChip(title: String, unreadCount: Int, id: String?) -> some View {
        let selected = selectedFolderID == id
        return Button {
            selectedFolderID = id
        } label: {
            HStack(spacing: 6) {
                Text(title)
                if unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : String(unreadCount))
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(selected ? Color.white.opacity(0.22) : WorkspacePalette.primary.opacity(0.14), in: Capsule())
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selected ? .white : WorkspacePalette.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? WorkspacePalette.primary : WorkspacePalette.input, in: Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let id,
               let folder = appModel.folders.first(where: { $0.id == id }),
               folder.systemType == nil || folder.systemType == "created" {
                Button("Удалить папку", role: .destructive) {
                    if selectedFolderID == id { selectedFolderID = nil }
                    Task { await appModel.deleteFolder(folder) }
                }
            }
        }
    }
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

private struct WorkspaceStreamRow: View {
    let stream: WorkspaceStream

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(streamColor)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Text(stream.name.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                if stream.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(WorkspacePalette.secondaryText, in: Circle())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stream.name)
                    .font(.body.weight(stream.unreadCount > 0 ? .semibold : .regular))
                    .foregroundStyle(WorkspacePalette.text)
                    .lineLimit(1)
                if let description = stream.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(WorkspacePalette.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if stream.unreadCount > 0 {
                Text(stream.unreadCount > 99 ? "99+" : String(stream.unreadCount))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 24)
                    .background(WorkspacePalette.primary, in: Capsule())
                    .accessibilityLabel("Непрочитанных: \(stream.unreadCount)")
            }
        }
        .padding(.vertical, 5)
    }

    private var streamColor: Color {
        let red = Double((stream.color >> 16) & 0xFF) / 255
        let green = Double((stream.color >> 8) & 0xFF) / 255
        let blue = Double(stream.color & 0xFF) / 255
        return Color(red: red, green: green, blue: blue)
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
