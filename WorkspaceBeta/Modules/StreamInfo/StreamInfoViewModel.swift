//
//  StreamInfoViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class StreamInfoViewModel: ObservableObject {

    @Published private(set) var model: StreamInfo
    private(set) var apiClient: APIClient
    private let eventHandler: EventHandler
    private var cancellables: Set<AnyCancellable> = []
    let userProfile: UserProfile
    private(set) var onSettingsButtonTap: () -> Void

    init(apiClient: APIClient, model: StreamInfo, eventHandler: EventHandler, onSettingsButtonTap: @escaping () -> Void) {
        self.apiClient = apiClient
        self.model = model
        self.eventHandler = eventHandler
        self.userProfile = eventHandler.userProfile
        self.onSettingsButtonTap = onSettingsButtonTap
    }
}
