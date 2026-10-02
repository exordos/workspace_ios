//
//  ProjectsViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class ProjectsViewModel: ObservableObject {

    @Published private(set) var model: Projects
    private let apiClient: APIClient
    let userProfile: UserProfile
    @Published var loadingState: LoadingState = .initialized
    @Published var selectProjectLoadingState: LoadingState = .initialized

    private var cancellables: Set<AnyCancellable> = []

    init(apiClient: APIClient, model: Projects, userProfile: UserProfile) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
    }

    func onAppear() {
        loadProjects()
    }

    func loadProjects() {
        loadingState = .loading
        apiClient.createPublisher(for: ProjectsRequest())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
                self?.loadingState = .loaded
            } receiveValue: { [weak self] response in
                guard let self else { return }
                model.projects = response
                self.loadingState = .loaded
            }
            .store(in: &cancellables)
    }

    func onTap(on project: ProjectResponseData) {
        selectProjectLoadingState = .loading

        apiClient.createPublisher(for: RefreshTokenRequest(with: userProfile.refreshToken ?? "", scope: "openid email profile project:\(project.uuid)"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
                self?.selectProjectLoadingState = .loaded
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.userProfile.refreshToken = response.refreshToken
                self.userProfile.accessToken = response.accessToken
                self.userProfile.selectedServer?.projectUuid = project.uuid
                self.selectProjectLoadingState = .loaded
            }
            .store(in: &cancellables)
    }

}

// MARK: - Additional API
public extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Int) async throws {
        try await sleep(nanoseconds: UInt64(seconds) * NSEC_PER_SEC)
    }

    static func sleep(seconds: UInt64) async throws {
        try await sleep(nanoseconds: seconds * NSEC_PER_SEC)
    }

    static func sleep(seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * Double(NSEC_PER_SEC)))
    }
}
