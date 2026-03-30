//
//  ChatChannelsView.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 25.03.2026.
//  
//

import SwiftUI
import Combine

enum ChatNavigationDestination: Hashable {
    case topics(ChatHeader)
    case messages(ChatHeader)
}

struct ChatChannelsView: View {

    @ObservedObject var viewModel: ChatChannelsViewModel

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            LazyVStack {
                ForEach(viewModel.model.chatHeaders, id: \.self) { chatHeader in
                    Text(chatHeader.title)
                        .onTapGesture {
                            if chatHeader.isDirectMessages {
                                path.append(ChatNavigationDestination.messages(chatHeader))
                            } else {
                                path.append(ChatNavigationDestination.topics(chatHeader))
                            }
                        }
                }

            }
            .navigationDestination(for: ChatNavigationDestination.self) { value in
                switch value {
                case let .messages(header):
                    ChatAssembly().assemble(chatTitle: header.title, chatId: header.streamId, isDirectMessages: header.isDirectMessages)
                case let .topics(header):
                    ChatTopicsAssembly().assemble()
                }
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}
