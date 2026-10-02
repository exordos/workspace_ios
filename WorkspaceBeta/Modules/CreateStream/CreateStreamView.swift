//
//  CreateStreamView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

struct CreateStreamView: View {

    @ObservedObject var viewModel: CreateStreamViewModel

    var body: some View {
        VStack {
            CommonInputView(viewModel: viewModel.streamNameFieldViewModel, text: $viewModel.model.streamName)
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(viewModel.users, id:\.self) { user in
                        StreamUserView(user: user, viewModel: viewModel)
                    }
                }
            }
            PrimaryButton(title: "Создать", action: viewModel.createButtonTapped)
        }
        .padding(.horizontal, 12.0)
    }
}

struct StreamUserView: View {

    let user: UserResponseData
    @ObservedObject var viewModel: CreateStreamViewModel

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Button {
                    viewModel.userCheckboxCheck(user: user)
                } label: {
                    ZStack {
                        Image(viewModel.model.selectedUsers.contains(user) ? "checkboxOn" : "checkboxOff")
                            .accentColor(Color.primary)
                        if viewModel.model.selectedUsers.contains(user) {
                            Image("checkboxTick")
                        }
                    }
                    .padding(.trailing, 8.0)
                }

                AvatarView(avatarUrn: user.avatar, baseUrl: viewModel.userProfile.selectedServer?.baseUrl ?? "", color: nil, name: user.displayableName, enhanceImageRequest: viewModel.apiClient.addHeaders)
                    .frame(width: 40.0, height: 40.0)
                    .clipShape(Circle())
                    .padding(.trailing, 4.0)
                VStack(alignment: .leading) {
                    Text(user.displayableName)
                        .font(.system(size: 14.0))
                        .foregroundStyle(Color.textHeaders)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let email = user.email {
                        Text(email)
                            .font(.system(size: 14.0))
                            .foregroundStyle(Color.textAdditional30)
                    }
                }
            }
            Divider()
                .background(Color.line10)
        }
    }
}
