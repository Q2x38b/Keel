import SwiftUI
import MapKit

struct MapWidget: View {
    let coordinate: CLLocationCoordinate2D
    let userLocation: CLLocationCoordinate2D?
    let showsRoute: Bool
    let height: CGFloat

    @State private var cameraPosition: MapCameraPosition

    init(
        coordinate: CLLocationCoordinate2D,
        userLocation: CLLocationCoordinate2D? = nil,
        showsRoute: Bool = false,
        height: CGFloat = 120
    ) {
        self.coordinate = coordinate
        self.userLocation = userLocation
        self.showsRoute = showsRoute
        self.height = height

        // Calculate center based on both points if user location exists
        let center: CLLocationCoordinate2D
        let span: MKCoordinateSpan

        if let userLoc = userLocation {
            // Center between user and destination
            center = CLLocationCoordinate2D(
                latitude: (coordinate.latitude + userLoc.latitude) / 2,
                longitude: (coordinate.longitude + userLoc.longitude) / 2
            )
            // Adjust span to show both points
            let latDiff = abs(coordinate.latitude - userLoc.latitude)
            let lonDiff = abs(coordinate.longitude - userLoc.longitude)
            let maxDiff = max(latDiff, lonDiff)
            span = MKCoordinateSpan(
                latitudeDelta: max(maxDiff * 1.8, 0.008),
                longitudeDelta: max(maxDiff * 1.8, 0.008)
            )
        } else {
            center = coordinate
            span = MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
        }

        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: center,
            span: span
        )))
    }

    var body: some View {
        Map(position: .constant(cameraPosition), interactionModes: []) {
            // Destination marker
            Annotation("", coordinate: coordinate) {
                DestinationMarker()
            }

            // User location marker
            if let userLoc = userLocation {
                Annotation("", coordinate: userLoc) {
                    UserLocationMarker()
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Map Annotation Item
struct MapAnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let type: MarkerType

    enum MarkerType {
        case user
        case destination
    }
}

// MARK: - User Location Marker
struct UserLocationMarker: View {
    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .fill(Color.statusOnline.opacity(0.2))
                .frame(width: 32, height: 32)

            // Middle ring
            Circle()
                .fill(Color.statusOnline)
                .frame(width: 16, height: 16)

            // White border
            Circle()
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 16, height: 16)
        }
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Destination Marker
struct DestinationMarker: View {
    var body: some View {
        VStack(spacing: 0) {
            // Pin head
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
            }

            // Pin point
            Triangle()
                .fill(Color.red)
                .frame(width: 14, height: 10)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Location Marker (legacy support)
struct LocationMarker: View {
    let type: MapAnnotationItem.MarkerType

    var body: some View {
        ZStack {
            switch type {
            case .user:
                UserLocationMarker()
            case .destination:
                DestinationMarker()
            }
        }
    }
}

// MARK: - Compact Map Widget (for dashboard cards)
struct CompactMapWidget: View {
    let location: SavedLocation
    let userLocation: CLLocationCoordinate2D?
    let isOnTheWay: Bool

    @State private var cameraPosition: MapCameraPosition

    private var iconColor: Color {
        switch location.type {
        case .home: return Color.locationHome
        case .school: return Color.locationSchool
        case .library: return Color.locationLibrary
        case .office: return Color.locationOffice
        case .other: return Color.locationOther
        }
    }

    init(location: SavedLocation, userLocation: CLLocationCoordinate2D?, isOnTheWay: Bool) {
        self.location = location
        self.userLocation = userLocation
        self.isOnTheWay = isOnTheWay

        // Calculate center based on both points if user location exists
        let center: CLLocationCoordinate2D
        let span: MKCoordinateSpan

        if let userLoc = userLocation, isOnTheWay {
            // Center between user and destination
            center = CLLocationCoordinate2D(
                latitude: (location.coordinate.latitude + userLoc.latitude) / 2,
                longitude: (location.coordinate.longitude + userLoc.longitude) / 2
            )
            // Adjust span to show both points
            let latDiff = abs(location.coordinate.latitude - userLoc.latitude)
            let lonDiff = abs(location.coordinate.longitude - userLoc.longitude)
            let maxDiff = max(latDiff, lonDiff)
            span = MKCoordinateSpan(
                latitudeDelta: max(maxDiff * 1.8, 0.008),
                longitudeDelta: max(maxDiff * 1.8, 0.008)
            )
        } else {
            center = location.coordinate
            span = MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
        }

        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: center,
            span: span
        )))
    }

    var body: some View {
        Map(position: .constant(cameraPosition), interactionModes: []) {
            // Location marker with custom icon
            Annotation("", coordinate: location.coordinate) {
                LocationTypeMarker(iconName: location.iconName, color: iconColor)
            }

            // User location
            if let userLoc = userLocation {
                Annotation("", coordinate: userLoc) {
                    UserLocationMarker()
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }
}

// MARK: - Location Type Marker
struct LocationTypeMarker: View {
    let iconName: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: 36, height: 36)

            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Dashboard Map Widget
struct DashboardMapWidget: View {
    let location: SavedLocation
    let userLocation: CLLocationCoordinate2D?
    let isOnline: Bool

    @State private var cameraPosition: MapCameraPosition

    init(location: SavedLocation, userLocation: CLLocationCoordinate2D?, isOnline: Bool) {
        self.location = location
        self.userLocation = userLocation
        self.isOnline = isOnline

        let center = userLocation ?? location.coordinate
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
        )))
    }

    private var iconColor: Color {
        switch location.type {
        case .home: return Color.locationHome
        case .school: return Color.locationSchool
        case .library: return Color.locationLibrary
        case .office: return Color.locationOffice
        case .other: return Color.locationOther
        }
    }

    var body: some View {
        Map(position: .constant(cameraPosition), interactionModes: []) {
            // Location marker
            Annotation("", coordinate: location.coordinate) {
                LocationTypeMarker(iconName: location.iconName, color: iconColor)
            }

            // User location
            if let userLoc = userLocation {
                Annotation("", coordinate: userLoc) {
                    UserLocationMarker()
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .saturation(isOnline ? 1.0 : 0.3)
        .opacity(isOnline ? 1.0 : 0.7)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        MapWidget(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            userLocation: CLLocationCoordinate2D(latitude: 37.7739, longitude: -122.4184),
            showsRoute: true
        )
        .padding()

        MapWidget(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        )
        .padding()
    }
    .background(Color.background)
    .preferredColorScheme(.dark)
}
