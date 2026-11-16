//
//  VisualSettingsAssembly.swift
//  Workspace
//
//  
//

import SwiftUI

struct VisualSettingsAssembly {

    func assemble() -> some View {
        let model = VisualSettings()
        let viewModel = VisualSettingsViewModel(apiClient: WorkspaceAPIClient.current, model: model)
        let view = VisualSettingsView(viewModel: viewModel)
        return view
    }
}
