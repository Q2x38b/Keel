import SwiftUI
import MapKit

// MARK: - AnyShape Type Eraser
struct AnyShape: Shape {
    private let pathBuilder: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

struct LocationCard: View {
    let location: SavedLocation
    let userLocation: CLLocationCoordinate2D?
    let isOnline: Bool
    let currentLesson: Lesson?
    let nextLesson: (lesson: Lesson, startsIn: TimeInterval)?
    let todayLessonsCount: Int
    let dayEndsAt: Date?
    let isCurrentLocation: Bool

    private var status: LessonStatus {
        if let current = currentLesson {
            let now = Date()
            let calendar = Calendar.current
            let endComponents = calendar.dateComponents([.hour, .minute], from: current.endTime)
            var todayEnd = calendar.dateComponents([.year, .month, .day], from: now)
            todayEnd.hour = endComponents.hour
            todayEnd.minute = endComponents.minute

            if let end = calendar.date(from: todayEnd) {
                return .live(endsIn: end.timeIntervalSince(now))
            }
            return .live(endsIn: 0)
        } else if let next = nextLesson {
            return .upcoming(startsIn: next.startsIn)
        } else {
            return .noLessons
        }
    }

    private var isOnTheWay: Bool {
        if let userLoc = userLocation {
            return !location.isNearby(userLoc, threshold: 200) && isCurrentLocation
        }
        return false
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
        ZStack(alignment: .bottom) {
            // Large Map Background - zooms to building if available
            FullSizeMapWidget(
                location: location,
                buildingCoordinate: currentLesson?.buildingCoordinate ?? nextLesson?.lesson.buildingCoordinate,
                userLocation: userLocation,
                isOnTheWay: isOnTheWay,
                isOnline: isOnline
            )
            .frame(height: 300)

            // Top blur header with icon and name
            VStack {
                HStack(spacing: 10) {
                    // Location Icon
                    ZStack {
                        Circle()
                            .fill(iconColor)
                            .frame(width: 32, height: 32)

                        Image(systemName: location.iconName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    // Location Name
                    Text(isOnTheWay ? "On the Way" : location.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.5), Color.black.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Spacer()
            }

            // Bottom floating card - connected lesson card and footer
            VStack(spacing: 0) {
                // Lesson Card
                LessonCardOverlay(
                    status: status,
                    currentLesson: currentLesson,
                    nextLesson: nextLesson?.lesson,
                    hasFooter: todayLessonsCount > 0
                )

                // Classes count footer - connected to main card
                if todayLessonsCount > 0 {
                    ClassesCountFooter(count: todayLessonsCount)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.cardBackground)
        )
    }
}

// MARK: - Lesson Card Overlay
struct LessonCardOverlay: View {
    let status: LessonStatus
    let currentLesson: Lesson?
    let nextLesson: Lesson?
    var hasFooter: Bool = false

    private var activeLesson: Lesson? {
        currentLesson ?? nextLesson
    }

    private var progress: Double {
        guard let lesson = currentLesson, case .live = status else { return 0 }

        let now = Date()
        let calendar = Calendar.current

        let startComponents = calendar.dateComponents([.hour, .minute], from: lesson.startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: lesson.endTime)

        var todayStart = calendar.dateComponents([.year, .month, .day], from: now)
        todayStart.hour = startComponents.hour
        todayStart.minute = startComponents.minute

        var todayEnd = calendar.dateComponents([.year, .month, .day], from: now)
        todayEnd.hour = endComponents.hour
        todayEnd.minute = endComponents.minute

        guard let start = calendar.date(from: todayStart),
              let end = calendar.date(from: todayEnd) else {
            return 0
        }

        let total = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        return min(max(elapsed / total, 0), 1)
    }

    private var cardShape: some Shape {
        if hasFooter {
            return AnyShape(UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 22,
                style: .continuous
            ))
        } else {
            return AnyShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Background with liquid glass effect
            cardShape
                .fill(.ultraThinMaterial)

            // Progress fill for live lessons - properly clipped
            if case .live = status, let lesson = currentLesson {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(lesson.color.color.opacity(0.2))
                        .frame(width: geometry.size.width * progress)
                }
                .clipShape(cardShape)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Status row
                HStack {
                    Text(statusText)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(statusColor)

                    Spacer()

                    if let timeText = timeIndicatorText {
                        Text(timeText)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(statusColor)
                    }
                }

                if let lesson = activeLesson {
                    // Lesson name
                    Text(lesson.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    // Time and Room
                    HStack(spacing: 12) {
                        HStack(spacing: 3) {
                            Image(systemName: "alarm")
                                .font(.system(size: 10))
                            Text(timeText(for: lesson))
                                .font(.caption2)
                        }
                        .foregroundStyle(timeColor)

                        HStack(spacing: 3) {
                            Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                                .font(.system(size: 10))
                            Text(lesson.room)
                                .font(.caption2)
                        }
                        .foregroundStyle(Color.textSecondary)
                    }
                } else {
                    Text("No upcoming sessions")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(14)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statusText: String {
        switch status {
        case .live: return "NOW"
        case .upcoming: return "UPCOMING"
        case .noLessons, .ended: return "NO SESSION"
        }
    }

    private var statusColor: Color {
        switch status {
        case .live: return .red
        case .upcoming: return .orange
        case .noLessons, .ended: return Color.textSecondary
        }
    }

    private var timeIndicatorText: String? {
        switch status {
        case .live(let endsIn):
            let minutes = Int(endsIn / 60)
            return "\(minutes)m left"
        case .upcoming(let startsIn):
            let minutes = Int(startsIn / 60)
            if minutes >= 60 {
                let hours = minutes / 60
                let mins = minutes % 60
                return "in \(hours)h \(mins)m"
            }
            return "in \(minutes)m"
        case .noLessons, .ended:
            return nil
        }
    }

    private var timeColor: Color {
        switch status {
        case .live: return .green
        case .upcoming: return .blue
        default: return Color.textSecondary
        }
    }

    private func timeText(for lesson: Lesson) -> String {
        switch status {
        case .live:
            return "Ends \(lesson.formattedEndTime)"
        case .upcoming:
            return "Starts \(lesson.formattedStartTime)"
        default:
            return lesson.formattedTimeRange
        }
    }
}

// MARK: - Classes Count Footer
struct ClassesCountFooter: View {
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 10))
            Text("\(count) sessions today")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 22,
                bottomTrailingRadius: 22,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Full Size Map Widget
struct FullSizeMapWidget: View {
    let location: SavedLocation
    let buildingCoordinate: CLLocationCoordinate2D?
    let userLocation: CLLocationCoordinate2D?
    let isOnTheWay: Bool
    let isOnline: Bool

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

    init(location: SavedLocation, buildingCoordinate: CLLocationCoordinate2D? = nil, userLocation: CLLocationCoordinate2D?, isOnTheWay: Bool, isOnline: Bool) {
        self.location = location
        self.buildingCoordinate = buildingCoordinate
        self.userLocation = userLocation
        self.isOnTheWay = isOnTheWay
        self.isOnline = isOnline

        let center: CLLocationCoordinate2D
        let span: MKCoordinateSpan

        if let userLoc = userLocation, isOnTheWay {
            let targetCoord = buildingCoordinate ?? location.coordinate
            center = CLLocationCoordinate2D(
                latitude: (targetCoord.latitude + userLoc.latitude) / 2,
                longitude: (targetCoord.longitude + userLoc.longitude) / 2
            )
            let latDiff = abs(targetCoord.latitude - userLoc.latitude)
            let lonDiff = abs(targetCoord.longitude - userLoc.longitude)
            let maxDiff = max(latDiff, lonDiff)
            span = MKCoordinateSpan(
                latitudeDelta: max(maxDiff * 2.0, 0.01),
                longitudeDelta: max(maxDiff * 2.0, 0.01)
            )
        } else if let building = buildingCoordinate {
            // Zoom to specific building on campus
            center = building
            span = MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
        } else {
            center = location.coordinate
            span = MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        }

        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: center,
            span: span
        )))
    }

    private var mapCenter: CLLocationCoordinate2D {
        buildingCoordinate ?? location.coordinate
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: .constant(cameraPosition), interactionModes: []) {
                // Building marker if specific building location
                if let building = buildingCoordinate {
                    Annotation("", coordinate: building) {
                        BuildingMarker()
                    }
                }

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
            .mapControlVisibility(.hidden)
            .saturation(isOnline ? 1.0 : 0.3)
            .opacity(isOnline ? 1.0 : 0.7)
            .allowsHitTesting(false)

            // Cover Apple Maps attribution
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 50)
        }
    }
}

// MARK: - Building Marker
struct BuildingMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accent)
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            Image(systemName: "building.2.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Offline Location Card
struct OfflineLocationCard: View {
    let location: SavedLocation

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
        ZStack(alignment: .bottom) {
            // Large Map Background (grayscale)
            FullSizeMapWidget(
                location: location,
                buildingCoordinate: nil,
                userLocation: nil,
                isOnTheWay: false,
                isOnline: false
            )
            .frame(height: 200)

            // Top blur header with icon and name
            VStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(iconColor)
                            .frame(width: 32, height: 32)

                        Image(systemName: location.iconName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text(location.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.5), Color.black.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Spacer()
            }

            // Bottom floating card
            VStack(spacing: 0) {
                LessonCardOverlay(
                    status: .noLessons,
                    currentLesson: nil,
                    nextLesson: nil
                )
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.cardBackground)
        )
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Offline/Home Card
            OfflineLocationCard(location: SavedLocation.samples[0])
                .padding(.horizontal)

            // On the Way Card
            LocationCard(
                location: SavedLocation.samples[1],
                userLocation: CLLocationCoordinate2D(latitude: 37.7799, longitude: -122.4144),
                isOnline: true,
                currentLesson: nil,
                nextLesson: (Lesson.samples[0], 900),
                todayLessonsCount: 6,
                dayEndsAt: Calendar.current.date(bySettingHour: 16, minute: 45, second: 0, of: Date()),
                isCurrentLocation: true
            )
            .padding(.horizontal)

            // At School - Live Lesson Card
            LocationCard(
                location: SavedLocation.samples[1],
                userLocation: SavedLocation.samples[1].coordinate,
                isOnline: true,
                currentLesson: Lesson.samples[1],
                nextLesson: nil,
                todayLessonsCount: 4,
                dayEndsAt: Calendar.current.date(bySettingHour: 16, minute: 45, second: 0, of: Date()),
                isCurrentLocation: true
            )
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    .background(Color.background)
    .preferredColorScheme(.dark)
}
