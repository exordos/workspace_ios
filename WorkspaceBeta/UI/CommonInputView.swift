//
//  CommonInputView.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 22.02.2026.
//

import SwiftUI
import Combine

struct CommonInputView: View {

    struct EyeView: View {

        @Binding var isOpen: Bool

        var body: some View {
            Button(action: {
                isOpen.toggle()
            },
            label: {
                Image(isOpen ? "eye" : "crossedEye")
            })
        }
    }

    struct Appearance {
        static let placeholderPadding: CGFloat = 24.0
        static let frameCornerRadius: CGFloat = 8.0
        static let frameLineWidth: CGFloat = 1.0
        static let framePadding: CGFloat = 2.0
        static let backgroundEdgeInsets: EdgeInsets = EdgeInsets(top: 6.0, leading: 8.0, bottom: 6.0, trailing: 8.0)
        static let smallSpacerHeight: CGFloat = 8.0
        static let mediumSpacerHeight: CGFloat = 18.0
        static let textfieldHeight: CGFloat = 24.0
        static let titlePadding: CGFloat = 4.0
        static let errorTextPadding: CGFloat = 4.0
        static let richErrorTextPadding: CGFloat = 16.0
        static let frameHeight: CGFloat = 64.0
    }

    @ObservedObject var viewModel: CommonInputViewModel
    @Binding var text: String
    @State private var isFocused = false
    @State private var isSecured = true

    var isFull: Bool { !text.isEmpty || isFocused }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: .zero) {
                if let stringKey = viewModel.title.stringKey, !stringKey.isEmpty {
                    HStack {
                        Text(viewModel.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textAdditional30)
                    }
                    .padding(.bottom, Appearance.titlePadding)
                }
                HStack {
                    possiblySecuredTextField
                        .frame(height: Appearance.textfieldHeight)
                    if !text.isEmpty, viewModel.isEnabled {
                        Button {
                            text = ""
                        } label: {
                            Image("inputCross")
                        }
                    }
                    if viewModel.isPassword {
                        Spacer()
                        EyeView(isOpen: $isSecured)
                    }
                }
                .padding(Appearance.backgroundEdgeInsets)
                .overlay(
                    RoundedRectangle(cornerRadius: Appearance.frameCornerRadius)
                        .stroke(Color.searchBackground, lineWidth: Appearance.frameLineWidth)
                )
                .background(Color.searchBackground)
                if let errorText = viewModel.errorText {
                    Text(errorText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Appearance.errorTextPadding)
                } else if let descriptionText = viewModel.descriptionText {
                    Text(descriptionText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Appearance.errorTextPadding)
                }
            }
            .padding(.horizontal, Appearance.framePadding)
        }
        .frame(height: frameHeight)
    }

    var frameHeight: CGFloat {
        return Appearance.frameHeight
    }

    @ViewBuilder
    var possiblySecuredTextField: some View {
            if viewModel.isPassword && isSecured {
                SecureField(viewModel.placeholder, text: $text)
                    .font(.system(size: 14))
                    .foregroundColor(.textHeaders)
                    .disableAutocorrection(true)
                    .textContentType(viewModel.textContentType)
                    .onSubmit {
                        viewModel.onSubmit?()
                    }
            } else {
                TextField(viewModel.placeholder, text: $text) { editingStatus in
                    isFocused = editingStatus
                }
                .onSubmit {
                    viewModel.onSubmit?()
                }
                .font(.system(size: 14))
                .foregroundColor(.textHeaders)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .disabled(!viewModel.isEnabled)
                .textContentType(viewModel.textContentType)
                .keyboardType(viewModel.keyBoardType)
            }

    }
}

class CommonInputViewModel: ObservableObject {
    let title: LocalizedStringKey
    @Published var placeholder: LocalizedStringKey
    let isPassword: Bool
    let isRequired: Bool
    let keyBoardType: UIKeyboardType
    let textLimit: Int?
    let textContentType: UITextContentType?
    var onSubmit: (() -> Void)?
    @Published var errorText: LocalizedStringKey?
    @Published var descriptionText: LocalizedStringKey?
    @Published var richErrorText: String?
    @Published var isEnabled: Bool

    init(with title: LocalizedStringKey, placeholder: LocalizedStringKey = "", isRequired: Bool = false, isPassword: Bool = false, keyBoardType: UIKeyboardType = .default, textLimit: Int? = nil, textContentType: UITextContentType? = nil, errorText: LocalizedStringKey? = nil, descriptionText: LocalizedStringKey? = nil, isEnabled: Bool = true, onSubmit: (() -> Void)? = nil) {
        self.title = title
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.isPassword = isPassword
        self.keyBoardType = keyBoardType
        self.textLimit = textLimit
        self.textContentType = textContentType
        self.errorText = errorText
        self.descriptionText = descriptionText
        self.isEnabled = isEnabled
        self.onSubmit = onSubmit
    }
}

struct CommonInputView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = CommonInputViewModel(with: "Пароль", isRequired: true, isPassword: true)
        viewModel.errorText = "error"
        viewModel.richErrorText = "RichError"
        return CommonInputView(viewModel: viewModel, text: .constant(""))
            .previewLayout(.fixed(width: 300.0, height: 200.0))
    }
}

extension LocalizedStringKey {

    var stringKey: String? {
        Mirror(reflecting: self).children.first(where: { $0.label == "key" })?.value as? String
    }
}
