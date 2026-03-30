//
//  ChatChannelsAssembly.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 25.03.2026.
//  
//

import SwiftUI

struct ChatChannelsAssembly {

    func assemble(with userProfile: UserProfile) -> some View {
        let model = ChatChannels()
        let viewModel = ChatChannelsViewModel(apiClient: WorkspaceAPIClient.current, model: model, userProfile: userProfile)
        let view = ChatChannelsView(viewModel: viewModel)
        return view
    }

    func view(from viewModel: ChatChannelsViewModel) -> some View {
        let view = ChatChannelsView(viewModel: viewModel)
        return view
    }
}
