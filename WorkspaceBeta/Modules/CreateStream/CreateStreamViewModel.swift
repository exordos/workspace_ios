//
//  CreateStreamViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine
import CryptoKit

final class CreateStreamViewModel: ObservableObject {

    @Published var model: CreateStream
    private(set) var apiClient: APIClient
    let userProfile: UserProfile
    private(set) var eventHandler: EventHandler
    var onSuccess: (String, String) -> Void

    private var cancellables: Set<AnyCancellable> = []

    let streamNameFieldViewModel = CommonInputViewModel(with: "Название стрима", isRequired: false, isPassword: false)

    init(apiClient: APIClient, model: CreateStream, userProfile: UserProfile, eventHandler: EventHandler, onSuccess: @escaping (String, String) -> Void) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
        self.eventHandler = eventHandler
        self.onSuccess = onSuccess

    }

    func createButtonTapped() {
        let keyUuid = model.isEncrypted ? UUID().uuidString.lowercased() : nil
        apiClient.createPublisher(for: AddStreamRequest(with: model.streamName, description: "", directUserUuid: nil, isEncrypted: model.isEncrypted, currentEncryptionKeyUuid: keyUuid))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] streamCreationResponse in
                guard let self else { return }
                if model.isEncrypted, let keyUuid {
                    userProfile.createGroupKey(keyUuid: keyUuid, userUuid: eventHandler.ownUser?.uuid ?? "", streamUuid: streamCreationResponse.uuid)
                }
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

    func userCheckboxCheck(user: UserData) {
        if let index = model.selectedUsers.firstIndex(of: user) {
            model.selectedUsers.remove(at: index)
        } else {
            model.selectedUsers.append(user)
        }
    }
}
