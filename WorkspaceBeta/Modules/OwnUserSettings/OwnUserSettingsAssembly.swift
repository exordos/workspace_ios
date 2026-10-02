//
//  OwnUserSettingsAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct OwnUserSettingsAssembly {

    func assemble() -> some View {
        let model = OwnUserSettings()
        let viewModel = OwnUserSettingsViewModel(apiClient: WorkspaceAPIClient.current, model: model)
        let view = OwnUserSettingsView(viewModel: viewModel)
        return view
    }
}
