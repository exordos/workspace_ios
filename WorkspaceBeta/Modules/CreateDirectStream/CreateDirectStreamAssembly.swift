//
//  CreateDirectStreamAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct CreateDirectStreamAssembly {

    func assemble(with userProfile: UserProfile, eventHandler: EventHandler, onSuccess: @escaping (String, String) -> Void) -> some View {
        let model = CreateDirectStream()
        let viewModel = CreateDirectStreamViewModel(apiClient: WorkspaceAPIClient.current, model: model, userProfile: userProfile, eventHandler: eventHandler, onSuccess: onSuccess)
        let view = CreateDirectStreamView(viewModel: viewModel)
        return view
    }
}
