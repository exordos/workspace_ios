//
//  StreamKeySettingsAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct StreamKeySettingsAssembly {

    func assemble(streamUuid: String, topicUuid: String, eventHandler: EventHandler) -> some View {
        let model = StreamKeySettings(streamUuid: streamUuid, topicUuid: topicUuid)
        let viewModel = StreamKeySettingsViewModel(apiClient: WorkspaceAPIClient.current, model: model, eventHandler: eventHandler)
        let view = StreamKeySettingsView(viewModel: viewModel)
        return view
    }
}
