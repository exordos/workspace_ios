//
//  CalendarViewModel.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 24.02.2026.
//  
//

import SwiftUI
import Combine

final class CalendarViewModel: ObservableObject {

    @Published private(set) var model: Calendar
    private let apiClient: APIClient

    init(apiClient: APIClient, model: Calendar) {
        self.apiClient = apiClient
        self.model = model
    }
}
