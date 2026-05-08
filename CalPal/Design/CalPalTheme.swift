import SwiftUI
import UIKit

enum CalPalTheme {
    enum Colors {
        static let backgroundPrimary = Color(light: "#F7F8FC", dark: "#05070A")
        static let backgroundElevated = Color(light: "#FFFFFF", dark: "#15171D")
        static let backgroundGlassTint = Color(light: "#FFFFFF", dark: "#1C1E24")
        static let textPrimary = Color(light: "#101218", dark: "#F4F7FB")
        static let textSecondary = Color(light: "#667085", dark: "#A7B0BE")
        static let brandPrimary = Color(light: "#0A84FF", dark: "#4DA3FF")
        static let brandSecondary = Color(light: "#00C7BE", dark: "#65DAD2")
        static let recording = Color(light: "#FF3B30", dark: "#FF453A")
        static let success = Color(light: "#34C759", dark: "#30D158")
        static let warning = Color(light: "#FF9F0A", dark: "#FFD60A")
        static let destructive = Color(light: "#FF3B30", dark: "#FF453A")
        static let timelineRule = Color(light: "#D0D5DD", dark: "#343842")
        static let selectedDateBackground = Color(light: "#006EDB", dark: "#2F7FD6")
        static let selectedDateForeground = Color.white
        static let brandGradient = LinearGradient(colors: [brandPrimary, brandSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)

        static let aiChip = ChipPalette(background: Color(light: "#E7F2FF", dark: "#102A43"), foreground: Color(light: "#0057B8", dark: "#A9D4FF"))
        static let warningChip = ChipPalette(background: Color(light: "#FFF3D6", dark: "#3C2E12"), foreground: Color(light: "#7A4A00", dark: "#FFE8A3"))
        static let successChip = ChipPalette(background: Color(light: "#E8F8EE", dark: "#12351F"), foreground: Color(light: "#176B36", dark: "#7EE29A"))
        static let destructiveChip = ChipPalette(background: Color(light: "#FFE8E6", dark: "#431815"), foreground: Color(light: "#B42318", dark: "#FFB4AD"))
        static let neutralChip = ChipPalette(background: Color(light: "#EEF2F6", dark: "#242832"), foreground: textSecondary)

        static func eventAccent(hex: String?, fallbackID: String) -> Color {
            if let hex, let color = Color(hex: hex) { return color }
            let palette = [
                Color(light: "#5E5CE6", dark: "#7D7AFF"),
                Color(light: "#0A84FF", dark: "#4DA3FF"),
                Color(light: "#00A88F", dark: "#65DAD2"),
                Color(light: "#AF52DE", dark: "#BF8CFF"),
                Color(light: "#FF9F0A", dark: "#FFD60A")
            ]
            let value = abs(fallbackID.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
            return palette[value % palette.count]
        }
    }

    struct ChipPalette {
        let background: Color
        let foreground: Color
    }

    struct AppearancePreviewPalette {
        let title: String
        let background: Color
        let card: Color
        let accent: Color
    }

    enum AppearancePreview {
        static let light = AppearancePreviewPalette(title: "Light", background: Colors.backgroundPrimary, card: Color(light: "#FFFFFF", dark: "#FFFFFF"), accent: Colors.brandPrimary)
        static let dark = AppearancePreviewPalette(title: "Dark", background: Color(light: "#05070A", dark: "#05070A"), card: Color(light: "#15171D", dark: "#15171D"), accent: Color(light: "#4DA3FF", dark: "#4DA3FF"))
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let orb: CGFloat = 76
        static let recordingOrb: CGFloat = 96
    }

    enum Radius {
        static let card: CGFloat = 18
        static let compactCard: CGFloat = 14
        static let pill: CGFloat = 999
    }
}

struct ElevatedCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(CalPalTheme.Colors.backgroundElevated, in: RoundedRectangle(cornerRadius: CalPalTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CalPalTheme.Radius.card, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 18, x: 0, y: 8)
    }
}

struct GlassCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: CalPalTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CalPalTheme.Radius.card, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.10), radius: 20, x: 0, y: 10)
    }

    private var backgroundStyle: AnyShapeStyle {
        if reduceTransparency { return AnyShapeStyle(CalPalTheme.Colors.backgroundElevated) }
        return AnyShapeStyle(.regularMaterial)
    }
}

struct QuietChipModifier: ViewModifier {
    let palette: CalPalTheme.ChipPalette

    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(palette.background, in: Capsule())
            .foregroundStyle(palette.foreground)
    }
}

extension View {
    func elevatedCard() -> some View { modifier(ElevatedCardModifier()) }
    func glassCard() -> some View { modifier(GlassCardModifier()) }
    func quietChip(_ palette: CalPalTheme.ChipPalette = CalPalTheme.Colors.neutralChip) -> some View { modifier(QuietChipModifier(palette: palette)) }
}

extension Color {
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    init?(hex: String) {
        guard let uiColor = UIColor(optionalHex: hex) else { return nil }
        self.init(uiColor: uiColor)
    }
}

private extension UIColor {
    convenience init(hex: String) {
        guard let components = UIColor.rgbComponents(from: hex) else {
            self.init(white: 0, alpha: 0)
            return
        }
        self.init(red: components.red, green: components.green, blue: components.blue, alpha: 1)
    }

    convenience init?(optionalHex hex: String) {
        guard let components = UIColor.rgbComponents(from: hex) else { return nil }
        self.init(red: components.red, green: components.green, blue: components.blue, alpha: 1)
    }

    static func rgbComponents(from hex: String) -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        return (
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255
        )
    }
}
