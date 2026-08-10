import SwiftUI

/// Design tokens matching the web app, so the two don't look like unrelated
/// products. Values are the same hex codes used in the web CSS variables.
enum Theme {
    static let navy950 = Color(hex: 0x060F1C)
    static let navy900 = Color(hex: 0x0B1728)
    static let navy800 = Color(hex: 0x142438)
    static let cyan400 = Color(hex: 0x29D3F5)
    static let cyan300 = Color(hex: 0x7FE3FA)
    static let slate300 = Color(hex: 0xC3D3E2)
    static let slate400 = Color(hex: 0x94A9BE)
    static let danger  = Color(hex: 0xFF6B6B)
    static let line    = Color.white.opacity(0.10)

    static let cardRadius: CGFloat = 14
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.navy900)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.navy950)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Theme.cyan400.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.slate300)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Theme.navy800.opacity(configuration.isPressed ? 0.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
    }
}
