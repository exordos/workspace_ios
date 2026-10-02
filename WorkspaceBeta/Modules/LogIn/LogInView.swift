//
//  LogInView.swift
//  WorkspaceBeta
//
//

import SwiftUI

enum LoginRoute: Hashable {
    case login
    case otp(login: String, password: String)
    case projects
}


struct LogInView: View {

    private struct Appearance {
        static let supportElementsSpacing: CGFloat = 2.0
    }

    @ObservedObject var viewModel: LogInViewModel
    @Environment(\.presentationMode) var presentationMode

    @State var needToRegister = false

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            VStack(alignment: .center) {
                if let imageUrl = viewModel.userProfile.selectedServer?.imageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .frame(width: 116, height: 116)
                    } placeholder: {
                        Image("serverIcon")
                            .resizable()
                            .frame(width: 116, height: 116)
                    }
                    .padding(.top, 100)
                } else {
                    Image("serverIcon")
                        .resizable()
                        .frame(width: 116, height: 116)
                        .padding(.top, 100)
                }
                title
                organizationUrl
                loginField
                    .padding(.top, 12)
                passwordField
                signInButton
                    .padding(.top, 24)
                logoutButton
                    .padding(.vertical, 12.0)
                Spacer()
            }
            .padding(.horizontal, 16)
            .edgesIgnoringSafeArea(.horizontal)
            .navigationBarHidden(true)
            .navigationDestination(for: LoginRoute.self) { route in
                switch route {
                case .login:
                    LogInAssembly().assemble(with: viewModel.userProfile)
                case let .otp(login, password):
                    OtpAssembly().assemble(login: login, password: password, userProfile: viewModel.userProfile) {
                        viewModel.path.append(LoginRoute.projects)
                    }
                case .projects:
                    ProjectsAssembly().assemble(with: viewModel.projectsViewModel)
                }
            }
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
        Text(viewModel.userProfile.selectedServer?.name ?? "")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Color.textHeaders)
            .padding(.vertical, 10.0)
    }

    var organizationUrl: some View {
        Text(viewModel.userProfile.selectedServer?.baseUrl ?? "")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Color.textAdditional50)
            .padding(.bottom, 12.0)
            .padding(.horizontal, 20.0)
    }

    var loginField: some View {
        CommonInputView(viewModel: viewModel.loginFieldViewModel, text: $viewModel.model.login)
    }

    var passwordField: some View {
        CommonInputView(viewModel: viewModel.passwordFieldViewModel, text: $viewModel.model.password)
    }
    var signInButton: some View {
        PrimaryButton(title: "Войти", action: viewModel.signIn)
            .accessibilityIdentifier("loginButton")
    }

    var logoutButton: some View {
        DestructiveButton(title: "Выйти из организации") {
            viewModel.exitTapped()
        }
    }
}


extension UIApplication {

    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
