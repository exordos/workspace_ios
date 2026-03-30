//
//  ChatTopicsAssembly.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 25.03.2026.
//  
//

import SwiftUI

struct ChatTopicsAssembly {

    func assemble() -> some View {
        let model = ChatTopics()
        let viewModel = ChatTopicsViewModel(apiClient: WorkspaceAPIClient.current, model: model)
        let view = ChatTopicsView(viewModel: viewModel)
        return view
    }
}
