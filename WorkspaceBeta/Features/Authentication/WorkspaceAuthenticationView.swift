import SwiftUI

struct WorkspaceAuthenticationView: View {
    @Environment(WorkspaceAppModel.self) private var appModel
    @State private var serverInput = ""
    @FocusState private var serverFieldFocused: Bool

    var body: some View {
        ZStack {
            WorkspacePalette.authBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 22)

                    Text("Вход")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(WorkspacePalette.text)

                    if let errorMessage = appModel.errorMessage,
                       !errorMessage.isEmpty {
                        WorkspaceInlineError(message: errorMessage)
                            .padding(.top, 16)
                    }

                    if appModel.selectedServer == nil {
                        serverPicker
                            .transition(.opacity)
                    } else {
                        WorkspaceCredentialsView()
                            .transition(.opacity)
                    }

                    Spacer()
                        .frame(height: 28)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: 390)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            if appModel.isWorking {
                WorkspaceAuthenticationLoadingOverlay()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appModel.selectedServer)
        .animation(.easeInOut(duration: 0.2), value: appModel.needsOTP)
    }

    private var serverPicker: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: appModel.errorMessage == nil ? 76 : 32)

            Text("Добро пожаловать")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(WorkspacePalette.text)

            Text("Введите адрес вашей организации,\nчтобы продолжить")
                .font(.system(size: 17))
                .foregroundStyle(WorkspacePalette.authMutedText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 10)

            Spacer()
                .frame(height: 78)

            WorkspaceAuthenticationField(
                label: "Адрес организации",
                isFocused: serverFieldFocused
            ) {
                ZStack(alignment: .leading) {
                    if serverInput.isEmpty {
                        Text("https://example.com")
                            .foregroundStyle(WorkspacePalette.authMutedText)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $serverInput)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($serverFieldFocused)
                        .onSubmit(connectToCustomServer)
                        .accessibilityIdentifier("serverURLField")
                }
            }

            WorkspaceAuthenticationPrimaryButton(
                title: "Войти",
                enabled: canConnectToCustomServer,
                action: connectToCustomServer
            )
            .padding(.top, 24)
            .accessibilityIdentifier("connectServerButton")

            HStack(spacing: 12) {
                Rectangle()
                    .fill(WorkspacePalette.authDivider)
                    .frame(height: 1)

                Text("ИЛИ")
                    .font(.system(size: 13))
                    .foregroundStyle(WorkspacePalette.authMutedText)

                Rectangle()
                    .fill(WorkspacePalette.authDivider)
                    .frame(height: 1)
            }
            .padding(.vertical, 30)

            Text("Вы можете подключиться к нашему\nпубличному серверу:")
                .font(.system(size: 17))
                .foregroundStyle(WorkspacePalette.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                serverFieldFocused = false
                Task { _ = await appModel.usePublicServer() }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(WorkspacePalette.authLogoBackground)

                        Image("serverIcon")
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    }
                    .frame(width: 44, height: 44)

                    Text("Exordos public")
                        .font(.system(size: 17))
                        .foregroundStyle(WorkspacePalette.text)

                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    WorkspacePalette.authField,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(appModel.isWorking)
            .padding(.top, 12)
            .accessibilityIdentifier("publicWorkspaceServer")
        }
    }

    private var canConnectToCustomServer: Bool {
        !serverInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !appModel.isWorking
    }

    private func connectToCustomServer() {
        guard canConnectToCustomServer else { return }
        serverFieldFocused = false
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
        Group {
            if appModel.needsOTP {
                otpContent
            } else {
                credentialsContent
            }
        }
        .onChange(of: appModel.needsOTP) { _, needsOTP in
            guard needsOTP else {
                focusedField = nil
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                focusedField = .otp
            }
        }
    }

    private var credentialsContent: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 54)

            WorkspaceAuthenticationLogo()

            Text(organizationTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WorkspacePalette.text)
                .padding(.top, 16)

            Text(organizationURL)
                .font(.system(size: 16))
                .foregroundStyle(WorkspacePalette.authMutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 6)

            Rectangle()
                .fill(WorkspacePalette.authDivider)
                .frame(height: 1)
                .padding(.top, 24)
                .padding(.bottom, 18)

            WorkspaceAuthenticationField(
                label: "Имя пользователя или email",
                isFocused: focusedField == .username
            ) {
                ZStack(alignment: .leading) {
                    if username.isEmpty {
                        Text("username или email@example.com")
                            .foregroundStyle(WorkspacePalette.authMutedText)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $username)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .username)
                        .onSubmit { focusedField = .password }
                        .accessibilityIdentifier("usernameField")
                }
            }

            WorkspaceAuthenticationField(
                label: "Пароль",
                isFocused: focusedField == .password
            ) {
                HStack(spacing: 4) {
                    ZStack(alignment: .leading) {
                        if password.isEmpty {
                            Text("Введите пароль")
                                .foregroundStyle(WorkspacePalette.authMutedText)
                                .allowsHitTesting(false)
                        }

                        Group {
                            if passwordVisible {
                                TextField("", text: $password)
                            } else {
                                SecureField("", text: $password)
                            }
                        }
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($focusedField, equals: .password)
                        .onSubmit(submitCredentials)
                        .accessibilityIdentifier("passwordField")
                    }

                    Button {
                        passwordVisible.toggle()
                    } label: {
                        Image(systemName: passwordVisible ? "eye.slash" : "eye")
                            .font(.system(size: 20))
                            .foregroundStyle(WorkspacePalette.authMutedText)
                            .frame(width: 36, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(passwordVisible ? "Скрыть пароль" : "Показать пароль")
                }
            }
            .padding(.top, 14)

            Text("Не помню пароль")
                .font(.system(size: 15))
                .foregroundStyle(WorkspacePalette.primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 8)

            WorkspaceAuthenticationPrimaryButton(
                title: "Войти",
                enabled: canSubmitCredentials,
                action: submitCredentials
            )
            .padding(.top, 26)
            .accessibilityIdentifier("signInButton")

            WorkspaceAuthenticationLogoutButton {
                focusedField = nil
                appModel.clearSelectedServer()
            }
            .padding(.top, 14)
            .accessibilityIdentifier("logoutOrganizationButton")
        }
    }

    private var otpContent: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 76)

            Text("Введите код")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(WorkspacePalette.text)

            Text("Введите 6-значный код из\nприложения-аутентификатора")
                .font(.system(size: 17))
                .foregroundStyle(WorkspacePalette.authMutedText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 10)

            Spacer()
                .frame(height: 64)

            WorkspaceOTPCodeField(
                otp: $otp,
                focusedField: $focusedField,
                focusValue: .otp
            )

            WorkspaceAuthenticationPrimaryButton(
                title: "Подтвердить",
                enabled: canSubmitOTP,
                action: submitOTP
            )
            .padding(.top, 40)
            .accessibilityIdentifier("signInButton")

            Button("Вернуться к логину") {
                otp = ""
                focusedField = nil
                appModel.returnToCredentials()
            }
            .buttonStyle(.plain)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(WorkspacePalette.primary)
            .padding(.vertical, 8)
            .padding(.top, 14)
            .disabled(appModel.isWorking)
            .accessibilityIdentifier("returnToLoginButton")
        }
    }

    private var organizationTitle: String {
        guard let server = appModel.selectedServer else { return "Workspace" }
        return WorkspaceAuthenticationRules.organizationTitle(for: server)
    }

    private var organizationURL: String {
        guard let server = appModel.selectedServer else { return "" }
        let value = server.baseURL.absoluteString
        return value.hasSuffix("/") ? String(value.dropLast()) : value
    }

    private var canSubmitCredentials: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !password.isEmpty &&
            !appModel.isWorking
    }

    private var canSubmitOTP: Bool {
        otp.count == WorkspaceAuthenticationRules.otpLength && !appModel.isWorking
    }

    private func submitCredentials() {
        guard canSubmitCredentials else { return }
        focusedField = nil
        Task { _ = await appModel.signIn(username: username, password: password, otp: nil) }
    }

    private func submitOTP() {
        guard canSubmitOTP else { return }
        focusedField = nil
        let submittedOTP = otp
        Task {
            let signedIn = await appModel.signIn(
                username: username,
                password: password,
                otp: submittedOTP
            )
            if !signedIn, appModel.needsOTP {
                otp = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    focusedField = .otp
                }
            }
        }
    }
}

private struct WorkspaceAuthenticationField<Content: View>: View {
    let label: String
    var error: String?
    let isFocused: Bool
    let content: Content

    init(
        label: String,
        error: String? = nil,
        isFocused: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.error = error
        self.isFocused = isFocused
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(error == nil ? WorkspacePalette.authLabelText : WorkspacePalette.authError)

            content
                .font(.system(size: 16))
                .foregroundStyle(WorkspacePalette.text)
                .tint(WorkspacePalette.primary)
                .padding(.horizontal, 12)
                .frame(minHeight: 52)
                .background(
                    WorkspacePalette.authField,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(fieldBorderColor, lineWidth: 1)
                }
                .padding(.top, 6)

            if let error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(WorkspacePalette.authError)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fieldBorderColor: Color {
        if error != nil { return WorkspacePalette.authError }
        if isFocused { return WorkspacePalette.primary }
        return .clear
    }
}

private struct WorkspaceAuthenticationPrimaryButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(
                    enabled ? WorkspacePalette.authPrimaryText : WorkspacePalette.authDisabledText
                )
                .background(
                    enabled ? WorkspacePalette.primary : WorkspacePalette.authDisabled,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct WorkspaceAuthenticationLogoutButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 20))
                Text("Выйти из организации")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(WorkspacePalette.authError)
            .frame(maxWidth: .infinity, minHeight: 50)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(WorkspacePalette.authError, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct WorkspaceAuthenticationLogo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(WorkspacePalette.authLogoBackground)

            Image("serverIcon")
                .resizable()
                .scaledToFit()
                .padding(22)
        }
        .frame(width: 116, height: 116)
        .accessibilityHidden(true)
    }
}

private struct WorkspaceOTPCodeField<FocusValue: Hashable>: View {
    @Binding var otp: String
    let focusedField: FocusState<FocusValue?>.Binding
    let focusValue: FocusValue

    var body: some View {
        ZStack {
            TextField("", text: $otp)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .focused(focusedField, equals: focusValue)
                .onChange(of: otp) { _, value in
                    otp = WorkspaceAuthenticationRules.normalizedOTP(value)
                }
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityLabel("Одноразовый код")
                .accessibilityIdentifier("otpField")

            HStack(spacing: 8) {
                ForEach(0 ..< WorkspaceAuthenticationRules.otpLength, id: \.self) { index in
                    Text(digit(at: index))
                        .font(.system(size: 24))
                        .foregroundStyle(WorkspacePalette.text)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(
                            WorkspacePalette.authField,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    isActive(index) ? WorkspacePalette.primary : .clear,
                                    lineWidth: 1
                                )
                        }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { focusedField.wrappedValue = focusValue }
            .accessibilityHidden(true)
        }
    }

    private func digit(at index: Int) -> String {
        guard index < otp.count else { return "" }
        let valueIndex = otp.index(otp.startIndex, offsetBy: index)
        return String(otp[valueIndex])
    }

    private func isActive(_ index: Int) -> Bool {
        guard focusedField.wrappedValue == focusValue else { return false }
        return index == min(otp.count, WorkspaceAuthenticationRules.otpLength - 1)
    }
}

private struct WorkspaceAuthenticationLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()

            ProgressView()
                .controlSize(.large)
                .tint(WorkspacePalette.primary)
                .accessibilityLabel("Выполняется вход")
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isModal)
    }
}

struct WorkspaceInlineError: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 18, weight: .semibold))

            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(WorkspacePalette.authErrorText)
        .padding(.horizontal, 12)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(
            WorkspacePalette.authErrorContainer,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityIdentifier("inlineError")
    }
}

nonisolated enum WorkspaceAuthenticationRules {
    static let otpLength = 6

    static func normalizedOTP(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(otpLength))
    }

    static func organizationTitle(for server: WorkspaceServer) -> String {
        if server.baseURL.host == "workspace.exordos.com" {
            return "Exordos Workspace"
        }
        return server.displayName
    }
}

#Preview("Organization · Dark") {
    WorkspaceAuthenticationView()
        .environment(WorkspaceAppModel())
        .preferredColorScheme(.dark)
}

#Preview("Organization · Light") {
    WorkspaceAuthenticationView()
        .environment(WorkspaceAppModel())
        .preferredColorScheme(.light)
}
