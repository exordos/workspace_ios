//
//  HomeMentionsAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct HomeMentionsAssembly {

    func assemble(with userProfile: UserProfile, eventHandler: EventHandler) -> some View {
        let model = HomeMentions()
        let viewModel = HomeMentionsViewModel(apiClient: WorkspaceAPIClient.current, model: model, userProfile: userProfile, eventHandler: eventHandler)
        let view = HomeMentionsView(viewModel: viewModel)
        return view
    }
}
