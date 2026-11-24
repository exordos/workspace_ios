//
//  MainTabBarView.swift
//  Workspace
//
//

import SwiftUI
import Combine

struct MainTabBarView: View {

    @ObservedObject var viewModel: MainTabBarViewModel
    @ObservedObject var userProfile: UserProfile

    @State var selectedTabIndex: Int = 0
    @ObservedObject private var push = PushNotifications.shared

    var body: some View {
        contentView
            .task(id: push.pendingTap) {
                guard let route = push.pendingTap else { return }
                let opened = await viewModel.chatChannelsViewModel.openNotification(route)
                guard !Task.isCancelled, push.pendingTap == route else { return }
                if opened {
                    selectedTabIndex = 2
                }
                push.pendingTap = nil
            }
    }

    private var contentView: some View {
        TabView(selection: $selectedTabIndex) {
            HomeAssembly().view(from: viewModel.homeViewModel)
                .tabItem {
                    MainTabBar.Tab.home.image
                }
                .tag(1)
            ChatChannelsAssembly().view(from: viewModel.chatChannelsViewModel)
                .tabItem {
                    MainTabBar.Tab.chat.image
                }
                .tag(2)
            ProfileAssembly().view(from: viewModel.profileViewModel)
                .tabItem {
                    MainTabBar.Tab.profile.image
                }
                .tag(3)
        }
    }
}
