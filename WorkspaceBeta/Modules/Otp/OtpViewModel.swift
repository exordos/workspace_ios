//
//  OtpViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class OtpViewModel: ObservableObject {

    @Published private(set) var model: Otp
    private let apiClient: APIClient
    private let userProfile: UserProfile
    var onSuccess: () -> Void

    init(apiClient: APIClient, model: Otp, userProfile: UserProfile, onSuccess: @escaping () -> Void) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
        self.onSuccess = onSuccess
    }

    @Published var loadingState: LoadingState = .loaded
    @Published var enteredCodeError: LocalizedStringKey?
    @Published var actionErrorResult: LocalizedStringKey?
    private var isValidating = false
    @Published var hasActionError = false
    private var cancellables: Set<AnyCancellable> = []

    @Published var enteredCode = ""
    {
        didSet {
            if enteredCode.count == 6, oldValue.count == 5, !isValidating {
                validateCode()
            }
        }
    }

    func validateCode() {
        loadingState = .loading
        apiClient.createPublisher(for: UserLogInRequest(with: model.login, password: model.password, otp: enteredCode))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                if case let .failure(error) = completion {
                    self.hasActionError = true
                    self.enteredCodeError = "Код введён неверно"
                    self.loadingState = .loaded
                }
            } receiveValue: { [weak self] response in
                self?.userProfile.refreshToken = response.refreshToken
                self?.userProfile.accessToken = response.accessToken
                self?.onSuccess()
            }
            .store(in: &cancellables)
    }
}
