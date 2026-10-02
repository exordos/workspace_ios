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

    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            VStack(alignment: .center) {
                Text("Добро пожаловать")
                    .font(.system(size: 16.0, weight: .medium))
                    .foregroundStyle(Color.textHeaders)
                Text("Введите адрес вашей организации,\nчтобы продолжить")
                    .font(.system(size: 14.0))
                    .foregroundStyle(Color.textHeaders)
                    .multilineTextAlignment(.center)
                    .padding(EdgeInsets(top: 8.0, leading: 20.0, bottom: 64.0, trailing: 20.0))
                CommonInputView(viewModel: viewModel.baseUrlFieldViewModel, text: $viewModel.model.baseUrl)
                PrimaryButton(title: "Добавить") {
                    viewModel.checkServerSettings()
                }
                .padding(.bottom, 20.0)
                HStack {
                    Color.line10
                        .frame(height: 1.0)
                    Text("или")
                        .font(.system(size: 14.0, weight: .medium))
                        .foregroundStyle(Color.textHeaders)
                        .padding(.horizontal, 10.0)
                    Color.line10
                        .frame(height: 1.0)

                }
                VStack(alignment: .leading) {
                    Text("Вы можете подключиться к нашему публичному серверу:")
                        .font(.system(size: 14.0, weight: .medium))
                        .foregroundStyle(Color.textHeaders)
                    HStack(spacing: .zero) {
                        Image("serverIcon")
                            .resizable()
                            .frame(width: 36.0, height: 36.0)
                            .padding(8.0)
                        Text("Exordos public")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textHeaders)
                        Spacer()
                    }
                    .onTapGesture {
                        viewModel.setDefaultServerUrl()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.searchBackground)
                    .clipShape(RoundedCorner(radius: 8.0))
                }
                .padding(.vertical, 16.0)
            }
            .padding(.horizontal, 16.0)
            Spacer()
        }
        .background(Color.background)
        .showLoader(viewModel.loadingState == .loading)
        .navigationBarHidden(true)
        .background(Color.background)
    }
}
