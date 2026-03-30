//
//  LogInView.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 22.02.2026.
//

import SwiftUI

struct LogInView: View {

    private struct Appearance {
        static let supportElementsSpacing: CGFloat = 2.0
    }

    @ObservedObject var viewModel: LogInViewModel

    @State var needToRegister = false

    var body: some View {
        NavigationView {
            ZStack(alignment: .topLeading) {
                background
                .edgesIgnoringSafeArea(.top)
                VStack(alignment: .leading) {
                    Image("logo")
                        .padding(.leading, -16)
                    title
                        .padding(.top, 24)
                    loginField
                        .padding(.top, 24)
                    passwordField
                        .padding(.top, 24)
                    signInButton
                        .padding(.top, 24)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .edgesIgnoringSafeArea(.horizontal)
            .navigationBarHidden(true)
            .onTapGesture {
                UIApplication.shared.endEditing()
            }
            .onAppear {
                viewModel.onAppear()
            }
        }
//        .accentColor(Color.primary500)
    }

    var background: some View {
        VStack(alignment: .trailing) {
            Image("backgroundNeutral")
                .resizable()
                .aspectRatio(contentMode: .fit)
            Spacer()
        }
    }

    var title: some View {
        Text(String.title)
//            .font(DesignSystemFont.semibold32Display)
//            .foregroundColor(Color.neutral900)
    }

    var loginField: some View {
        CommonInputView(viewModel: viewModel.loginFieldViewModel, text: $viewModel.model.login)
    }

    var passwordField: some View {
        CommonInputView(viewModel: viewModel.passwordFieldViewModel, text: $viewModel.model.password)
    }

    var signInButton: some View {
        PrimaryButton(title: "login_button", action: viewModel.signIn)
            .accessibilityIdentifier("loginButton")
    }
}

// MARK: - Localization
private extension String {
    static let title = NSLocalizedString("login_title", comment: "Заголовок экрана входа")
    static let forgotPasswordTitle = NSLocalizedString("login_forgot_password", comment: "Кнопка для перехода на экран восстановления пароля")
    static let signInButton = NSLocalizedString("login_button", comment: "Кнопка входа в аккаунт")
}



extension UIApplication {

    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
