//
//  StreamSettingsView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

struct StreamSettingsView: View {

    @ObservedObject var viewModel: StreamSettingsViewModel

    var body: some View {
        VStack {
            SettingsItem(imageName: "key", title: "Ключ шифрования") {
                viewModel.onKeySettingsButtonTap()
            }
            Spacer()
        }
        .padding(.horizontal, 12.0)
    }
}
