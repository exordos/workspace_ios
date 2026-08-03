import SwiftUI
import UIKit

enum WorkspacePalette {
    static let background = adaptive(light: 0xF6F6F8, dark: 0x1B1B1D)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x202022)
    static let surfaceRaised = adaptive(light: 0xFFFFFF, dark: 0x29292C)
    static let primary = adaptive(light: 0xE96520, dark: 0xFF8138)
    static let primaryPressed = adaptive(light: 0xC94F13, dark: 0xEA6A24)
    static let text = adaptive(light: 0x1B1B1D, dark: 0xF8F8F9)
    static let secondaryText = adaptive(light: 0x68686D, dark: 0xB5B5BB)
    static let separator = adaptive(light: 0xE4E4E8, dark: 0x38383D)
    static let input = adaptive(light: 0xECECF0, dark: 0x2C2C2F)
    static let danger = adaptive(light: 0xC93D3D, dark: 0xFF6B6B)
    static let online = Color(red: 0.16, green: 0.67, blue: 0.39)

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
