//
//  OtpAssembly.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI

struct OtpAssembly {

    func assemble(login: String, password: String, userProfile: UserProfile, onSuccess: @escaping () -> Void) -> some View {
        let model = Otp(login: login, password: password)
        let viewModel = OtpViewModel(apiClient: WorkspaceAPIClient.current, model: model, userProfile: userProfile, onSuccess: onSuccess)
        let view = OtpView(viewModel: viewModel)
        return view
    }
}
