//
//  MainTabBarView.swift
//  WorkspaceBeta
//
//

import SwiftUI
import Combine

struct MainTabBarView: View {

    @ObservedObject var viewModel: MainTabBarViewModel
    @ObservedObject var userProfile: UserProfile

    @State var selectedTabIndex: Int = 0

    var body: some View {
        contentView
    }

    private var contentView: some View {
        TabView(selection: $selectedTabIndex) {
            ChatChannelsAssembly().view(from: viewModel.chatChannelsViewModel)
                .tabItem {
                    MainTabBar.Tab.chat.image
                }
                .tag(1)
            ProfileAssembly().view(from: viewModel.profileViewModel)
                .tabItem {
                    MainTabBar.Tab.profile.image
                }
                .tag(2)
        }
    }
}
