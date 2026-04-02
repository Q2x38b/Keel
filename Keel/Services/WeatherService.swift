import Foundation
import WeatherKit
import CoreLocation

// MARK: - Hourly Forecast Model
struct HourlyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let temperature: Int
    let symbol: String
    let precipitationChance: Double
}

// MARK: - Daily Forecast Model
struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let highTemperature: Int
    let lowTemperature: Int
    let symbol: String
    let precipitationChance: Double
}

@MainActor
class WeatherService: ObservableObject {
    static let shared = WeatherService()

    // Current weather
    @Published var temperature: Int?
    @Published var windSpeed: Int?
    @Published var airQualityIndex: Int?
    @Published var airQualityCategory: AirQualityCategory = .good
    @Published var weatherSymbol: String = "cloud.fill"
    @Published var conditionDescription: String = "Partly Cloudy"
    @Published var feelsLike: Int?
    @Published var highTemperature: Int?
    @Published var lowTemperature: Int?
    @Published var locationName: String = ""

    // Hourly forecast (next 6 hours)
    @Published var hourlyForecast: [HourlyForecast] = []

    // Daily forecast (7 days)
    @Published var dailyForecast: [DailyForecast] = []

    @Published var isLoading = false
    @Published var lastUpdate: Date?

    private let weatherService = WeatherKit.WeatherService.shared
    private let geocoder = CLGeocoder()

    private init() {}

    func fetchWeather(for location: CLLocationCoordinate2D) async {
        isLoading = true
        defer { isLoading = false }

        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        do {
            let weather = try await weatherService.weather(for: clLocation)

            // Current temperature in Fahrenheit
            temperature = Int(weather.currentWeather.temperature.converted(to: .fahrenheit).value)

            // Feels like temperature
            feelsLike = Int(weather.currentWeather.apparentTemperature.converted(to: .fahrenheit).value)

            // Wind speed in mph
            windSpeed = Int(weather.currentWeather.wind.speed.converted(to: .milesPerHour).value)

            // Weather symbol and condition
            weatherSymbol = weather.currentWeather.symbolName
            conditionDescription = weather.currentWeather.condition.description

            // Today's high/low from daily forecast
            if let todayForecast = weather.dailyForecast.first {
                highTemperature = Int(todayForecast.highTemperature.converted(to: .fahrenheit).value)
                lowTemperature = Int(todayForecast.lowTemperature.converted(to: .fahrenheit).value)
            }

            // Hourly forecast (next 6 hours)
            hourlyForecast = Array(weather.hourlyForecast.prefix(6)).map { hour in
                HourlyForecast(
                    date: hour.date,
                    temperature: Int(hour.temperature.converted(to: .fahrenheit).value),
                    symbol: hour.symbolName,
                    precipitationChance: hour.precipitationChance
                )
            }

            // Daily forecast (7 days)
            dailyForecast = Array(weather.dailyForecast.prefix(7)).map { day in
                DailyForecast(
                    date: day.date,
                    highTemperature: Int(day.highTemperature.converted(to: .fahrenheit).value),
                    lowTemperature: Int(day.lowTemperature.converted(to: .fahrenheit).value),
                    symbol: day.symbolName,
                    precipitationChance: day.precipitationChance
                )
            }

            lastUpdate = Date()

            // Fetch location name
            await fetchLocationName(for: clLocation)

            // Fetch air quality if available
            await fetchAirQuality(for: clLocation)

        } catch {
            print("[Weather] Failed to fetch weather: \(error.localizedDescription)")
            print("[Weather] Error details: \(error)")
        }
    }

    private func fetchLocationName(for location: CLLocation) async {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                locationName = placemark.locality ?? placemark.administrativeArea ?? "Current Location"
            }
        } catch {
            locationName = "Current Location"
        }
    }

    private func fetchAirQuality(for location: CLLocation) async {
        // WeatherKit doesn't directly provide AQI, so we'll estimate based on conditions
        // In a production app, you'd use a dedicated air quality API
        // For now, we'll show a placeholder or use visibility as a proxy

        // Default to good air quality
        airQualityIndex = 50
        airQualityCategory = .good
    }
}

enum AirQualityCategory {
    case good       // 0-50
    case moderate   // 51-100
    case unhealthySensitive // 101-150
    case unhealthy  // 151-200
    case veryUnhealthy // 201-300
    case hazardous  // 301+
    
    var color: String {
        switch self {
        case .good: return "green"
        case .moderate: return "yellow"
        case .unhealthySensitive: return "orange"
        case .unhealthy: return "red"
        case .veryUnhealthy: return "purple"
        case .hazardous: return "maroon"
        }
    }
    
    static func from(aqi: Int) -> AirQualityCategory {
        switch aqi {
        case 0...50: return .good
        case 51...100: return .moderate
        case 101...150: return .unhealthySensitive
        case 151...200: return .unhealthy
        case 201...300: return .veryUnhealthy
        default: return .hazardous
        }
    }
}
