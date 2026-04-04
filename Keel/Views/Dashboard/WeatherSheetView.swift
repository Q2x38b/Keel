import SwiftUI

struct WeatherSheetView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var weatherService: WeatherService

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.textTertiary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 20) {
                    // Current weather header
                    currentWeatherSection

                    // Hourly forecast
                    hourlyForecastSection

                    // Air quality
                    airQualitySection

                    // 7-day forecast
                    weeklyForecastSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity)
        .background(Color.secondaryBackground)
    }

    // MARK: - Current Weather Section
    private var currentWeatherSection: some View {
        VStack(spacing: 8) {
            // Location name
            Text(weatherService.locationName.isEmpty ? "Current Location" : weatherService.locationName)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.textPrimary)

            // Large temperature
            if let temp = weatherService.temperature(for: appState.unitSystem) {
                Text("\(temp)°")
                    .font(.system(size: 80, weight: .thin))
                    .foregroundStyle(Color.textPrimary)
            } else {
                Text("--°")
                    .font(.system(size: 80, weight: .thin))
                    .foregroundStyle(Color.textTertiary)
            }

            // Condition and feels like
            VStack(spacing: 4) {
                Text(weatherService.conditionDescription)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.textSecondary)

                if let feelsLike = weatherService.feelsLike(for: appState.unitSystem) {
                    Text("Feels like: \(feelsLike)°")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textTertiary)
                } else {
                    Text("Feels like: --°")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textTertiary)
                }

                // High / Low
                if let high = weatherService.highTemperature(for: appState.unitSystem),
                   let low = weatherService.lowTemperature(for: appState.unitSystem) {
                    Text("H: \(high)° L: \(low)°")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                } else {
                    Text("H: --° L: --°")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Hourly Forecast Section
    private var hourlyForecastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if weatherService.hourlyForecast.isEmpty {
                // Loading/empty state
                HStack(spacing: 16) {
                    ForEach(0..<6, id: \.self) { index in
                        VStack(spacing: 8) {
                            Text(index == 0 ? "Now" : "--")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.textTertiary)

                            Image(systemName: "cloud.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.textTertiary.opacity(0.5))
                                .frame(height: 28)

                            Text("--°")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .frame(width: 56)
                    }
                }
                .padding(.horizontal, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(weatherService.hourlyForecast.enumerated()), id: \.element.id) { index, hour in
                            VStack(spacing: 8) {
                                // Time
                                Text(index == 0 ? "Now" : formatHour(hour.date))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.textSecondary)

                                // Weather icon
                                Image(systemName: hour.symbol)
                                    .font(.system(size: 22))
                                    .symbolRenderingMode(.multicolor)
                                    .frame(height: 28)

                                // Rain chance if > 0
                                if hour.precipitationChance > 0 {
                                    Text("\(Int(hour.precipitationChance * 100))%")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.cyan)
                                }

                                // Temperature
                                Text("\(hour.temperature(for: appState.unitSystem))°")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)
                            }
                            .frame(width: 56)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.tertiaryBackground.opacity(0.6))
        )
    }

    // MARK: - Air Quality Section
    private var airQualitySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "aqi.low")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textTertiary)
                    Text("Air quality")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }

                if let aqi = weatherService.airQualityIndex {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(aqiColor(for: aqi))
                            .frame(width: 10, height: 10)

                        Text(aqiLabel(for: aqi))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)

                        Text("· \(aqi) AQI")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.tertiaryBackground.opacity(0.6))
        )
    }

    // MARK: - Weekly Forecast Section
    private var weeklyForecastSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
                Text("7-day forecast")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if weatherService.dailyForecast.isEmpty {
                // Loading/empty state
                VStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { index in
                        HStack(spacing: 12) {
                            Text(index == 0 ? "Today" : "---")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.textTertiary)
                                .frame(width: 50, alignment: .leading)

                            Image(systemName: "cloud.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.textTertiary.opacity(0.5))
                                .frame(width: 28)

                            Spacer()
                                .frame(width: 36)

                            Text("--°")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.textTertiary)
                                .frame(width: 32, alignment: .trailing)

                            Capsule()
                                .fill(Color.textTertiary.opacity(0.2))
                                .frame(height: 4)

                            Text("--°")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.textTertiary)
                                .frame(width: 32, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if index < 6 {
                            Divider()
                                .background(Color.cardBorder)
                                .padding(.leading, 48)
                        }
                    }
                }
                .padding(.bottom, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(weatherService.dailyForecast.enumerated()), id: \.element.id) { index, day in
                        DailyForecastRow(
                            day: day,
                            isToday: index == 0,
                            minTemp: weatherService.dailyForecast.map { $0.lowTemperature(for: appState.unitSystem) }.min() ?? 0,
                            maxTemp: weatherService.dailyForecast.map { $0.highTemperature(for: appState.unitSystem) }.max() ?? 100,
                            unitSystem: appState.unitSystem
                        )

                        if index < weatherService.dailyForecast.count - 1 {
                            Divider()
                                .background(Color.cardBorder)
                                .padding(.leading, 48)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.tertiaryBackground.opacity(0.6))
        )
    }

    // MARK: - Helpers
    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
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

    private func aqiLabel(for aqi: Int) -> String {
        switch aqi {
        case 0...50: return "Good"
        case 51...100: return "Moderate"
        case 101...150: return "Unhealthy for Sensitive"
        case 151...200: return "Unhealthy"
        case 201...300: return "Very Unhealthy"
        default: return "Hazardous"
        }
    }
}

// MARK: - Daily Forecast Row
struct DailyForecastRow: View {
    let day: DailyForecast
    let isToday: Bool
    let minTemp: Int
    let maxTemp: Int
    let unitSystem: UnitSystem

    private var dayName: String {
        if isToday {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: day.date)
    }

    private var tempRange: CGFloat {
        CGFloat(maxTemp - minTemp)
    }

    private var lowTemp: Int {
        day.lowTemperature(for: unitSystem)
    }

    private var highTemp: Int {
        day.highTemperature(for: unitSystem)
    }

    private var barStart: CGFloat {
        guard tempRange > 0 else { return 0 }
        return CGFloat(lowTemp - minTemp) / tempRange
    }

    private var barWidth: CGFloat {
        guard tempRange > 0 else { return 1 }
        return CGFloat(highTemp - lowTemp) / tempRange
    }

    var body: some View {
        HStack(spacing: 12) {
            // Day name
            Text(dayName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 50, alignment: .leading)

            // Weather icon
            Image(systemName: day.symbol)
                .font(.system(size: 20))
                .symbolRenderingMode(.multicolor)
                .frame(width: 28)

            // Rain chance
            if day.precipitationChance > 0 {
                Text("\(Int(day.precipitationChance * 100))%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.cyan)
                    .frame(width: 36, alignment: .leading)
            } else {
                Spacer()
                    .frame(width: 36)
            }

            // Low temp
            Text("\(lowTemp)°")
                .font(.system(size: 16))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 32, alignment: .trailing)

            // Temperature bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.textTertiary.opacity(0.2))
                        .frame(height: 4)

                    // Temperature range bar
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * barWidth, 8), height: 4)
                        .offset(x: geometry.size.width * barStart)
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity)
            }
            .frame(height: 20)

            // High temp
            Text("\(highTemp)°")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 32, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    WeatherSheetView(weatherService: WeatherService.shared)
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
