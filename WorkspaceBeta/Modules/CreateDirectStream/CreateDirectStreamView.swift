//
//  CreateDirectStreamView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

struct CreateDirectStreamView: View {

    @ObservedObject var viewModel: CreateDirectStreamViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(viewModel.users, id:\.self) { user in
                    DirectUserView(user: user, viewModel: viewModel)
                }
            }
        }
    }
}

struct DirectUserView: View {

    let user: UserResponseData
    let viewModel: CreateDirectStreamViewModel

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
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
        .onTapGesture {
            viewModel.onTap(on: user)
        }
        .padding(.horizontal, 12.0)
    }
}
