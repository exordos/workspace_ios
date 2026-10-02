//
//  HomeAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct HomeAssembly {

    func assemble(with userProfile: UserProfile, eventHandler: EventHandler) -> some View {
        let model = Home()
        let viewModel = HomeViewModel(apiClient: WorkspaceAPIClient.current, model: model, userProfile: userProfile, eventHandler: eventHandler)
        let view = HomeView(viewModel: viewModel)
        return view
    }

    func view(from viewModel: HomeViewModel) -> some View {
        let view = HomeView(viewModel: viewModel)
        return view
    }
}
