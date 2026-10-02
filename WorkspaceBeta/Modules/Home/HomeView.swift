//
//  HomeView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

enum HomeRoute: Hashable {
    case inbounds
    case mentions
    case drafts
}


struct HomeView: View {

    @ObservedObject var viewModel: HomeViewModel

    @State var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 4.0) {
                HomeMenuElementView(name: "Входящие", imageName: "homeInbounds", badgeValue: nil) {
                    path.append(HomeRoute.inbounds)
                }
                HomeMenuElementView(name: "Упоминания", imageName: "homeMentions", badgeValue: nil) {
                    path.append(HomeRoute.mentions)
                }
                HomeMenuElementView(name: "Черновики", imageName: "homeDrafts", badgeValue: nil) {
                    path.append(HomeRoute.drafts)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding(.horizontal, 12.0)
            .navigationTitle("Моя активность")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .inbounds:
                    HomeInboundsAssembly().assemble(with: viewModel.userProfile, eventHandler: viewModel.eventHandler)
                case .mentions:
                    HomeMentionsAssembly().assemble(with: viewModel.userProfile, eventHandler: viewModel.eventHandler)
                case .drafts:
                    HomeDraftsAssembly().assemble(with: viewModel.userProfile, eventHandler: viewModel.eventHandler)
                }
            }
            .onAppear {
                viewModel.onAppear()
            }
        }
    }
}

struct HomeMenuElementView: View {

    let name: String
    let imageName: String
    let badgeValue: String?
    let onTap: () -> Void

    var body: some View {
        HStack {
            Image(imageName)
                .padding(8.0)
            Text(name)
                .font(.system(size: 14.0))
                .foregroundStyle(Color.textHeaders)
            Spacer()
            if let badgeValue {
                BadgeView(item: "\(badgeValue)", color: Color.noticeBase)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing, 8.0)
        .background(Color.searchBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        .onTapGesture {
            onTap()
        }
    }
}
