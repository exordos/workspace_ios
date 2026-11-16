//
//  HomeInboundsViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import SwiftData
import Combine

final class HomeInboundsViewModel: ObservableObject {

    @Published private(set) var model: HomeInbounds
    private(set) var apiClient: APIClient
    let userProfile: UserProfile
    private(set) var eventHandler: EventHandler
    @Published var loadingState: LoadingState = .initialized
    @Query var streams: [StreamData]

    private var cancellables: Set<AnyCancellable> = []

    @Published var streamTopics: [String:[TopicResponseData]] = [:]
    @Published var poolMessages: [MessageResponseData] = []

    init(apiClient: APIClient, model: HomeInbounds, userProfile: UserProfile, eventHandler: EventHandler) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
        self.eventHandler = eventHandler
    }

    func onAppear() {

        loadingState = .loading

        let unreadStreamUuids = streams.filter { $0.activeUnreadCount > 0 }.map { $0.uuid }
        let streamWithLoadedTopicsUuids = Array(streamTopics.keys)
        let unreadStreamUuidsToLoadTopics = unreadStreamUuids.filter {  !streamWithLoadedTopicsUuids.contains($0) }
        if unreadStreamUuidsToLoadTopics.count > 0 {
//            loadTopics(for: unreadStreamUuidsToLoadTopics)
        } else {
            loadingState = .loaded
        }
    }
}
