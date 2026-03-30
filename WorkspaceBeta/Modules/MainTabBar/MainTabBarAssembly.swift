//
//  MainTabBarAssembly.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 24.02.2026.
//

import SwiftUI

struct MainTabBarAssembly {

    func assemble(with viewModel: MainTabBarViewModel) -> some View {
        let view = MainTabBarView(viewModel: viewModel, userProfile: viewModel.userProfile)
        return view
    }
}
