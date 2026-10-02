//
//  ChatChannelsView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

enum ChatNavigationDestination: Hashable {
    case messages(String, String, Bool)
    case streamInfo(StreamData, TopicsResponseData)
    case userProfile(UserResponseData)
    case creationBase
    case createStream
    case createDirectStream
}

struct ChatChannelsView: View {

    @ObservedObject var viewModel: ChatChannelsViewModel

    @State private var path = NavigationPath()

    @State var shouldShowAddUserScene = false

    @State private var offsetX: CGFloat = 0
    @GestureState private var dragX: CGFloat = 0
    private let dismissThreshold: CGFloat = 120

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
                    let sortedFilteredStreams = filteredStreams.sorted {
                        guard let firstMessage = $0.lastMessage else {
                            return false
                        }

                        guard let secondMessage = $1.lastMessage else {
                            return true
                        }

                        return firstMessage.createdAt > secondMessage.createdAt
                    }
                    ScrollView {
                        LazyVStack(alignment: .leading) {
                            ForEach(sortedFilteredStreams) { stream in
                                ChatHeaderView(stream: stream, viewModel: viewModel)
                                    .onTapGesture {
                                        withAnimation {
                                            viewModel.selectedStream = stream
                                        }
                                        viewModel.loadTopics(for: stream)
                                    }
                            }
                        }
                    }
                }
                if let selectedStream = viewModel.selectedStream {
                    HStack {
                        Divider()
                            .background(Color.line10)
                        ScrollView {
                            LazyVStack(alignment: .leading) {
                                let topics = viewModel.streamTopics[selectedStream.uuid] ?? []
                                ForEach(topics, id: \.self) { topic in
                                    TopicHeaderView(topic: topic, viewModel: viewModel)
                                        .onTapGesture {
                                            path.append(ChatNavigationDestination.messages(selectedStream.uuid, topic.uuid, selectedStream.isPrivate))
                                        }
                                        .contextMenu(
                                            ContextMenu {
                                                Button {

                                                } label: {
                                                    Text("Wassup")
                                                }

                                            }
                                        )
                                }
                            }
                        }
                    }
                    .background(Color.surface)
                    .padding(.leading, 80.0)
                    .offset(x: offsetX + dragX)
                    .simultaneousGesture(
                                DragGesture(minimumDistance: 20)
                                    .updating($dragX) { value, state, _ in
                                        if abs(value.translation.width) > abs(value.translation.height) {
                                            state = value.translation.width
                                        }
                                    }
                                    .onEnded { value in
                                        let dx = value.translation.width
                                        let dy = value.translation.height
                                        guard abs(dx) > abs(dy), abs(dx) > dismissThreshold else {
                                            withAnimation(.spring()) { offsetX = 0 }
                                            return
                                        }
                                        let direction: CGFloat = dx > 0 ? 1 : -1
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            offsetX = direction * UIScreen.main.bounds.width
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            viewModel.selectedStream = nil
                                            offsetX = 0
                                        }
                                    }
                            )
                }
            }
            .navigationDestination(for: ChatNavigationDestination.self) { value in
                switch value {
                case let .messages(streamUuid, topicUuid, isDirectMessages):
                    ChatAssembly().assemble(streamUuid: streamUuid, topicUuid: topicUuid, isDirectMessages: isDirectMessages, eventHandler: viewModel.eventHandler)
                case .creationBase:
                    CreationBaseAssembly().assemble {
                        path.append(ChatNavigationDestination.createDirectStream)
                    } onStreamTap: {
                        path.append(ChatNavigationDestination.createStream)
                    }
                case .createDirectStream:
                    CreateDirectStreamAssembly().assemble(with: viewModel.userProfile, eventHandler: viewModel.eventHandler) { streamUuid, topicUuid in
                        path.removeLast(path.count)
                        path.append(ChatNavigationDestination.messages(streamUuid, topicUuid, true))
                    }
                case .createStream:
                    CreateStreamAssembly().assemble(with: viewModel.userProfile, eventHandler: viewModel.eventHandler) { streamUuid, topicUuid in
                        path.removeLast(path.count)
                        path.append(ChatNavigationDestination.messages(streamUuid, topicUuid, true))
                    }
                case let .streamInfo(stream, topic):
                    StreamInfoAssembly().assemble()
                case let .userProfile(userData):
                    ChatUserInfoAssembly().assemble()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Мессенджер")
            .navigationBarItems(
                trailing: Button(action: {
                    path.append(ChatNavigationDestination.creationBase)
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
    @ObservedObject var viewModel: ChatChannelsViewModel

    var body: some View {
        ZStack {
            HStack {
                AvatarView(avatarUrn: stream.avatarString, baseUrl: viewModel.userProfile.selectedServer?.baseUrl ?? "", color: stream.color, name: stream.name, enhanceImageRequest: viewModel.apiClient.addHeaders)
                    .frame(width: 40, height: 40.0)
                    .clipShape(Circle())
                    .padding(EdgeInsets(top: 12.0, leading: 8.0, bottom: 12.0, trailing: 12.0))
                VStack(alignment: .leading, spacing: 8.0) {
                    Text(stream.name)
                        .foregroundStyle(Color.textHeaders)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let lastMessage = stream.lastMessage {
                        HStack {
                            if let lastMessageAuthor = lastMessage.author {
                                Text(lastMessageAuthor.displayableName)
                                    .foregroundStyle(Color.textHeaders)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            Text(lastMessage.payload.content)
                                .foregroundStyle(Color.textAdditional50)
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    let unreadCount = stream.activeUnreadCount > 0 ? stream.activeUnreadCount : stream.passiveUnreadCount
                    if unreadCount > 0 {
                        let badgeColor = stream.activeUnreadCount > 0 ? Color.noticeBase : Color.noticeDisable
                        BadgeView(item: "\(unreadCount)", color: badgeColor)
                    }
                    Spacer()
                    if let lastMessage = stream.lastMessage {
                        Text(DateFormatter.timeFormatter.string(from: lastMessage.createdAt))
                            .foregroundStyle(Color.messageTimeColor)
                            .font(.system(size: 12))
                    }
                }
                .padding(EdgeInsets(top: 4.0, leading: 8.0, bottom: 4.0, trailing: 0.0))
            }
            if viewModel.selectedStream == nil {
                VStack {
                    Spacer()
                    Divider()
                        .background(Color.line10)
                }
            }
        }
        .frame(height: 64.0)
        .padding(.horizontal, 12.0)
    }
}

struct TopicHeaderView: View {

    let topic: TopicsResponseData
    let viewModel: ChatChannelsViewModel

    var body: some View {
        ZStack {
            HStack {
                Color(hex: topic.color)
                    .frame(width: 3.0, height: 47.0)
                    .padding(.horizontal, 12.0)
                VStack(alignment: .leading, spacing: 8.0) {
                    Text(topic.name)
                        .foregroundStyle(Color.textHeaders)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let lastMessage = topic.lastMessage {
                        HStack {
                            if let lastMessageAuthor = lastMessage.author {
                                Text(lastMessageAuthor.displayableName)
                                    .foregroundStyle(Color.textHeaders)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            Text(lastMessage.payload.content)
                                .foregroundStyle(Color.textAdditional50)
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    if topic.unreadCount > 0 {
                        let badgeColor = topic.notificationMode == .mute ? Color.noticeDisable : Color.noticeBase
                        BadgeView(item: "\(topic.unreadCount)", color: badgeColor)
                    }
                    Spacer()
                    Button {
                        viewModel.setNextNotificationMode(for: topic)
                    } label: {
                        let imageName = switch (topic.notificationMode) {
                        case .default: "notificationsSmall"
                        case .follow: "volumeSmall"
                        case .mute: "notificationsOffSmall"
                        }
                        Image(imageName)
                    }
                    .accentColor(Color.textAdditional30)

                }
                .padding(8.0)
            }
            VStack {
                Spacer()
                Divider()
                    .background(Color.line10)
            }
        }
        .frame(height: 64.0)
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

extension View {
    func animatedDrag() -> some View {
        modifier(DraggableModifier())
    }
}

struct DraggableModifier : ViewModifier {

    @State private var draggedOffset: CGSize = .zero

    func body(content: Content) -> some View {
        content
        .offset(
            CGSize(width: draggedOffset.width,
                   height:  0)
        )
        .gesture(
            DragGesture()
            .onChanged { value in
                self.draggedOffset = value.translation
            }
            .onEnded { value in
                self.draggedOffset = .zero
            }
        )
    }
}
