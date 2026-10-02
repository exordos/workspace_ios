//
//  HomeInboundsAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct HomeInboundsAssembly {

    func assemble(with userProfile: UserProfile, eventHandler: EventHandler) -> some View {
        let model = HomeInbounds()
        let viewModel = HomeInboundsViewModel(apiClient: WorkspaceAPIClient.current, model: model, userProfile: userProfile, eventHandler: eventHandler)
        let view = HomeInboundsView(viewModel: viewModel)
        return view
    }
}
