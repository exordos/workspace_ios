//
//  StreamInfoView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import SwiftData
import Combine

struct StreamInfoView: View {

    @ObservedObject var viewModel: StreamInfoViewModel

    @Query var users: [UserData]

    @Query var currentStreamArray: [StreamData]

    init(viewModel: StreamInfoViewModel, streamUuid: String) {
        self.viewModel = viewModel

        let streamPredicate = #Predicate<StreamData> { stream in
            stream.uuid == streamUuid
        }
        _currentStreamArray = Query(filter: streamPredicate)
    }

    var body: some View {
        VStack(alignment: .leading) {
            header
            generalSettings
            notificationSettings
            participantsView
        }
    }

    var header: some View {
        HStack {
            let currentStream = currentStreamArray.first
            AvatarView(avatarUrn: currentStream?.avatarString, baseUrl: viewModel.userProfile.selectedServer?.baseUrl ?? "", color: currentStream?.color, name: currentStream?.name ?? "", enhanceImageRequest: viewModel.apiClient.addHeaders)
                .frame(width: 40, height: 40.0)
                .clipShape(Circle())
                .padding(EdgeInsets(top: 12.0, leading: 8.0, bottom: 12.0, trailing: 12.0))
            VStack(alignment: .leading) {
                if let currentStream {
                    Text(currentStream.name)
                        .foregroundStyle(Color.textHeaders)
                        .font(.system(size: 20, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if currentStream.hasEncryption {
                        Text("Защищённый чат")
                            .foregroundStyle(Color.primary)
                            .font(.system(size: 16))
                    }
                    Text(userStatusString)
                        .foregroundStyle(Color.textAdditional30)
                        .font(.system(size: 14))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var generalSettings: some View {
        HStack(spacing: 8.0) {
            SettingsButton(title: "Позвонить", imageName: "call") {

            }
            SettingsButton(title: "Настройки", imageName: "settings") {
                viewModel.onSettingsButtonTap()
            }
            SettingsButton(title: "Поделиться", imageName: "share") {

            }
        }
        .padding(.horizontal, 12.0)
    }

    var notificationSettings: some View {
        HStack {
            Text("")
            Text("")
            Text("")
        }
    }

    var participantsView: some View {
        VStack(alignment: .leading) {
            Text("Участники")
                .foregroundStyle(Color.textHeaders)
                .font(.system(size: 14, weight: .medium))
                .padding(12.0)
            ScrollView {
                LazyVStack(alignment: .leading) {
                    let bindedUsers: [UserData] = currentStreamArray.first?.streamBindings.compactMap(\.user) ?? []
                    ForEach(bindedUsers, id:\.self) { user in
                        ParticipantView(user: user, viewModel: viewModel)
                    }
                }
            }
        }
    }

    var userStatusString: String {
        guard let currentStream = currentStreamArray.first else { return "" }
        let bindedUsers = currentStream.streamBindings.compactMap(\.user)
        let onlineBindedUsersCount = bindedUsers.count { $0.status == "active" }
        return "\(bindedUsers.count) участников, \(onlineBindedUsersCount) онлайн"
    }
}

struct ParticipantView: View {

    let user: UserData
    let viewModel: StreamInfoViewModel

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                AvatarView(avatarUrn: user.avatar, baseUrl: viewModel.userProfile.selectedServer?.baseUrl ?? "", color: nil, name: user.displayableName, enhanceImageRequest: viewModel.apiClient.addHeaders)
                    .frame(width: 40.0, height: 40.0)
                    .clipShape(Circle())
                    .padding(.trailing, 4.0)
                VStack(alignment: .leading) {
                    Text(user.displayableName)
                        .font(.system(size: 14.0))
                        .foregroundStyle(Color.textHeaders)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(user.statusString)
                        .font(.system(size: 14.0))
                        .foregroundStyle(Color.textAdditional30)
                }
            }
            Divider()
                .background(Color.line10)
        }
        .padding(.horizontal, 12.0)
    }
}

struct SettingsButton: View {

    let title: LocalizedStringKey
    let imageName: String
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .center) {
                Image(imageName)
                Text(title)
                    .font(.system(size: 12.0))
                    .foregroundStyle(Color.textAdditional50)
            }
            .padding(.vertical, 8.0)
        }
        .frame(maxWidth: .infinity)
        .background(Color.cardBackgroundBase)
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
    }
}
