//
//  AddFolderAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct AddFolderAssembly {

    func assemble() -> some View {
        let model = AddFolder()
        let viewModel = AddFolderViewModel(apiClient: WorkspaceAPIClient.current, model: model)
        let view = AddFolderView(viewModel: viewModel)
        return view
    }
}
