//
//  CreationBaseAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct CreationBaseAssembly {

    func assemble(onDirectTap: @escaping () -> Void, onStreamTap: @escaping () -> Void) -> some View {
        let model = CreationBase()
        let viewModel = CreationBaseViewModel(apiClient: WorkspaceAPIClient.current, model: model, onDirectTap: onDirectTap, onStreamTap: onStreamTap)
        let view = CreationBaseView(viewModel: viewModel)
        return view
    }
}
