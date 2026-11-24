//
//  ChatAssembly.swift
//  Workspace
//
//  
//

import SwiftUI

struct ChatAssembly {

    func assemble(streamUuid: String,
                  topicUuid: String,
                  isDirectMessages: Bool,
                  eventHandler: EventHandler, initialMessageUuid: String? = nil,
                  onInfoButtonTap: @escaping () -> Void, onUserTap: @escaping (String) -> Void) -> some View {
        let model = Chat(streamUuid: streamUuid, topicUuid: topicUuid)
        let viewModel = ChatViewModel(apiClient: WorkspaceAPIClient.current, model: model, eventHandler: eventHandler, onInfoButtonTap: onInfoButtonTap, onUserTap: onUserTap)
        let view = ChatView(viewModel: viewModel, streamUuid: streamUuid, topicUuid: topicUuid, initialMessageUuid: initialMessageUuid)
        return view
    }

    func view(from viewModel: ChatViewModel) -> some View {
        let view = ChatView(viewModel: viewModel, streamUuid: viewModel.model.streamUuid, topicUuid: viewModel.model.topicUuid)
        return view
    }
}
