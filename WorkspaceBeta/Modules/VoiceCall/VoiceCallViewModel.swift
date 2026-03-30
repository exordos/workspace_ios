//
//  VoiceCallViewModel.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 24.02.2026.
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
