//
//  ChooseServerView.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 25.03.2026.
//  
//

import SwiftUI
import Combine

struct ChooseServerView: View {

    @ObservedObject var viewModel: ChooseServerViewModel

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .center) {
                VStack {
                    Text("Добавить организацию")
                    Text("Укажите ссылку на организацию, чтобы добавить её в список")
                    CommonInputView(viewModel: viewModel.baseUrlFieldViewModel, text: $viewModel.model.baseUrl)
                    Text("Или можете подключиться к нашему публичному сервису")
                    Button {
                        viewModel.setDefaultServerUrl()
                    } label: {
                        Label {
                            Text("Genesis core public")
                                .foregroundStyle(Color.textHeaders)
                        } icon: {
                            Image("serverIcon")
                                .resizable()
                                .frame(width: 36.0, height: 36.0)
                        }
                    }
                    PrimaryButton(title: "Добавить") {
                        viewModel.applyBaseServerUrl()
                        path.append("login")
                    }
                }
            }
            .navigationDestination(for: String.self) { value in
                if value == "login" {
                    LogInAssembly().assemble(with: viewModel.userProfile)
                }
            }
            .navigationBarHidden(true)
        }
        .background(Color.background)
    }
}
