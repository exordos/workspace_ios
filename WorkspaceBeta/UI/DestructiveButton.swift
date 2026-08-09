//
//  DestructiveButton.swift
//  WorkspaceBeta
//
//

import SwiftUI

struct DestructiveButton: View {

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
                        .foregroundColor(.indicatorRed)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.indicatorRed)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .disabled(isLoading)
        .buttonStyle(DestructiveButtonStyle())
    }
}

extension DestructiveButton {
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

struct DestructiveButtonStyle: ButtonStyle {


    struct Appearance {
        static let verticalPadding: CGFloat = 10.0
    }

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(.vertical, Appearance.verticalPadding)
            .padding(.horizontal, 16)
            .background(configuration.isPressed ? Color.clear : Color.clear)
            .overlay(
                RoundedCorner(radius: 8)
                    .stroke(Color.indicatorRed, lineWidth: 2)
                    .clipShape(RoundedCorner(radius: 8))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

}

struct RoundedCorner: Shape {

    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}


#Preview {
    DestructiveButton(title: "Кнопка", icon: nil, action: {})
        .padding(16.0)
}

