//
//  ProfileAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct ProfileAssembly {

    func assemble(with userProfile: UserProfile, eventHandler: EventHandler) -> some View {
        let model = Profile()
        let viewModel = ProfileViewModel(apiClient: WorkspaceAPIClient.current, model: model, userProfile: userProfile, eventHandler: eventHandler)
        let view = ProfileView(viewModel: viewModel)
        return view
    }

    func view(from viewModel: ProfileViewModel) -> some View {
        let view = ProfileView(viewModel: viewModel)
        return view
    }
}
