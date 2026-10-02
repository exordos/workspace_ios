//
//  CreationBaseViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class CreationBaseViewModel: ObservableObject {

    @Published private(set) var model: CreationBase
    private let apiClient: APIClient
    var onDirectTap: () -> Void
    var onStreamTap: () -> Void

    init(apiClient: APIClient, model: CreationBase, onDirectTap: @escaping () -> Void, onStreamTap: @escaping () -> Void) {
        self.apiClient = apiClient
        self.model = model
        self.onDirectTap = onDirectTap
        self.onStreamTap = onStreamTap
    }
}
