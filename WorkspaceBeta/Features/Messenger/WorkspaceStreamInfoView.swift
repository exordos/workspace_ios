import Observation
import SwiftUI

@MainActor
@Observable
final class WorkspaceStreamInfoModel {
    let api: WorkspaceAPI
    let session: WorkspaceSession
    private(set) var stream: WorkspaceStream
    private(set) var bindings: [WorkspaceStreamBinding] = []
    private(set) var isLoading = false
    private(set) var isSavingNotifications = false
    private(set) var errorMessage: String?

    init(api: WorkspaceAPI, session: WorkspaceSession, stream: WorkspaceStream) {
        self.api = api
        self.session = session
        self.stream = stream
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            bindings = try await api.streamBindings(session: session)
        } catch {
            errorMessage = "Не удалось загрузить участников"
        }
    }

    func setNotificationMode(_ mode: String) async {
        guard !isSavingNotifications, mode != stream.notificationMode else { return }
        isSavingNotifications = true
        errorMessage = nil
        defer { isSavingNotifications = false }
        do {
            stream = try await api.setStreamNotificationMode(
                session: session,
                streamUUID: stream.id,
                mode: mode
            )
        } catch {
            errorMessage = "Не удалось изменить уведомления"
        }
    }
}

struct WorkspaceStreamInfoView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @State private var model: WorkspaceStreamInfoModel

    init(api: WorkspaceAPI, session: WorkspaceSession, stream: WorkspaceStream) {
        _model = State(initialValue: WorkspaceStreamInfoModel(api: api, session: session, stream: stream))
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    WorkspaceInfoAvatar(name: displayName, color: model.stream.color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.title3.weight(.semibold))
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(WorkspacePalette.secondaryText)
                    }
                }
                .padding(.vertical, 8)
            }

            if let peer {
                Section("Профиль") {
                    LabeledContent("Статус", value: presenceLabel(peer.status))
                    if let status = peer.statusText, !status.isEmpty {
                        LabeledContent("Сообщение", value: status)
                    }
                    if let email = peer.email, !email.isEmpty {
                        LabeledContent("Email", value: email)
                    }
                    LabeledContent("Имя пользователя", value: peer.username)
                    LabeledContent("ID пользователя", value: peer.id)
                }
            } else {
                Section("Канал") {
                    if let description = model.stream.description, !description.isEmpty {
                        Text(description)
                    }
                    LabeledContent("Доступ", value: model.stream.isPrivate ? "Закрытый" : "Открытый")
                    if let role = model.stream.role {
                        LabeledContent("Ваша роль", value: roleLabel(role))
                    }
                }
            }

            Section("Уведомления") {
                Picker("Режим", selection: notificationModeBinding) {
                    Text("Все сообщения").tag("all_messages")
                    Text("Только упоминания").tag("mentions_only")
                    Text("Без уведомлений").tag("muted")
                }
                .disabled(model.isSavingNotifications)
                if model.isSavingNotifications { ProgressView() }
            }

            if peer == nil {
                Section("Участники") {
                    if model.isLoading, members.isEmpty {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if members.isEmpty {
                        Text("Список участников недоступен")
                            .foregroundStyle(WorkspacePalette.secondaryText)
                    } else {
                        ForEach(members, id: \.user.id) { member in
                            HStack(spacing: 12) {
                                WorkspaceInfoAvatar(name: member.user.displayName, color: model.stream.color, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.user.displayName)
                                    Text(roleLabel(member.binding.role))
                                        .font(.caption)
                                        .foregroundStyle(WorkspacePalette.secondaryText)
                                }
                                Spacer()
                                Circle()
                                    .fill(member.user.status == "offline" ? WorkspacePalette.separator : WorkspacePalette.online)
                                    .frame(width: 8, height: 8)
                                    .accessibilityLabel(presenceLabel(member.user.status))
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(WorkspacePalette.background)
        .navigationTitle(peer == nil ? "О канале" : "Профиль")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .overlay(alignment: .top) {
            if let error = model.errorMessage {
                WorkspaceInlineError(message: error).padding(.horizontal)
            }
        }
    }

    private var peer: WorkspaceUser? {
        guard model.stream.isPrivate else { return nil }
        if let peerID = model.stream.directUserUUID {
            return appModel.users.first { $0.id == peerID }
        }
        return nil
    }

    private var displayName: String { peer?.displayName ?? model.stream.name }

    private var subtitle: String {
        if let peer { return presenceLabel(peer.status) }
        let online = members.filter { $0.user.status != "offline" }.count
        return "\(members.count) участников, \(online) в сети"
    }

    private var members: [(binding: WorkspaceStreamBinding, user: WorkspaceUser)] {
        let usersByID = Dictionary(uniqueKeysWithValues: appModel.users.map { ($0.id, $0) })
        return model.bindings
            .filter { $0.streamUUID == model.stream.id }
            .compactMap { binding in usersByID[binding.userUUID].map { (binding, $0) } }
            .sorted { lhs, rhs in
                if lhs.binding.role == "owner", rhs.binding.role != "owner" { return true }
                if rhs.binding.role == "owner", lhs.binding.role != "owner" { return false }
                return lhs.user.displayName.localizedCaseInsensitiveCompare(rhs.user.displayName) == .orderedAscending
            }
    }

    private var notificationModeBinding: Binding<String> {
        Binding(
            get: { model.stream.notificationMode ?? "all_messages" },
            set: { mode in Task { await model.setNotificationMode(mode) } }
        )
    }

    private func presenceLabel(_ status: String) -> String {
        switch status {
        case "active": "В сети"
        case "idle": "Неактивен"
        default: "Не в сети"
        }
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "owner": "Владелец"
        case "administrator": "Администратор"
        case "moderator": "Модератор"
        case "guest": "Гость"
        default: "Участник"
        }
    }
}

private struct WorkspaceInfoAvatar: View {
    let name: String
    let color: Int
    var size: CGFloat = 64

    var body: some View {
        Circle()
            .fill(streamColor.opacity(0.18))
            .frame(width: size, height: size)
            .overlay {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundStyle(streamColor)
            }
            .accessibilityHidden(true)
    }

    private var streamColor: Color {
        Color(
            red: Double((color >> 16) & 0xFF) / 255,
            green: Double((color >> 8) & 0xFF) / 255,
            blue: Double(color & 0xFF) / 255
        )
    }
}
