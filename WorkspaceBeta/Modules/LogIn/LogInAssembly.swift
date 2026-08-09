//
//  LogInAssembly.swift
//  WorkspaceBeta
//
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
}
