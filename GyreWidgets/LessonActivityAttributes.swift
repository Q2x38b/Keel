import ActivityKit
import SwiftUI

struct LessonActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var lessonName: String
        var room: String
        var building: String?
        var startTime: Date
        var endTime: Date
        var colorHex: String
        var isLive: Bool
        var progress: Double
        var timeRemaining: TimeInterval
    }

    var locationName: String
    var lessonId: String
}

// MARK: - Color from Hex
extension Color {
    static func fromHex(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        return Color(red: r, green: g, blue: b)
    }
}
