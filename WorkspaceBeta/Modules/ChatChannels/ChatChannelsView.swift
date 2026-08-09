//
//  ChatChannelsView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

enum ChatNavigationDestination: Hashable {
    case messages(StreamData, TopicsResponseData)
}

struct ChatChannelsView: View {

    @ObservedObject var viewModel: ChatChannelsViewModel

    @State private var path = NavigationPath()

    @State var shouldShowAddUserScene = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                VStack {
                    if !viewModel.folders.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.folders, id: \.self) { folder in
                                    Text(folder.title)
                                        .foregroundStyle(folder.uuid == viewModel.currentlySelectedFolder?.uuid ?  Color.textHeaders : Color.textAdditional30)
                                        .font(.system(size: 14, weight: .medium))
                                        .onTapGesture {
                                            viewModel.currentlySelectedFolder = folder
                                        }
                                }
                            }
                        }
                        .padding(.horizontal, 16.0)
                    }
                    let filteredStreams = if let currentlySelectedFolder = viewModel.currentlySelectedFolder {
                        viewModel.streams.filter { stream in
                            guard let folderItems = currentlySelectedFolder.folderItems else { return false }
                            let folderItemIds = folderItems.map { folderItem in folderItem.streamUuid }
                            return folderItemIds.contains(stream.uuid)
                        }
                    } else {
                        viewModel.streams
                    }
                    ScrollView {
                        LazyVStack(alignment: .leading) {
                            ForEach(filteredStreams) { stream in
                                ChatHeaderView(stream: stream, viewModel: viewModel)
                                    .onTapGesture {
//                                        if stream.isPrivate {
//                                            path.append(ChatNavigationDestination.directMessages(chatHeader))
//                                        } else {
                                            viewModel.selectedStream = stream
                                            viewModel.loadTopics(for: stream)
//                                        }
                                    }
                            }

                        }
                    }
                }
                if let selectedStream = viewModel.selectedStream {
                    ScrollView {
                        LazyVStack(alignment: .leading) {
                            ForEach(viewModel.loadedTopics, id: \.self) { topic in
                                TopicHeaderView(topic: topic, viewModel: viewModel)
                                    .onTapGesture {
                                        path.append(ChatNavigationDestination.messages(selectedStream, topic))
                                    }
                            }
                        }
                    }
                    .background(Color.surface)
                    .padding(.leading, 80.0)
                }
            }
            .navigationDestination(for: ChatNavigationDestination.self) { value in
                switch value {
                case let .messages(stream, topic):
                    ChatAssembly().assemble(stream: stream, topic: topic, isDirectMessages: stream.isPrivate, eventHandler: viewModel.eventHadler)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Мессенджер")
            .navigationBarItems(
                trailing: Button(action: {
                    shouldShowAddUserScene = true
                }) {
                    Image("addChat")
                }
            )

        }
        .fullScreenCover(isPresented: $shouldShowAddUserScene) {
            AddUserView(userList: viewModel.users, enhanceAvatarUrl: viewModel.apiClient.addBaseUrl(to:)) { selectedUser in
                shouldShowAddUserScene = false
//                path.append(
//                    ChatNavigationDestination.directMessages(
//                        .init(user: selectedUser,
//                              lastMessage: nil,
//                              currentUserId: "\(viewModel.ownUser?.userId ?? 0)",
//                              unreadCount: 0,
//                              avatarUrl: selectedUser.avatarUrl
//                             )
//                    )
//                )
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

struct ChatHeaderView: View {

    let stream: StreamData
    let viewModel: ChatChannelsViewModel

    var body: some View {
        HStack {
            AvatarView(avatarUrn: stream.avatarString, baseUrl: viewModel.userProfile.baseUrl ?? "", color: stream.color, name: stream.name)
                .frame(width: 40, height: 40.0)
                .clipShape(Circle())
                .padding(.trailing, 12)
            VStack(alignment: .leading) {
                HStack {
                    Text(stream.name)
                        .foregroundStyle(Color.textHeaders)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    if let lastMessage = stream.lastMessage {
                        Text(DateFormatter.timeFormatter.string(from: lastMessage.updatedAt))
                            .foregroundStyle(Color.messageTimeColor)
                            .font(.system(size: 12))
                    }
                }
                HStack {
                    if let lastMessage = stream.lastMessage {
                        Text(lastMessage.payload.content)
                            .foregroundStyle(Color.textAdditional50)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer()
                    if stream.unreadCount > 0 {
                        Text("\(stream.unreadCount)")
                            .padding(.horizontal, 8)
                            .foregroundStyle(Color.noticeOnBadge)
                            .background(Color.noticeCounterBadge)
                            .clipShape(RoundedRectangle(cornerRadius: 100.0))
                    }
                }
            }
        }
        .frame(height: 70.0)
        .padding(.horizontal, 16.0)
        .background(Color.chatHeaderBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        .padding(.horizontal, 16.0)
    }
}

struct TopicHeaderView: View {

    let topic: TopicsResponseData
    let viewModel: ChatChannelsViewModel

    var body: some View {
        HStack {
            VStack {
                HStack {
                    Text(topic.name)
                        .foregroundStyle(Color.textHeaders)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    if let lastMessage = topic.lastMessage {
                        Text(DateFormatter.timeFormatter.string(from: lastMessage.updatedAt))
                            .foregroundStyle(Color.messageTimeColor)
                            .font(.system(size: 12))
                    }
                }
                HStack {
                    if let lastMessage = topic.lastMessage {
                        Text(lastMessage.payload.content)
                            .foregroundStyle(Color.textAdditional50)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer()
                    if topic.unreadCount > 0 {
                        Text("\(topic.unreadCount)")
                            .padding(.horizontal, 8)
                            .foregroundStyle(Color.noticeOnBadge)
                            .background(Color.noticeCounterBadge)
                            .clipShape(RoundedRectangle(cornerRadius: 100.0))
                    }
                }
            }

        }
        .frame(height: 70.0)
        .padding(.horizontal, 16.0)
        .background(Color.chatHeaderBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        .padding(.horizontal, 16.0)
    }
}

struct AddUserView: View {
    let userList: [UserResponseData]
    let enhanceAvatarUrl: (String) -> String
    let onTap: (UserResponseData) -> Void

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            ZStack {
                Text("Выберите пользователя")
                HStack {
                    Spacer()
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image("cross")
                    }
                }
                .padding(.horizontal, 12.0)
            }
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(userList) { user in
                        HStack {
//                            if let avatarUrl = user.avatarUrl {
//                                AvatarView(urlString: enhanceAvatarUrl(avatarUrl))
//                                    .frame(width: 40, height: 40.0)
//                                    .clipShape(Circle())
//                            }
                            Text("\(user.firstName) \(user.lastName)")
                                .onTapGesture {
                                    onTap(user)
                                }
                        }
                    }
                }
                .padding(.horizontal, 12.0)
            }
        }
    }
}
