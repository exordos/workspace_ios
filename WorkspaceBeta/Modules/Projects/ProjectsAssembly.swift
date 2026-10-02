//
//  ProjectsAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct ProjectsAssembly {

    func assemble(with userProfile: UserProfile) -> some View {
        let model = Projects()
        let viewModel = ProjectsViewModel(apiClient: WorkspaceAPIClient.current, model: model, userProfile: userProfile)
        let view = ProjectsView(viewModel: viewModel)
        return view
    }

    func assemble(with viewModel: ProjectsViewModel) -> some View {
        let view = ProjectsView(viewModel: viewModel)
        return view
    }
}
