//
//  CreateStreamAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct CreateStreamAssembly {

    func assemble(with userProfile: UserProfile, eventHandler: EventHandler, onSuccess: @escaping (String, String) -> Void) -> some View {
        let model = CreateStream()
        let viewModel = CreateStreamViewModel(apiClient: WorkspaceAPIClient.current, model: model, userProfile: userProfile, eventHandler: eventHandler, onSuccess: onSuccess)
        let view = CreateStreamView(viewModel: viewModel)
        return view
    }
}
