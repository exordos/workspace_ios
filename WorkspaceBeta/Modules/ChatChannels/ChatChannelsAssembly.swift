//
//  ChatChannelsAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct ChatChannelsAssembly {

    func assemble(with userProfile: UserProfile, eventHandler: EventHandler) -> some View {
        let model = ChatChannels()
        let viewModel = ChatChannelsViewModel(apiClient: WorkspaceAPIClient.current, model: model, userProfile: userProfile, eventHandler: eventHandler)
        let view = ChatChannelsView(viewModel: viewModel)
        return view
    }

    func view(from viewModel: ChatChannelsViewModel) -> some View {
        let view = ChatChannelsView(viewModel: viewModel)
        return view
    }
}
