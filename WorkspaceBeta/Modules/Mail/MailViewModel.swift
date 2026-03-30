//
//  MailViewModel.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 24.02.2026.
//  
//

import SwiftUI
import Combine

final class MailViewModel: ObservableObject {

    @Published private(set) var model: Mail
    private let apiClient: APIClient

    init(apiClient: APIClient, model: Mail) {
        self.apiClient = apiClient
        self.model = model
    }
}
