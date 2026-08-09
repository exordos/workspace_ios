//
//  LogInViewModel.swift
//  WorkspaceBeta
//
//

import SwiftUI
import Combine

protocol LogInViewModelProtocol {

}

class LogInViewModel: LogInViewModelProtocol, ObservableObject {
    private var apiClient: APIClient
    @Published var model: LogIn
    @Published var urlToShow: URL?
    @Published var forgotPassword = false
    @Published var needsOtp = false
    let userProfile: UserProfile
    private var forgottenEmailString: String?
    @Published var loadingState: LoadingState = .initialized

//    @Published var temporaryLoginUserInfo: LoginResponseUserInfo?
    var emailTimeout: Date?
    var supportPhone: String?
    var supportEmails: [String]?

    let loginFieldViewModel = CommonInputViewModel(with: "Логин", isRequired: false, keyBoardType: .emailAddress, textContentType: .username)

    let passwordFieldViewModel = CommonInputViewModel(with: "Пароль", isRequired: false, isPassword: true, textContentType: .password)

    let otpFieldViewModel = CommonInputViewModel(with: "Otp", isRequired: false, keyBoardType: .numberPad, textContentType: .oneTimeCode)


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
        model.login = ""
        model.password = ""
    }

    func signIn() {
        loadingState = .loading
        model.login = model.login.trimmingCharacters(in: .whitespacesAndNewlines)
        apiClient.createPublisher(for: UserLogInRequest(with: model.login, password: model.password, otp: model.otp))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    if (error as? HTTPError) == .sessionExpired {
                        self?.needsOtp = true
                    }
                    self?.loadingState = .loaded
                }
            } receiveValue: { [weak self] response in
                self?.userProfile.refreshToken = response.refreshToken
                self?.userProfile.accessToken = response.accessToken
            }
            .store(in: &cancellables)
    }
}
