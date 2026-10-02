//
//  StreamInfoAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct StreamInfoAssembly {

    func assemble() -> some View {
        let model = StreamInfo()
        let viewModel = StreamInfoViewModel(apiClient: WorkspaceAPIClient.current, model: model)
        let view = StreamInfoView(viewModel: viewModel)
        return view
    }
}
