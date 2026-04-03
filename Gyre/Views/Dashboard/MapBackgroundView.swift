import SwiftUI
import MapKit

struct MapBackgroundView: View {
    @Binding var cameraPosition: MapCameraPosition
    let userLocation: CLLocationCoordinate2D?
    let savedLocations: [SavedLocation]
    let todayLessons: [Lesson]
    let isOnline: Bool

    var body: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
            // User location marker
            if let userLoc = userLocation {
                Annotation("", coordinate: userLoc) {
                    UserLocationMarker()
                }
            }

            // Saved location markers
            ForEach(savedLocations) { location in
                Annotation("", coordinate: location.coordinate) {
                    LocationTypeMarker(
                        iconName: location.iconName,
                        color: iconColor(for: location.type)
                    )
                }
            }

            // Building markers for today's lessons with coordinates
            ForEach(todayLessons.filter { $0.hasBuildingLocation }, id: \.id) { lesson in
                if let coord = lesson.buildingCoordinate {
                    Annotation("", coordinate: coord) {
                        LessonBuildingMarker(lesson: lesson)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControlVisibility(.hidden)
        .saturation(isOnline ? 1.0 : 0.3)
        .opacity(isOnline ? 1.0 : 0.7)
        // Offset the map down to push the Apple logo out of the visible viewport
        .offset(y: -100)
        // Scale up to fill the gap created by the offset
        .scaleEffect(1.25, anchor: .center)
    }

    private func iconColor(for type: LocationType) -> Color {
        switch type {
        case .home: return Color.locationHome
        case .school: return Color.locationSchool
        case .library: return Color.locationLibrary
        case .office: return Color.locationOffice
        case .other: return Color.locationOther
        }
    }
}

// MARK: - Lesson Building Marker
struct LessonBuildingMarker: View {
    let lesson: Lesson

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(lesson.color.color.opacity(0.25))
                .frame(width: 40, height: 40)

            // Main circle
            Circle()
                .fill(lesson.color.color)
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            // Icon
            Image(systemName: "building.2.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Map Control Buttons
struct MapControlButtons: View {
    let onCenterUser: () -> Void
    let onCenterSchool: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Center on user
            Button(action: {
                HapticManager.shared.mapFocus()
                onCenterUser()
            }) {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(HapticButtonStyle(hapticStyle: .button, scaleEffect: 0.92))

            // Center on school
            Button(action: {
                HapticManager.shared.mapFocus()
                onCenterSchool()
            }) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(HapticButtonStyle(hapticStyle: .button, scaleEffect: 0.92))
        }
    }
}
