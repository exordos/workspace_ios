//
//  StreamSettingsAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct StreamSettingsAssembly {

    func assemble(streamUuid: String, topicUuid: String, eventHandler: EventHandler, onKeySettingsButtonTap: @escaping () -> Void) -> some View {
        let model = StreamSettings(streamUuid: streamUuid, topicUuid: topicUuid)
        let viewModel = StreamSettingsViewModel(apiClient: WorkspaceAPIClient.current, model: model, eventHandler: eventHandler, onKeySettingsButtonTap: onKeySettingsButtonTap)
        let view = StreamSettingsView(viewModel: viewModel)
        return view
    }
}
