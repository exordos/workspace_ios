//
//  ChooseServerAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct ChooseServerAssembly {

    func assemble(with userProfile: UserProfile) -> some View {
        let model = ChooseServer()
        let viewModel = ChooseServerViewModel(apiClient: WorkspaceAPIClient.current, model: model, userProfile: userProfile)
        let view = ChooseServerView(viewModel: viewModel)
        return view
    }
}
