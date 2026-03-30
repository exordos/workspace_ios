//
//  PrimaryButton.swift
//  WorkspaceBeta
//
//  Created by Evgenii Vedenin on 22.02.2026.
//

import SwiftUI

struct PrimaryButton: View {

    @State var isAnimating = false
    let title: LocalizedStringKey
    let icon: String?
    @Binding var isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                Image("buttonLoader")
                    .resizable()
                    .foregroundColor(.onPrimary)
                    .frame(width: 24.0, height: 24.0)
                    .frame(maxWidth: .infinity)
                    .rotationEffect(Angle(radians: self.isAnimating ? 2 * .pi : .zero))
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: false),
                        value: UUID()
                    )
                    .onAppear {
                        self.isAnimating = true
                    }
            } else {
                if let icon = icon {
                    Label(title, image: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.onPrimary)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.onPrimary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .disabled(isLoading)
        .buttonStyle(PrimaryButtonStyle())
    }
}

extension PrimaryButton {
    init(title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
        self.icon = nil
        self._isLoading = .constant(false)
    }

    init(title: LocalizedStringKey, icon: String?, action: @escaping () -> Void) {
        self.title = title
        self.action = action
        self._isLoading = .constant(false)
        self.icon = icon
    }
}

struct PrimaryButtonStyle: ButtonStyle {


    struct Appearance {
        static let verticalPadding: CGFloat = 10.0
    }

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(.vertical, Appearance.verticalPadding)
            .padding(.horizontal, 16)
            .background(configuration.isPressed ? Color.primary : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

}

#Preview {
    PrimaryButton(title: "Кнопка", icon: nil, action: {})
}

