//
//  HomeViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class HomeViewModel: ObservableObject {

    @Published private(set) var model: Home
    private let apiClient: APIClient
    let userProfile: UserProfile
    private(set) var eventHandler: EventHandler

    init(apiClient: APIClient, model: Home, userProfile: UserProfile, eventHandler: EventHandler) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
        self.eventHandler = eventHandler
    }

    func onAppear() {
        eventHandler.loadServerSettings()
    }
}
