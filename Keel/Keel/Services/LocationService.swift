import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()

    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastUpdateTime: Date = Date()

    var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 5 // Update every 5 meters for precise tracking
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .otherNavigation
    }

    // MARK: - Public Methods

    func requestPermission() {
        // Request "Always" authorization for background updates
        locationManager.requestAlwaysAuthorization()
    }

    func enableBackgroundUpdates() {
        // Enable background location updates for live activity support
        if authorizationStatus == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
            print("[Location] Background updates enabled")
        }
    }

    func disableBackgroundUpdates() {
        // Disable background location updates when no live activity
        locationManager.allowsBackgroundLocationUpdates = false
        print("[Location] Background updates disabled")
    }

    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }

        // Don't enable background updates here - only enable when live activity is active
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
    }

    func requestCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        locationManager.requestLocation()
    }

    // MARK: - Distance & Bearing

    func distance(from coordinate1: CLLocationCoordinate2D, to coordinate2: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: coordinate1.latitude, longitude: coordinate1.longitude)
        let location2 = CLLocation(latitude: coordinate2.latitude, longitude: coordinate2.longitude)
        return location1.distance(from: location2)
    }

    func isNearLocation(_ savedLocation: SavedLocation, threshold: CLLocationDistance = 100) -> Bool {
        guard let current = currentLocation else { return false }
        return savedLocation.distance(from: current) <= threshold
    }

    func nearestLocation(from locations: [SavedLocation]) -> SavedLocation? {
        guard let current = currentLocation else { return nil }

        return locations.min { loc1, loc2 in
            loc1.distance(from: current) < loc2.distance(from: current)
        }
    }

    // MARK: - Geocoding

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let placemarks = try await geocoder.reverseGeocodeLocation(location)

        guard let placemark = placemarks.first else { return nil }

        var addressParts: [String] = []

        if let streetNumber = placemark.subThoroughfare {
            addressParts.append(streetNumber)
        }
        if let street = placemark.thoroughfare {
            addressParts.append(street)
        }
        if let city = placemark.locality {
            addressParts.append(city)
        }

        return addressParts.isEmpty ? nil : addressParts.joined(separator: " ")
    }

    func geocode(address: String) async throws -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(address)

        return placemarks.first?.location?.coordinate
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Get the most accurate recent location
        guard let location = locations.last else { return }

        // Accept the location if we don't have one yet (first location)
        // Or if it meets our accuracy requirements
        let isFirstLocation = currentLocation == nil
        let isAccurate = location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100
        let isRecent = abs(location.timestamp.timeIntervalSinceNow) < 30

        // Always accept first location, otherwise filter for quality
        guard isFirstLocation || (isAccurate && isRecent) else {
            print("[Location] Skipping location: accuracy=\(location.horizontalAccuracy)m, age=\(abs(location.timestamp.timeIntervalSinceNow))s")
            return
        }

        currentLocation = location.coordinate
        lastUpdateTime = Date()
        onLocationUpdate?(location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            // Start tracking but don't enable background updates yet
            // Background updates are only enabled when a live activity is active
            startTracking()
        case .denied, .restricted:
            stopTracking()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Location State
enum LocationState {
    case unknown
    case atHome
    case atSchool(SavedLocation)
    case onTheWay(to: SavedLocation)
    case elsewhere

    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .atHome: return "At Home"
        case .atSchool(let location): return "At \(location.name)"
        case .onTheWay(let location): return "On the way to \(location.name)"
        case .elsewhere: return "Elsewhere"
        }
    }
}

extension LocationService {
    func determineState(locations: [SavedLocation]) -> LocationState {
        guard let current = currentLocation else { return .unknown }

        // Check if at home
        if let home = locations.first(where: { $0.type == .home }),
           home.isNearby(current, threshold: 100) {
            return .atHome
        }

        // Check if at any school
        if let school = locations.first(where: { $0.type == .school && $0.isNearby(current, threshold: 100) }) {
            return .atSchool(school)
        }

        // Check if on the way to school (between home and school)
        if let home = locations.first(where: { $0.type == .home }),
           let nearestSchool = locations.filter({ $0.type == .school }).min(by: { $0.distance(from: current) < $1.distance(from: current) }) {

            let distanceToHome = home.distance(from: current)
            let distanceToSchool = nearestSchool.distance(from: current)
            let totalDistance = home.distance(from: nearestSchool.coordinate)

            // If we're between home and school (within reasonable bounds)
            if distanceToHome > 100 && distanceToSchool > 100 && distanceToHome + distanceToSchool < totalDistance * 1.5 {
                return .onTheWay(to: nearestSchool)
            }
        }

        return .elsewhere
    }
}
