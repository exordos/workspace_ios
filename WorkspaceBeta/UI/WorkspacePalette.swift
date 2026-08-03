import SwiftUI
import UIKit

enum WorkspacePalette {
    static let background = adaptive(light: 0xF6F6F8, dark: 0x1B1B1D)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x202022)
    static let surfaceRaised = adaptive(light: 0xFFFFFF, dark: 0x29292C)
    static let mobileCard = adaptive(light: 0xFFFFFF, dark: 0x3A3A3D)
    static let mobileNavigation = adaptive(light: 0xFFFFFF, dark: 0x343437)
    static let mobileSelection = adaptive(light: 0xE5E5E8, dark: 0x56565B)
    static let mobileIcon = adaptive(light: 0x77777D, dark: 0x77777D)
    static let unreadBadge = Color(red: 1.0, green: 0.08, blue: 0.14)
    static let primary = adaptive(light: 0xE96520, dark: 0xFF8138)
    static let primaryPressed = adaptive(light: 0xC94F13, dark: 0xEA6A24)
    static let text = adaptive(light: 0x1B1B1D, dark: 0xF8F8F9)
    static let secondaryText = adaptive(light: 0x68686D, dark: 0xB5B5BB)
    static let separator = adaptive(light: 0xE4E4E8, dark: 0x38383D)
    static let input = adaptive(light: 0xECECF0, dark: 0x2C2C2F)
    static let danger = adaptive(light: 0xC93D3D, dark: 0xFF6B6B)
    static let online = Color(red: 0.16, green: 0.67, blue: 0.39)

    // Authentication uses the same semantic palette as the Android reference.
    // These colors intentionally stay separate from the messenger palette so
    // matching the sign-in flow does not restyle already-shipped screens.
    static let authBackground = adaptive(light: 0xF8F8FA, dark: 0x1B1B1D)
    static let authField = adaptive(light: 0xFFFFFF, dark: 0x28282B)
    static let authLogoBackground = adaptive(light: 0xEFEFF2, dark: 0x2D2D30)
    static let authMutedText = adaptive(light: 0x68686E, dark: 0x9A9A9F)
    static let authLabelText = adaptive(light: 0x606066, dark: 0x737378)
    static let authDivider = adaptive(light: 0xDEDEE3, dark: 0x343438)
    static let authDisabled = adaptive(light: 0xE1E1E5, dark: 0x555558)
    static let authDisabledText = adaptive(light: 0xA0A0A6, dark: 0x8A8A8E)
    static let authError = adaptive(light: 0xD92D35, dark: 0xFF4248)
    static let authErrorContainer = adaptive(light: 0xFFECEE, dark: 0xFFE7E8)
    static let authErrorText = adaptive(light: 0xB4232A, dark: 0xDE2B32)
    static let authPrimaryText = Color(red: 23.0 / 255.0, green: 23.0 / 255.0, blue: 25.0 / 255.0)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(
            UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
