//
//  ProfileView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

struct ProfileView: View {

    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        VStack {
            Button {
                viewModel.logout()
            } label: {
                Text("Выйти")
            }

        }
    }
}
