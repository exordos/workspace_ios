//
//  ChatAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct ChatAssembly {

    func assemble(stream: StreamData,
                  topic: TopicsResponseData,
                  isDirectMessages: Bool,
                  eventHandler: EventHandler) -> some View {
        let model = Chat(stream: stream, topic: topic)
        let viewModel = ChatViewModel(apiClient: WorkspaceAPIClient.current, model: model, eventHandler: eventHandler)
        let view = ChatView(viewModel: viewModel)
        return view
    }

    func view(from viewModel: ChatViewModel) -> some View {
        let view = ChatView(viewModel: viewModel)
        return view
    }
}
