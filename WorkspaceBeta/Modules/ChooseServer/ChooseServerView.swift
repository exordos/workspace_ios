//
//  ChooseServerView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

struct ChooseServerView: View {

    @ObservedObject var viewModel: ChooseServerViewModel

//    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            VStack(alignment: .center) {
                Spacer()
                VStack(alignment: .center) {
                    Text("Добавить организацию")
                        .font(.system(size: 16.0, weight: .medium))
                        .foregroundStyle(Color.textHeaders)
                        .padding(20.0)
                    Text("Укажите ссылку на организацию, чтобы добавить её в список")
                        .font(.system(size: 14.0))
                        .foregroundStyle(Color.textHeaders)
                        .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 12.0, trailing: 20.0))
                    CommonInputView(viewModel: viewModel.baseUrlFieldViewModel, text: $viewModel.model.baseUrl)
                    Text("Или можете подключиться к нашему публичному сервису")
                        .font(.system(size: 14.0, weight: .medium))
                        .foregroundStyle(Color.textHeaders)
                        .padding(20.0)
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
                    .padding(20.0)
                    PrimaryButton(title: "Добавить") {
                        viewModel.checkServerSettings()
                    }
                    .padding(.bottom, 20.0)
                }
                .padding(.horizontal, 16.0)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20.0))
                .padding(.horizontal, 16.0)
                Spacer()
            }
            .background(Color.background)
            .navigationDestination(for: String.self) { value in
                if value == "login" {
                    LogInAssembly().assemble(with: viewModel.userProfile)
                }
            }
            .showLoader(viewModel.loadingState == .loading)
            .navigationBarHidden(true)
        }
        .background(Color.background)
    }
}
