//
//  VoiceCallViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class VoiceCallViewModel: ObservableObject {

    @Published private(set) var model: VoiceCall
    private let apiClient: APIClient

    init(apiClient: APIClient, model: VoiceCall) {
        self.apiClient = apiClient
        self.model = model
    }
}
