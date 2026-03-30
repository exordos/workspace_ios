//
//  VoiceCallAssembly.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 24.02.2026.
//  
//

import SwiftUI

struct VoiceCallAssembly {

    func assemble() -> some View {
        let model = VoiceCall()
        let viewModel = VoiceCallViewModel(apiClient: WorkspaceAPIClient.current, model: model)
        let view = VoiceCallView(viewModel: viewModel)
        return view
    }

    func view(from viewModel: VoiceCallViewModel) -> some View {
        let view = VoiceCallView(viewModel: viewModel)
        return view
    }
}
