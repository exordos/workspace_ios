//
//  HomeDraftsViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class HomeDraftsViewModel: ObservableObject {

    @Published private(set) var model: HomeDrafts
    private let apiClient: APIClient
    let userProfile: UserProfile
    private(set) var eventHandler: EventHandler

    init(apiClient: APIClient, model: HomeDrafts, userProfile: UserProfile, eventHandler: EventHandler) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
        self.eventHandler = eventHandler
    }
}
