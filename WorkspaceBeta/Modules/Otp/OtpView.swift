//
//  OtpView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

struct OtpView: View {

    @ObservedObject var viewModel: OtpViewModel
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        VStack(alignment: .center) {
            Text("Введите код")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.textHeaders)
                .padding(.bottom, 10.0)
            Text("Введите 6-значный код\nиз приложения-аутентификатора")
                .font(.system(size: 14))
                .foregroundColor(Color.textAdditional50)
                .padding(.bottom, 44.0)
                .padding(.horizontal, 20.0)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 12.0) {
                codeEnteringView
            }
            .padding(.horizontal, 12.0)
        }
        .onAppear {
            isCodeFocused = true
        }
    }

    var codeEnteringView: some View {
        VStack(alignment: .leading, spacing: .zero) {
            InputCodeView(numberOfDigits: 6, isInErrorState: viewModel.enteredCodeError != nil, enteredCode: $viewModel.enteredCode, hasActionError: $viewModel.hasActionError)
                .focused($isCodeFocused)
            if let enteredCodeError = viewModel.enteredCodeError {
                Text(enteredCodeError)
                    .font(.system(size: 12.0))
                    .foregroundColor(Color.indicatorRed)
                    .padding(.vertical, 12.0)
            }
        }
    }
}


struct InputCodeSymbolView: View {

    private struct Appearance {
        static let elementHeight: CGFloat = 58.0
        static let linewidth: CGFloat = 2.0
    }

    let symbol: String
    let isInErrorState: Bool
    let isActive: Bool

    var body: some View {
            baseElement
                .overlay(
                    RoundedCorner(radius: 8.0)
                        .stroke(isActive ? Color.primary : Color.searchBackground, lineWidth: Appearance.linewidth)
                        .clipShape(RoundedCorner(radius: 8.0))
                )

    }

    var baseElement: some View {
        Text(symbol)
            .font(.system(size: 20.0))
            .foregroundStyle(Color.textHeaders)
            .frame(height: Appearance.elementHeight)
            .frame(maxWidth: .infinity)
            .background(Color.searchBackground)
    }
}

struct InputCodeView: View {

    private struct Appearance {
        static let headerElementPadding: CGFloat = 12.0
        static let digitSpacing: CGFloat = 10.0
        static let cornerRadius: CGFloat = 6.0
        static let elementPadding: CGFloat = 8.0
        static let textLimit: Int = 6
    }

    let numberOfDigits: Int
    let isInErrorState: Bool
    @Binding var enteredCode: String
    @Binding var hasActionError: Bool

    var body: some View {
        ZStack {
            HStack(spacing: Appearance.digitSpacing) {
                ForEach(0..<numberOfDigits, id: \.self) { symbolIndex in
                    InputCodeSymbolView(symbol: enteredSymbol(offsetBy: symbolIndex), isInErrorState: isInErrorState, isActive: enteredCode.count == symbolIndex)
                }
            }
            .onChange(of: hasActionError) { newValue in
                if newValue == true {
                    withAnimation(Animation.spring(response: 0.2, dampingFraction: 0.2, blendDuration: 0.2)) {
                        hasActionError = false
                    }
                }
            }
            .offset(x: hasActionError ? 30 : 0)
            TextField("", text: $enteredCode)
                .foregroundColor(.clear)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .frame(maxWidth: .infinity)
                .frame(height: 58.0)
                .accentColor(.clear)
                .onReceive(Just(enteredCode)) { _ in limitText(Appearance.textLimit) }
                .accessibilityIdentifier("enteredCodeTextField")
        }
    }

    func enteredSymbol(offsetBy offset: Int) -> String {
        if offset >= enteredCode.count {
            return " "
        } else {
            return String(enteredCode[enteredCode.index(enteredCode.startIndex, offsetBy: offset)])
        }
    }

    func limitText(_ upper: Int) {
        if enteredCode.count > upper {
            enteredCode = String(enteredCode.prefix(upper))
        }
    }

}
