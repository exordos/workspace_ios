//
//  ProfileView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

enum ProfileRoute: Hashable {
    case ownUserSettings
    case visualSettings
    case folderSettings
    case login(isFirstOrganization: Bool)
    case otp(login: String, password: String)
    case projects
}

struct ProfileView: View {

    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            VStack(alignment: .leading) {
                personalInformationView
                descriptionView
                settingsView
                Button {
                    viewModel.logout()
                } label: {
                    Text("Выйти")
                }
                .padding(.horizontal, 12.0)
                .accentColor(Color.indicatorRed)
                Spacer()
            }
            .navigationTitle("Мой профиль")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .ownUserSettings:
                    OwnUserSettingsAssembly().assemble()
                case .folderSettings:
                    FolderSettingsAssembly().assemble()
                case .visualSettings:
                    VisualSettingsAssembly().assemble()
                case .login:
                    LogInAssembly().assemble(with: viewModel.userProfile)
                case let .otp(login, password):
                    OtpAssembly().assemble(login: login, password: password, userProfile: viewModel.userProfile) {
                        viewModel.path.append(ProfileRoute.projects)
                    }
                case .projects:
                    ProjectsAssembly().assemble(with: viewModel.userProfile)
                }
            }
        }
    }

    var personalInformationView: some View {
        HStack {
            AvatarView(avatarUrn: viewModel.eventHandler.ownUser?.avatar, baseUrl: viewModel.userProfile.selectedServer?.baseUrl ?? "", color: nil, name: viewModel.eventHandler.ownUser?.displayableName ?? "", enhanceImageRequest: viewModel.apiClient.addHeaders)
                .frame(width: 64.0, height: 64.0)
                .clipShape(Circle())
                .padding(EdgeInsets(top: 12.0, leading: 8.0, bottom: 12.0, trailing: 12.0))
            VStack(alignment: .leading, spacing: 8.0) {
                Text(viewModel.eventHandler.ownUser?.displayableName ?? "")
                    .foregroundStyle(Color.textHeaders)
                    .font(.system(size: 20, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("В сети")
                    .foregroundStyle(Color.indicatorGreen)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
        }
    }

    var descriptionView: some View {
        Group {
            Text("ОПИСАНИЕ")
                .foregroundStyle(Color.textAdditional30)
                .font(.system(size: 14))
            SettingsItem(imageName: "personalInfo", title: "Личная информация") {
                viewModel.path.append(ProfileRoute.ownUserSettings)
            }
        }
        .padding(.horizontal, 12.0)
    }

    var settingsView: some View {
        Group {
            Text("НАСТРОЙКИ")
                .foregroundStyle(Color.textAdditional30)
                .font(.system(size: 14))
            SettingsItem(imageName: "folderSettings", title: "Отображение папок") {
                viewModel.path.append(ProfileRoute.folderSettings)
            }
            SettingsItem(imageName: "appearance", title: "Внешний вид") {
                viewModel.path.append(ProfileRoute.visualSettings)
            }
        }
        .padding(.horizontal, 12.0)
    }
}

struct SettingsItem: View {

    let imageName: String
    let title: String
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(imageName)
                    .padding(EdgeInsets(top: 6.0, leading: 0.0, bottom: 6.0, trailing: 8.0))
                Text(title)
                    .foregroundStyle(Color.textHeaders)
                    .font(.system(size: 14))
            }
            Divider()
                .background(Color.line10)
        }
        .onTapGesture {
            onTap()
        }
    }
}
