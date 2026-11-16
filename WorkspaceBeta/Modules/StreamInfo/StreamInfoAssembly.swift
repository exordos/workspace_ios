//
//  StreamInfoAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct StreamInfoAssembly {

    func assemble(streamUuid: String, topicUuid: String, eventHandler: EventHandler, onSettingsButtonTap: @escaping () -> Void) -> some View {
        let model = StreamInfo(streamUuid: streamUuid, topicUuid: topicUuid)
        let viewModel = StreamInfoViewModel(apiClient: WorkspaceAPIClient.current, model: model, eventHandler: eventHandler, onSettingsButtonTap: onSettingsButtonTap)
        let view = StreamInfoView(viewModel: viewModel, streamUuid: streamUuid)
        return view
    }
}
