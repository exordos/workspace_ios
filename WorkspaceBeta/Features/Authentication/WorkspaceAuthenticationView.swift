import SwiftUI

struct WorkspaceAuthenticationView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @State private var serverInput = ""

    var body: some View {
        NavigationStack {
            Group {
                if appModel.selectedServer == nil {
                    serverPicker
                } else {
                    WorkspaceCredentialsView()
                }
            }
            .background(WorkspacePalette.background.ignoresSafeArea())
            .toolbarBackground(WorkspacePalette.background, for: .navigationBar)
            .animation(.easeInOut(duration: 0.2), value: appModel.selectedServer)
        }
    }

    private var serverPicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 16) {
                    WorkspaceMark(size: 64)
                    Text("Добавить организацию")
                        .font(.largeTitle.bold())
                        .foregroundStyle(WorkspacePalette.text)
                    Text("Укажите адрес вашей организации или подключитесь к публичному Workspace.")
                        .font(.body)
                        .foregroundStyle(WorkspacePalette.secondaryText)
                }

                Button {
                    Task { _ = await appModel.usePublicServer() }
                } label: {
                    HStack(spacing: 14) {
                        Image("serverIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Workspace Exordos")
                                .font(.headline)
                                .foregroundStyle(WorkspacePalette.text)
                            Text("Публичный сервер")
                                .font(.subheadline)
                                .foregroundStyle(WorkspacePalette.secondaryText)
                        }
                        Spacer()
                        if appModel.isWorking {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(WorkspacePalette.secondaryText)
                        }
                    }
                    .padding(16)
                    .background(WorkspacePalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(appModel.isWorking)
                .accessibilityIdentifier("publicWorkspaceServer")

                VStack(alignment: .leading, spacing: 12) {
                    Text("Другой сервер")
                        .font(.headline)
                        .foregroundStyle(WorkspacePalette.text)
                    TextField("workspace.example.com", text: $serverInput)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 50)
                        .background(WorkspacePalette.input, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onSubmit(connectToCustomServer)
                        .accessibilityIdentifier("serverURLField")

                    Button(action: connectToCustomServer) {
                        HStack {
                            if appModel.isWorking { ProgressView().tint(.white) }
                            Text("Продолжить")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(WorkspacePalette.primary)
                    .disabled(serverInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appModel.isWorking)
                    .accessibilityIdentifier("connectServerButton")
                }

                if let errorMessage = appModel.errorMessage {
                    WorkspaceInlineError(message: errorMessage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func connectToCustomServer() {
        Task { _ = await appModel.selectServer(serverInput) }
    }
}

private struct WorkspaceCredentialsView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @State private var username = ""
    @State private var password = ""
    @State private var otp = ""
    @State private var passwordVisible = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case username
        case password
        case otp
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    WorkspaceMark(size: 56)
                    Text(appModel.needsOTP ? "Введите код OTP" : "Вход в Workspace")
                        .font(.largeTitle.bold())
                        .foregroundStyle(WorkspacePalette.text)
                    Text(subtitle)
                        .foregroundStyle(WorkspacePalette.secondaryText)
                }

                if appModel.needsOTP {
                    otpForm
                } else {
                    credentialsForm
                }

                if let errorMessage = appModel.errorMessage {
                    WorkspaceInlineError(message: errorMessage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(appModel.selectedServer?.displayName ?? "Workspace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    appModel.clearSelectedServer()
                } label: {
                    Label("Назад", systemImage: "chevron.left")
                }
                .disabled(appModel.isWorking)
            }
        }
        .onChange(of: appModel.needsOTP) { _, needsOTP in
            if needsOTP { focusedField = .otp }
        }
        .onAppear { focusedField = .username }
    }

    private var subtitle: String {
        if appModel.needsOTP {
            return "Откройте приложение-аутентификатор и введите одноразовый код."
        }
        return "Используйте имя пользователя или электронную почту."
    }

    private var credentialsForm: some View {
        VStack(spacing: 16) {
            TextField("Имя пользователя или email", text: $username)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .username)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .workspaceInputStyle()
                .accessibilityIdentifier("usernameField")

            HStack {
                Group {
                    if passwordVisible {
                        TextField("Пароль", text: $password)
                    } else {
                        SecureField("Пароль", text: $password)
                    }
                }
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit(submitCredentials)

                Button {
                    passwordVisible.toggle()
                } label: {
                    Image(systemName: passwordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(WorkspacePalette.secondaryText)
                }
                .accessibilityLabel(passwordVisible ? "Скрыть пароль" : "Показать пароль")
            }
            .workspaceInputStyle()
            .accessibilityIdentifier("passwordField")

            signInButton(action: submitCredentials)
        }
    }

    private var otpForm: some View {
        VStack(spacing: 16) {
            TextField("000000", text: $otp)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .tracking(8)
                .focused($focusedField, equals: .otp)
                .workspaceInputStyle()
                .onChange(of: otp) { _, value in
                    otp = String(value.filter(\.isNumber).prefix(8))
                }
                .accessibilityLabel("Одноразовый код")
                .accessibilityIdentifier("otpField")

            signInButton(action: submitOTP)

            Button("Вернуться к логину") {
                otp = ""
                appModel.returnToCredentials()
            }
            .frame(maxWidth: .infinity)
            .disabled(appModel.isWorking)
        }
    }

    private func signInButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if appModel.isWorking { ProgressView().tint(.white) }
                Text(appModel.needsOTP ? "Подтвердить" : "Войти")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(WorkspacePalette.primary)
        .disabled(signInDisabled)
        .accessibilityIdentifier("signInButton")
    }

    private var signInDisabled: Bool {
        if appModel.isWorking { return true }
        if appModel.needsOTP { return otp.isEmpty }
        return username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty
    }

    private func submitCredentials() {
        Task { _ = await appModel.signIn(username: username, password: password, otp: nil) }
    }

    private func submitOTP() {
        let submittedOTP = otp
        Task {
            let signedIn = await appModel.signIn(
                username: username,
                password: password,
                otp: submittedOTP
            )
            if !signedIn, appModel.needsOTP {
                otp = ""
                focusedField = .otp
            }
        }
    }
}

struct WorkspaceInlineError: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(WorkspacePalette.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(WorkspacePalette.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityIdentifier("inlineError")
    }
}

private extension View {
    func workspaceInputStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(WorkspacePalette.input, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview("Server picker") {
    WorkspaceAuthenticationView()
        .environment(WorkspaceAppModel())
}
