//
//  CalendarAssembly.swift
//  WorkspaceBeta
//
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
