//
//  ChatUserInfoAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct ChatUserInfoAssembly {

    func assemble() -> some View {
        let model = ChatUserInfo()
        let viewModel = ChatUserInfoViewModel(apiClient: WorkspaceAPIClient.current, model: model)
        let view = ChatUserInfoView(viewModel: viewModel)
        return view
    }
}
