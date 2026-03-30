//
//  MailAssembly.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 24.02.2026.
//  
//

import SwiftUI

struct MailAssembly {

    func assemble() -> some View {
        let model = Mail()
        let viewModel = MailViewModel(apiClient: WorkspaceAPIClient.current, model: model)
        let view = MailView(viewModel: viewModel)
        return view
    }

    func view(from viewModel: MailViewModel) -> some View {
        let view = MailView(viewModel: viewModel)
        return view
    }
}
