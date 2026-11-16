//
//  StreamSettingsViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class StreamSettingsViewModel: ObservableObject {

    @Published private(set) var model: StreamSettings
    private let apiClient: APIClient
    private let eventHandler: EventHandler
    private var cancellables: Set<AnyCancellable> = []
    let userProfile: UserProfile
    private(set) var onKeySettingsButtonTap: () -> Void

    init(apiClient: APIClient, model: StreamSettings, eventHandler: EventHandler, onKeySettingsButtonTap: @escaping () -> Void) {
        self.apiClient = apiClient
        self.model = model
        self.eventHandler = eventHandler
        self.userProfile = eventHandler.userProfile
        self.onKeySettingsButtonTap = onKeySettingsButtonTap
    }
}
