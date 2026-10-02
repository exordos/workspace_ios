//
//  MainTabBar.swift
//  WorkspaceBeta
//
//

import Foundation
import SwiftUI

struct MainTabBar {
    enum Tab: LocalizedStringKey, CaseIterable {
        case home 
        case chat = "Чат"
        case profile = "Профиль"
    }
}
