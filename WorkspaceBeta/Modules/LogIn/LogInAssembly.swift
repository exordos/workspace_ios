//
//  LogInAssembly.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 22.02.2026.
//

import SwiftUI

struct LogInAssembly {
    func assemble(with userProfile: UserProfile) -> some View {
        let model = LogIn()
        let viewModel = LogInViewModel(apiClient: WorkspaceAPIClient.current,
                                        model: model,
                                        userProfile: userProfile)
        let view = LogInView(viewModel: viewModel)
        return view
    }

    func view(from viewModel: LogInViewModel) -> some View {
        let view = LogInView(viewModel: viewModel)
        return view
    }
}
