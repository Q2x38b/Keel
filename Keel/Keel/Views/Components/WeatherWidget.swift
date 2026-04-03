import SwiftUI

struct WeatherWidget: View {
    let temperature: Int?
    let windSpeed: Int?
    let airQualityIndex: Int?
    let weatherSymbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Weather icon and temperature
            HStack(spacing: 8) {
                Image(systemName: weatherSymbol)
                    .font(.system(size: 20, weight: .medium))
                    .symbolRenderingMode(.multicolor)

                Text(temperature != nil ? "\(temperature!)°" : "--°")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(temperature != nil ? .white : .white.opacity(0.5))
            }

            // AQI row
            HStack(spacing: 6) {
                Circle()
                    .fill(airQualityIndex != nil ? aqiColor(for: airQualityIndex!) : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)

                Text(airQualityIndex != nil ? "\(airQualityIndex!) AQI" : "-- AQI")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(airQualityIndex != nil ? .white.opacity(0.8) : .white.opacity(0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
    }

    private func aqiColor(for aqi: Int) -> Color {
        switch aqi {
        case 0...50: return .green
        case 51...100: return .yellow
        case 101...150: return .orange
        case 151...200: return .red
        case 201...300: return .purple
        default: return Color(red: 0.5, green: 0, blue: 0)
        }
    }
}

// Placeholder when loading
struct WeatherWidgetPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.gray.opacity(0.5))

                Text("--°")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)

                Text("-- AQI")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    ZStack {
        Color.black
        WeatherWidget(
            temperature: 80,
            windSpeed: 12,
            airQualityIndex: 50,
            weatherSymbol: "wind"
        )
    }
}
