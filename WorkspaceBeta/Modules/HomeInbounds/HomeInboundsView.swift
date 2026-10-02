//
//  HomeInboundsView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

struct HomeInboundsView: View {

    @ObservedObject var viewModel: HomeInboundsViewModel

    var body: some View {
        mainView
            .navigationTitle("Входящие")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.onAppear()
            }
    }

    @ViewBuilder
    var mainView: some View {
        let unreadStreams = viewModel.streams.filter { $0.activeUnreadCount > 0 }
        if viewModel.loadingState == .loading {
            FullScreenLoaderView()
        } else if unreadStreams.isEmpty {
            VStack {
                Text("Новых сообщений нет")
            }
        } else {
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(unreadStreams, id: \.self) { stream in
                        VStack {
                            HStack {
                                AvatarView(avatarUrn: stream.avatarString, baseUrl: viewModel.userProfile.selectedServer?.baseUrl ?? "", color: stream.color, name: stream.name, enhanceImageRequest: viewModel.apiClient.addHeaders)
                                    .frame(width: 40, height: 40.0)
                                    .clipShape(Circle())
                                    .padding(EdgeInsets(top: 12.0, leading: 0.0, bottom: 12.0, trailing: 12.0))
                                Text(stream.name)
                                    .foregroundStyle(Color.textHeaders)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                                let unreadCount = stream.activeUnreadCount > 0 ? stream.activeUnreadCount : stream.passiveUnreadCount
                                if unreadCount > 0 {
                                    let badgeColor = stream.activeUnreadCount > 0 ? Color.noticeBase : Color.noticeDisable
                                    BadgeView(item: "\(unreadCount)", color: badgeColor)
                                }
                            }
                            .padding(.horizontal, 12.0)
                            if let unreadTopics = viewModel.streamTopics[stream.uuid]?.filter({ $0.activeUnreadCount > 0 }) {
                                ForEach(unreadTopics, id: \.self) { topic in
                                    ZStack {
                                        HStack {
                                            Color(hex: topic.color)
                                                .frame(width: 3.0, height: 35.0)
                                                .padding(.horizontal, 12.0)
                                            Text(topic.name)
                                                .foregroundStyle(Color.textHeaders)
                                                .font(.system(size: 14, weight: .medium))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                            Spacer()
                                            if topic.activeUnreadCount > 0 {
                                                let badgeColor = topic.notificationMode == .mute ? Color.noticeDisable : Color.noticeBase
                                                BadgeView(item: "\(topic.unreadCount)", color: badgeColor)
                                            }
                                        }
                                        VStack {
                                            Spacer()
                                            Divider()
                                                .background(Color.line10)
                                        }
                                    }
                                    .frame(height: 48.0)
                                    .padding(.horizontal, 24.0)
                                }
                            }
                        }
                        .background(Color.searchBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8.0))
                        .padding(.horizontal, 12.0)
                    }
                }
            }
        }
    }
}
