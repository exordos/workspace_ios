//
//  HomeDraftsView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

struct HomeDraftsView: View {

    @ObservedObject var viewModel: HomeDraftsViewModel

    var body: some View {
        Text("Здесь будут черновики")
            .navigationTitle("Черновики")
            .navigationBarTitleDisplayMode(.inline)
    }
}
