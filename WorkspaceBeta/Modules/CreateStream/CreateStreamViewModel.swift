//
//  CreateStreamViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class CreateStreamViewModel: ObservableObject {

    @Published var model: CreateStream
    private(set) var apiClient: APIClient
    let userProfile: UserProfile
    private(set) var eventHandler: EventHandler
    @Published var users: [UserResponseData]
    var onSuccess: (String, String) -> Void

    private var cancellables: Set<AnyCancellable> = []

    let streamNameFieldViewModel = CommonInputViewModel(with: "Название стрима", isRequired: false, isPassword: false)

    init(apiClient: APIClient, model: CreateStream, userProfile: UserProfile, eventHandler: EventHandler, onSuccess: @escaping (String, String) -> Void) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
        self.eventHandler = eventHandler
        self.users = eventHandler.users
        self.onSuccess = onSuccess

        subscribeToEvents()
    }

    func subscribeToEvents() {
        eventHandler.usersPublisher
            .assign(to: &$users)
    }

    func createButtonTapped() {
        apiClient.createPublisher(for: AddStreamRequest(with: model.streamName, description: "", directUserUuid: nil))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] streamCreationResponse in
                guard let self else { return }
                let members = model.selectedUsers.map { $0.uuid }
                apiClient.createPublisher(for: AddUsersToStreamRequest(with: streamCreationResponse.uuid, members: members))
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] completion in
                        if case let .failure(error) = completion {
                            // Error
                        }
                    } receiveValue: { [weak self] response in
                        self?.onSuccess(streamCreationResponse.uuid, streamCreationResponse.defaultTopicUuid ?? "")
                    }
                    .store(in: &self.cancellables)
            }
            .store(in: &cancellables)
    }

    func userCheckboxCheck(user: UserResponseData) {
        if let index = model.selectedUsers.firstIndex(of: user) {
            model.selectedUsers.remove(at: index)
        } else {
            model.selectedUsers.append(user)
        }
    }
}
