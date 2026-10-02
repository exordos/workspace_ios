//
//  HomeDraftsAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct HomeDraftsAssembly {

    func assemble(with userProfile: UserProfile, eventHandler: EventHandler) -> some View {
        let model = HomeDrafts()
        let viewModel = HomeDraftsViewModel(apiClient: WorkspaceAPIClient.current, model: model, userProfile: userProfile, eventHandler: eventHandler)
        let view = HomeDraftsView(viewModel: viewModel)
        return view
    }
}
