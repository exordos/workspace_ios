//
//  ChooseServerViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class ChooseServerViewModel: ObservableObject {

    @Published var model: ChooseServer
    private let apiClient: APIClient
    let userProfile: UserProfile
    private var cancellables: Set<AnyCancellable> = []

    let baseUrlFieldViewModel = CommonInputViewModel(with: "Ссылка на организацию", isRequired: false, keyBoardType: .emailAddress, textContentType: .username)

    @Published var path = NavigationPath()

    @Published var loadingState: LoadingState = .initialized

    init(apiClient: APIClient, model: ChooseServer, userProfile: UserProfile) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
    }


    func setDefaultServerUrl() {
        model.baseUrl = "https://workspace.exordos.com"
    }

    func applyBaseServerUrl() {
        userProfile.baseUrl = model.baseUrl
    }

    func checkServerSettings() {
        ensureHttpPrefix(in: &model.baseUrl)
        loadingState = .loading
        apiClient.createPublisher(for: ServerSettingsRequest(with: model.baseUrl))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
                self?.loadingState = .loaded
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.userProfile.baseUrl = self.model.baseUrl
                self.loadingState = .loaded
                self.path.append("login")
            }
            .store(in: &cancellables)
    }

    func ensureHttpPrefix(in url: inout String) {

    }
}
