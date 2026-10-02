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
    private let apiClient: APIClient

    init(apiClient: APIClient, model: StreamInfo) {
        self.apiClient = apiClient
        self.model = model
    }
}
