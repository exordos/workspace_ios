//
//  CalendarAssembly.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 24.02.2026.
//  
//

import SwiftUI

struct CalendarAssembly {

    func assemble() -> some View {
        let model = Calendar()
        let viewModel = CalendarViewModel(apiClient: WorkspaceAPIClient.current, model: model)
        let view = CalendarView(viewModel: viewModel)
        return view
    }

    func view(from viewModel: CalendarViewModel) -> some View {
        let view = CalendarView(viewModel: viewModel)
        return view
    }
}
