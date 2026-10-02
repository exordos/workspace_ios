//
//  AddUserToStreamAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct AddUserToStreamAssembly {

    func assemble() -> some View {
        let model = AddUserToStream()
        let viewModel = AddUserToStreamViewModel(apiClient: WorkspaceAPIClient.current, model: model)
        let view = AddUserToStreamView(viewModel: viewModel)
        return view
    }
}
