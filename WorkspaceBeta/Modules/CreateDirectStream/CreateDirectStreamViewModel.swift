//
//  CreateDirectStreamViewModel.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

final class CreateDirectStreamViewModel: ObservableObject {

    @Published private(set) var model: CreateDirectStream
    private(set) var apiClient: APIClient
    let userProfile: UserProfile
    private(set) var eventHandler: EventHandler
    var onSuccess: (String, String) -> Void

    private var cancellables: Set<AnyCancellable> = []

    init(apiClient: APIClient, model: CreateDirectStream, userProfile: UserProfile, eventHandler: EventHandler, onSuccess: @escaping (String, String) -> Void) {
        self.apiClient = apiClient
        self.model = model
        self.userProfile = userProfile
        self.eventHandler = eventHandler
        self.onSuccess = onSuccess

    }

    func onTap(on user: UserData) {
        apiClient.createPublisher(for: AddStreamRequest(with: user.displayableName, description: user.username, directUserUuid: user.uuid, isEncrypted: false, currentEncryptionKeyUuid: nil))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    // Error
                }
            } receiveValue: { [weak self] response in
                self?.onSuccess(response.uuid, response.defaultTopicUuid ?? "")
            }
            .store(in: &cancellables)

    }
}
