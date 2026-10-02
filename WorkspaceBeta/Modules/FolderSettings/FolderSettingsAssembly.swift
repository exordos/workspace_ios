//
//  FolderSettingsAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct FolderSettingsAssembly {

    func assemble() -> some View {
        let model = FolderSettings()
        let viewModel = FolderSettingsViewModel(apiClient: WorkspaceAPIClient.current, model: model)
        let view = FolderSettingsView(viewModel: viewModel)
        return view
    }
}
