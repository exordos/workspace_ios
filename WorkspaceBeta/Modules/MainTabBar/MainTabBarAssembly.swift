//
//  MainTabBarAssembly.swift
//  WorkspaceBeta
//
//

import SwiftUI

struct MainTabBarAssembly {

    func assemble(with viewModel: MainTabBarViewModel) -> some View {
        let view = MainTabBarView(viewModel: viewModel, userProfile: viewModel.userProfile)
        return view
    }
}
