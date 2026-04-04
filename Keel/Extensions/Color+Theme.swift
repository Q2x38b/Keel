import SwiftUI

extension Color {
    // MARK: - Dark Theme Colors

    /// Main accent color - sophisticated grey
    static let accent = Color(hex: "8E8E93")

    /// Background colors for dark mode
    static let background = Color(hex: "0F0F0F")
    static let secondaryBackground = Color(hex: "1C1C1E")
    static let tertiaryBackground = Color(hex: "2C2C2E")

    /// Card colors
    static let cardBackground = Color(hex: "1C1C1E")
    static let cardBorder = Color(hex: "38383A")

    /// Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8E8E93")
    static let textTertiary = Color(hex: "636366")

    // MARK: - Status Colors

    static let statusOnline = Color(hex: "34C759")
    static let statusOffline = Color(hex: "636366")
    static let statusLive = Color(hex: "FF3B30")
    static let statusUpcoming = Color(hex: "FF9500")

    // MARK: - Location Type Colors

    static let locationHome = Color(hex: "FF9500")
    static let locationSchool = Color(hex: "34C759")
    static let locationLibrary = Color(hex: "007AFF")
    static let locationOffice = Color(hex: "AF52DE")
    static let locationOther = Color(hex: "8E8E93")

    // MARK: - Semantic Colors

    static let cardShadow = Color.clear // No shadow in dark mode

    // MARK: - Gradient Helpers

    static func lessonGradient(for color: LessonColor) -> LinearGradient {
        LinearGradient(
            colors: [color.color, color.color.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Hex Initialization

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    var hex: String {
        guard let components = UIColor(self).cgColor.components else { return "000000" }

        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)

        return String(format: "%02X%02X%02X", r, g, b)
    }
}

// MARK: - View Extensions for Theming

extension View {
    func cardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.cardBorder, lineWidth: 0.5)
                    )
            )
    }

    func statusBadgeStyle(isOnline: Bool) -> some View {
        self
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(isOnline ? Color.statusOnline : Color.statusOffline)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isOnline ? Color.statusOnline.opacity(0.15) : Color.statusOffline.opacity(0.15))
            )
    }

    func darkCard() -> some View {
        self
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.cardBorder, lineWidth: 0.5)
            )
    }
}
