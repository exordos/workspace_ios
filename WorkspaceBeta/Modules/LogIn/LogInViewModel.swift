//
//  LogInViewModel.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 22.02.2026.
//

import SwiftUI
import Combine

protocol LogInViewModelProtocol {

}

class LogInViewModel: LogInViewModelProtocol, ObservableObject {

    private let apiClient: APIClient
    @Published var model: LogIn
    @Published var urlToShow: URL?
    @Published var forgotPassword = false
    let userProfile: UserProfile
    private var forgottenEmailString: String?
    @Published var shouldShowConfirmEmailScene = false
    @Published var shouldShowEnterPhoneScene = false
    @Published var shouldShowEnterCodeScene = false

//    @Published var temporaryLoginUserInfo: LoginResponseUserInfo?
    var emailTimeout: Date?
    var supportPhone: String?
    var supportEmails: [String]?

    let loginFieldViewModel = CommonInputViewModel(with: "Логин", isRequired: false, keyBoardType: .emailAddress, textContentType: .username)

    let passwordFieldViewModel = CommonInputViewModel(with: "Пароль", isRequired: false, isPassword: true, textContentType: .password)

    struct Constants {
        static let unauthorizedKey = "unauthorized"
    }

    private var cancellables: Set<AnyCancellable> = []


    init(apiClient: APIClient, model: LogIn, userProfile: UserProfile) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
    }

    func onAppear() {
    }

    func onError() {
        clearData()
    }

    func clearData() {
        userProfile.clearData()
        shouldShowEnterCodeScene = false
        shouldShowEnterPhoneScene = false
        shouldShowConfirmEmailScene = false
        model.login = ""
        model.password = ""
    }

    func signIn() {
        model.login = model.login.trimmingCharacters(in: .whitespacesAndNewlines)
        apiClient.createPublisher(for: UserLogInRequest(with: model.login, password: model.password))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                self?.userProfile.userId = response.userId
                self?.userProfile.userEmail = response.email
                self?.userProfile.apiKey = response.apiKey
            }
            .store(in: &cancellables)
    }
}
