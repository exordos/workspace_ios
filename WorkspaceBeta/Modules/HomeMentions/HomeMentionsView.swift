//
//  HomeMentionsView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

struct HomeMentionsView: View {

    @ObservedObject var viewModel: HomeMentionsViewModel

    var body: some View {
        mainView
            .navigationTitle("Упоминания")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.onAppear()
            }
    }

    @ViewBuilder
    var mainView: some View {
        if viewModel.loadingState == .loading {
            FullScreenLoaderView()
        } else if viewModel.model.messages.isEmpty {
            VStack {
                Text("Упоминаний нет")
            }
        } else {
            ScrollView {
                VStack(alignment: .leading) {
                    let sortedMessages = viewModel.model.messages.sorted {
                        $0.createdAt > $1.createdAt
                    }
                    ForEach(sortedMessages, id: \.self) { message in
                        VStack(alignment: .leading) {
                            HStack(alignment: .top) {
                                AvatarView(avatarUrn: message.author?.avatar, baseUrl: viewModel.userProfile.selectedServer?.baseUrl ?? "", color: nil, name: message.author?.displayableName ?? "", enhanceImageRequest: viewModel.apiClient.addHeaders)
                                    .frame(width: 40.0, height: 40.0)
                                    .clipShape(Circle())
                                    .padding(.trailing, 4.0)
                                    .padding(.top, 8.0)
                                VStack(alignment: .leading) {
                                    Text(message.author?.displayableName ?? "")
                                        .foregroundStyle(Color.indicatorPurple)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(LocalizedStringKey(message.payload.content))
                                        .lineLimit(Int.max)
                                        .foregroundStyle(Color.textHeaders)
                                        .font(.system(size: 14))
                                }
                                Spacer()
                                VStack {
                                    Spacer()
                                    Text(DateFormatter.timeFormatter.string(from: message.createdAt))
                                        .foregroundStyle(Color.messageTimeColor)
                                        .font(.system(size: 12))
                                }
                            }
                            Divider()
                                .background(Color.line10)
                        }
                        .padding(.horizontal, 12.0)
                    }
                }
            }
        }
    }
}
