//
//  ChatAssembly.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 24.02.2026.
//  
//

import SwiftUI

struct ChatAssembly {

    func assemble(chatTitle: String, chatId: String, topic: String? = nil, isDirectMessages: Bool) -> some View {
        let model = Chat(chatTitle: chatTitle, chatId: chatId, topic: topic, isDirectMessages: isDirectMessages)
        let viewModel = ChatViewModel(apiClient: WorkspaceAPIClient.current, model: model)
        let view = ChatView(viewModel: viewModel)
        return view
    }

    func view(from viewModel: ChatViewModel) -> some View {
        let view = ChatView(viewModel: viewModel)
        return view
    }
}
