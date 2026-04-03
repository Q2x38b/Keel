import SwiftUI
import MapKit
import CoreLocation

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var weatherService = WeatherService.shared

    // Day Selection
    @State private var selectedDay: DayOfWeek = .current

    // Settings & Class Creator
    @State private var showSettings = false
    @State private var showingClassCreator = false

    // Map expansion
    @State private var showExpandedMap = false

    // Weather Sheet State
    @State private var showWeatherSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.background
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Header with date picker
                LiquidGlassDateHeader(
                    selectedDay: $selectedDay,
                    showSettings: $showSettings,
                    showingClassCreator: $showingClassCreator
                )

                // Scrollable content area
                ScrollView {
                    VStack(spacing: 16) {
                        // Weather + Map row
                        HStack(spacing: 12) {
                            // Weather widget
                            WeatherWidget(
                                temperature: weatherService.temperature,
                                windSpeed: weatherService.windSpeed,
                                airQualityIndex: weatherService.airQualityIndex,
                                weatherSymbol: weatherService.weatherSymbol
                            )
                            .onTapGesture {
                                HapticManager.shared.buttonTap()
                                showWeatherSheet = true
                            }

                            // Compact Map widget
                            ClassLocationMapWidget(
                                currentLesson: currentLessonForToday,
                                nextLesson: nextLessonForToday?.lesson,
                                locations: appState.locations,
                                userLocation: appState.currentLocation,
                                onTap: {
                                    HapticManager.shared.buttonTap()
                                    showExpandedMap = true
                                }
                            )
                        }
                        .padding(.horizontal, 16)

                        // Schedule list widget
                        ScheduleListWidget(
                            selectedDay: selectedDay,
                            lessonsForDay: lessonsForSelectedDay,
                            allLessons: appState.lessons,
                            locations: appState.locations,
                            currentLesson: currentLessonForToday
                        )
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showExpandedMap) {
            ExpandedMapView(
                currentLesson: currentLessonForToday,
                nextLesson: nextLessonForToday?.lesson,
                locations: appState.locations,
                userLocation: appState.currentLocation
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showWeatherSheet) {
            WeatherSheetView(weatherService: weatherService)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(40)
                .presentationBackground(Color.secondaryBackground)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingClassCreator) {
            ClassCreatorView(selectedDay: selectedDay)
        }
        .onAppear {
            fetchWeatherIfNeeded()
        }
        .task {
            while true {
                try? await Task.sleep(for: .seconds(600))
                fetchWeatherIfNeeded()
            }
        }
    }

    private func fetchWeatherIfNeeded() {
        Task {
            if let location = appState.currentLocation {
                await weatherService.fetchWeather(for: location)
            } else if let firstLocation = appState.locations.first {
                await weatherService.fetchWeather(for: firstLocation.coordinate)
            } else {
                let fallbackLocation = CLLocationCoordinate2D(latitude: 29.5075, longitude: -95.0949)
                await weatherService.fetchWeather(for: fallbackLocation)
            }
        }
    }

    // MARK: - Computed Properties

    private var todayLessons: [Lesson] {
        let todayScheduled = appState.scheduledLessons.filter { $0.dayOfWeek == .current }
        return todayScheduled.compactMap { scheduled in
            appState.lessons.first { $0.id == scheduled.lessonId }
        }
    }

    private var lessonsForSelectedDay: [ScheduledLesson] {
        appState.scheduledLessons.filter { $0.dayOfWeek == selectedDay }
            .sorted { lesson1, lesson2 in
                guard let l1 = appState.lessons.first(where: { $0.id == lesson1.lessonId }),
                      let l2 = appState.lessons.first(where: { $0.id == lesson2.lessonId }) else {
                    return false
                }
                return l1.startTime < l2.startTime
            }
    }

    private var currentLessonForToday: Lesson? {
        appState.currentLesson()
    }

    private var nextLessonForToday: (lesson: Lesson, startsIn: TimeInterval)? {
        appState.nextLesson()
    }
}

// MARK: - Class Location Map Widget
struct ClassLocationMapWidget: View {
    let currentLesson: Lesson?
    let nextLesson: Lesson?
    let locations: [SavedLocation]
    let userLocation: CLLocationCoordinate2D?
    let onTap: () -> Void

    private var displayLesson: Lesson? {
        currentLesson ?? nextLesson
    }

    private var displayLocation: SavedLocation? {
        guard let lesson = displayLesson else {
            return locations.first(where: { $0.type == .school }) ?? locations.first
        }
        return locations.first(where: { $0.id == lesson.locationId })
    }

    private var mapCenter: CLLocationCoordinate2D {
        if let lesson = displayLesson, let coord = lesson.buildingCoordinate {
            return coord
        }
        return displayLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Map
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: mapCenter,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))) {
                    if let location = displayLocation {
                        Marker(location.name, coordinate: location.coordinate)
                            .tint(.red)
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .disabled(true)
                .allowsHitTesting(false)

                // Location label overlay
                if let lesson = displayLesson {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(lesson.room)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.7))
                    )
                    .padding(8)
                }

                // Expand indicator
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Circle().fill(.black.opacity(0.5)))
                            .padding(8)
                    }
                    Spacer()
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.cardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Expanded Map View
struct ExpandedMapView: View {
    let currentLesson: Lesson?
    let nextLesson: Lesson?
    let locations: [SavedLocation]
    let userLocation: CLLocationCoordinate2D?

    @State private var cameraPosition: MapCameraPosition = .automatic
    @Environment(\.dismiss) private var dismiss

    private var displayLesson: Lesson? {
        currentLesson ?? nextLesson
    }

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                if userLocation != nil {
                    UserAnnotation()
                }

                ForEach(locations) { location in
                    Marker(location.name, systemImage: location.iconName, coordinate: location.coordinate)
                        .tint(markerColor(for: location))
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .navigationTitle(displayLesson?.name ?? "Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let lesson = displayLesson, let coord = lesson.buildingCoordinate {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                } else if let location = locations.first(where: { $0.type == .school }) ?? locations.first {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
        }
    }

    private func markerColor(for location: SavedLocation) -> Color {
        switch location.type {
        case .home: return .orange
        case .school: return .green
        case .library: return .blue
        case .office: return .purple
        case .other: return .gray
        }
    }
}

// MARK: - Schedule List Widget
struct ScheduleListWidget: View {
    let selectedDay: DayOfWeek
    let lessonsForDay: [ScheduledLesson]
    let allLessons: [Lesson]
    let locations: [SavedLocation]
    let currentLesson: Lesson?

    private var dayTitle: String {
        if selectedDay == .current {
            return "Today's Schedule"
        } else {
            return "\(selectedDay.name)'s Schedule"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(dayTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("\(lessonsForDay.count) \(lessonsForDay.count == 1 ? "class" : "classes")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }

            // Schedule list
            if lessonsForDay.isEmpty {
                EmptyScheduleCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(lessonsForDay.enumerated()), id: \.element.id) { index, scheduled in
                        if let lesson = allLessons.first(where: { $0.id == scheduled.lessonId }) {
                            ScheduleListRow(
                                lesson: lesson,
                                location: locations.first(where: { $0.id == lesson.locationId }),
                                isActive: selectedDay == .current && currentLesson?.id == lesson.id,
                                repeatPattern: scheduled.repeatPattern
                            )

                            if index < lessonsForDay.count - 1 {
                                Divider()
                                    .padding(.leading, 80)
                            }
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.secondaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.cardBorder, lineWidth: 0.5)
                )
            }
        }
    }
}

// MARK: - Schedule List Row (matches reference image)
struct ScheduleListRow: View {
    let lesson: Lesson
    let location: SavedLocation?
    let isActive: Bool
    let repeatPattern: RepeatPattern

    @State private var isPinned: Bool = false

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    private var indicatorColor: Color {
        if isActive {
            return .red
        } else {
            return lesson.color.color
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeFormatter.string(from: lesson.startTime))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)

                Text(timeFormatter.string(from: lesson.endTime))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(width: 65, alignment: .trailing)

            // Colored indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(indicatorColor)
                .frame(width: 4, height: 44)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title row with icons
                HStack(spacing: 6) {
                    Text(lesson.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    // Location icon
                    if location != nil {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                    }

                    // Repeat icon
                    if repeatPattern != .once {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                // Subtitle: Room
                Text(lesson.room)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Pin button
            Button {
                HapticManager.shared.buttonTap()
                isPinned.toggle()
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isPinned ? lesson.color.color : Color.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.tertiaryBackground)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Empty Schedule Card
struct EmptyScheduleCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 32))
                .foregroundStyle(Color.textTertiary)

            Text("No classes scheduled")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textSecondary)

            Text("Enjoy your free day!")
                .font(.system(size: 13))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var classReminders = true
    @State private var reminderTime = 15
    @State private var showOnLockScreen = true
    @State private var dynamicIsland = true

    var body: some View {
        NavigationStack {
            List {
                Section("Notifications") {
                    Toggle("Class Reminders", isOn: $classReminders)
                        .onChange(of: classReminders) { _, _ in
                            HapticManager.shared.toggle()
                        }
                    Picker("Reminder Time", selection: $reminderTime) {
                        Text("5 minutes before").tag(5)
                        Text("10 minutes before").tag(10)
                        Text("15 minutes before").tag(15)
                        Text("30 minutes before").tag(30)
                    }
                    .onChange(of: reminderTime) { _, _ in
                        HapticManager.shared.selection()
                    }
                }

                Section("Live Activities") {
                    Toggle("Show on Lock Screen", isOn: $showOnLockScreen)
                        .onChange(of: showOnLockScreen) { _, _ in
                            HapticManager.shared.toggle()
                        }
                    Toggle("Dynamic Island", isOn: $dynamicIsland)
                        .onChange(of: dynamicIsland) { _, _ in
                            HapticManager.shared.toggle()
                        }
                }

                Section("Data") {
                    Button("Sync with iCloud") {
                        HapticManager.shared.buttonTap()
                        appState.loadData()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.dismiss()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - DayOfWeek Extension
extension DayOfWeek {
    var twoLetterName: String {
        switch self {
        case .monday: return "Mo"
        case .tuesday: return "Tu"
        case .wednesday: return "We"
        case .thursday: return "Th"
        case .friday: return "Fr"
        case .saturday: return "Sa"
        case .sunday: return "Su"
        }
    }
}

// MARK: - Liquid Glass Date Header
struct LiquidGlassDateHeader: View {
    @Binding var selectedDay: DayOfWeek
    @Binding var showSettings: Bool
    @Binding var showingClassCreator: Bool

    private var weekDays: [(day: DayOfWeek, date: Int, isToday: Bool, fullDate: Date)] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)

        let daysFromMonday = (weekday - 2 + 7) % 7
        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return []
        }

        let orderedDays: [DayOfWeek] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else {
                return nil
            }
            let dayNumber = calendar.component(.day, from: date)
            let dayOfWeek = orderedDays[offset]
            let isToday = calendar.isDateInToday(date)
            return (dayOfWeek, dayNumber, isToday, date)
        }
    }

    private var dateForSelectedDay: Date {
        weekDays.first { $0.day == selectedDay }?.fullDate ?? Date()
    }

    private var formattedDateTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: dateForSelectedDay)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                // Top row: Date title with dropdown, action buttons
                HStack(alignment: .center) {
                    Button {
                        HapticManager.shared.buttonTap()
                    } label: {
                        HStack(spacing: 5) {
                            Text(formattedDateTitle)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.textPrimary)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 0) {
                        Button {
                            HapticManager.shared.buttonTap()
                            showingClassCreator = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(LiquidGlassButtonStyle())

                        Button {
                            HapticManager.shared.buttonTap()
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                    }
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 54)

                // Week day picker
                HStack(spacing: 5) {
                    ForEach(weekDays, id: \.day) { item in
                        Button {
                            if selectedDay != item.day {
                                HapticManager.shared.selection()
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedDay = item.day
                            }
                        } label: {
                            VStack(spacing: 1) {
                                Text(item.day.initial)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(selectedDay == item.day ? Color.white.opacity(0.7) : Color.textTertiary)

                                Text("\(item.date)")
                                    .font(.system(size: 16, weight: selectedDay == item.day ? .bold : .medium))
                                    .foregroundStyle(selectedDay == item.day ? Color.white : Color.textPrimary)
                            }
                            .frame(width: 40, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selectedDay == item.day ? Color.black : Color.white.opacity(0.001))
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .opacity(selectedDay == item.day ? 0 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(Color.secondaryBackground)
        }
    }
}

// MARK: - Preview
#Preview {
    DashboardView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
