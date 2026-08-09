//
//  LogInView.swift
//  WorkspaceBeta
//
//

import SwiftUI

struct LogInView: View {

    private struct Appearance {
        static let supportElementsSpacing: CGFloat = 2.0
    }

    @ObservedObject var viewModel: LogInViewModel
    @Environment(\.presentationMode) var presentationMode

    @State var needToRegister = false

    var body: some View {
        NavigationView {
            VStack(alignment: .center) {
                Image("serverIcon")
                    .resizable()
                    .frame(width: 116, height: 116)
                    .padding(.top, 100)
                title
                organizationUrl
                loginField
                    .padding(.top, 24)
                passwordField
                    .padding(.top, 24)

                if viewModel.needsOtp {
                    otpField
                        .padding(.top, 24)
                }

                signInButton
                    .padding(.top, 24)
                logoutButton
                    .padding(.vertical, 10.0)
                Spacer()
            }
            .padding(.horizontal, 16)
            .edgesIgnoringSafeArea(.horizontal)
            .navigationBarHidden(true)
            .showLoader(viewModel.loadingState == .loading)
            .onTapGesture {
                UIApplication.shared.endEditing()
            }
            .onAppear {
                viewModel.onAppear()
            }
        }
//        .accentColor(Color.primary500)
    }

    var title: some View {
        Text("Название организации")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Color.textHeaders)
            .padding(.vertical, 10.0)
    }

    var organizationUrl: some View {
        Text(viewModel.userProfile.baseUrl ?? "")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Color.textAdditional50)
            .padding(.vertical, 10.0)
            .padding(.horizontal, 20.0)
    }

    var loginField: some View {
        CommonInputView(viewModel: viewModel.loginFieldViewModel, text: $viewModel.model.login)
    }

    var passwordField: some View {
        CommonInputView(viewModel: viewModel.passwordFieldViewModel, text: $viewModel.model.password)
    }

    var otpField: some View {
        CommonInputView(viewModel: viewModel.otpFieldViewModel, text: $viewModel.model.otp)
    }

    var signInButton: some View {
        PrimaryButton(title: "Логин", action: viewModel.signIn)
            .accessibilityIdentifier("loginButton")
    }

    var logoutButton: some View {
        DestructiveButton(title: "Выйти из организации") {
            presentationMode.wrappedValue.dismiss()
        }
    }
}


extension UIApplication {

    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
