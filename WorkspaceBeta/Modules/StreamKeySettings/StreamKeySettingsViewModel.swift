//
//  StreamKeySettingsViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class StreamKeySettingsViewModel: ObservableObject {

    @Published private(set) var model: StreamKeySettings
    private let apiClient: APIClient
    private let eventHandler: EventHandler
    private var cancellables: Set<AnyCancellable> = []
    let userProfile: UserProfile

    init(apiClient: APIClient, model: StreamKeySettings, eventHandler: EventHandler) {
        self.apiClient = apiClient
        self.model = model
        self.eventHandler = eventHandler
        self.userProfile = eventHandler.userProfile
    }
}
