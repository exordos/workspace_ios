//
//  ProfileAssembly.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 28.03.2026.
//  
//

import SwiftUI

struct ProfileAssembly {

    func assemble() -> some View {
        let model = Profile()
        let viewModel = ProfileViewModel(apiClient: WorkspaceAPIClient.current, model: model)
        let view = ProfileView(viewModel: viewModel)
        return view
    }

    func view(from viewModel: ProfileViewModel) -> some View {
        let view = ProfileView(viewModel: viewModel)
        return view
    }
}
