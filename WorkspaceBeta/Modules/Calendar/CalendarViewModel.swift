//
//  CalendarViewModel.swift
//  WorkspaceBeta
//
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
