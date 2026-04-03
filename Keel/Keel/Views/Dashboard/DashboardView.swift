import SwiftUI
import MapKit
import CoreLocation

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var weatherService = WeatherService.shared

    // Map State
    @State private var cameraPosition: MapCameraPosition = .automatic

    // Sheet State
    @State private var sheetDetent: PresentationDetent = .height(240)

    // Weather Sheet State
    @State private var showWeatherSheet = false

    // Day Selection
    @State private var selectedDay: DayOfWeek = .current

    var body: some View {
        ZStack(alignment: .bottom) {
            // Layer 1: Full-screen map
            MapBackgroundView(
                cameraPosition: $cameraPosition,
                userLocation: appState.currentLocation,
                savedLocations: appState.locations,
                todayLessons: todayLessons,
                isOnline: appState.isOnline
            )
            .ignoresSafeArea()

            // Layer 2: Liquid Glass Header at top
            VStack {
                DashboardLiquidGlassHeader(
                    selectedDay: $selectedDay,
                    weatherService: weatherService,
                    onWeatherTap: {
                        HapticManager.shared.buttonTap()
                        showWeatherSheet = true
                    }
                )

                Spacer()
            }

            // Layer 3: Bottom overlay - floating card + map controls
            VStack(spacing: 12) {
                // Map controls (right side)
                HStack {
                    Spacer()
                    MapControlButtons(
                        onCenterUser: centerOnUser,
                        onCenterSchool: centerOnSchool
                    )
                }
                .padding(.horizontal, 16)

                // Floating current class card - just above sheet
                CurrentClassCard(
                    currentLesson: currentLessonForToday,
                    nextLesson: nextLessonForToday,
                    nearestLocation: nearestLocation,
                    onTap: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if sheetDetent == .height(240) {
                                sheetDetent = .medium
                            }
                        }
                    }
                )
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 250) // Above sheet when collapsed
        }
        .sheet(isPresented: .constant(true)) {
            ScheduleSheetView(
                selectedDay: $selectedDay,
                currentDetent: $sheetDetent,
                lessonsForDay: lessonsForSelectedDay,
                allLessons: appState.lessons,
                locations: appState.locations,
                currentLesson: currentLessonForToday
            )
            .presentationDetents([.height(240), .medium, .large], selection: $sheetDetent)
            .presentationDragIndicator(.hidden)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .presentationCornerRadius(40)
            .presentationBackground(Color.secondaryBackground)
            .interactiveDismissDisabled()
        }
        .onChange(of: sheetDetent) { _, _ in
            HapticManager.shared.sheetSnap()
        }
        .sheet(isPresented: $showWeatherSheet) {
            WeatherSheetView(weatherService: weatherService)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(40)
                .presentationBackground(Color.secondaryBackground)
        }
        .onAppear {
            initializeCamera()
            fetchWeatherIfNeeded()
        }
        .task {
            // Refresh weather every 10 minutes
            while true {
                try? await Task.sleep(for: .seconds(600))
                fetchWeatherIfNeeded()
            }
        }
    }

    private func fetchWeatherIfNeeded() {
        Task {
            // Fetch weather using best available location
            if let location = appState.currentLocation {
                await weatherService.fetchWeather(for: location)
            } else if let firstLocation = appState.locations.first {
                await weatherService.fetchWeather(for: firstLocation.coordinate)
            } else {
                // Fallback to League City, TX if no location available
                let fallbackLocation = CLLocationCoordinate2D(latitude: 29.5075, longitude: -95.0949)
                await weatherService.fetchWeather(for: fallbackLocation)
            }
        }
    }

    // MARK: - Computed Properties

    private var nearestLocation: SavedLocation? {
        guard let userLocation = appState.currentLocation else {
            return appState.locations.first
        }
        return appState.locations.min { loc1, loc2 in
            loc1.distance(from: userLocation) < loc2.distance(from: userLocation)
        }
    }

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

    // MARK: - Map Actions

    private func initializeCamera() {
        // Center on nearest school or user location
        if let school = appState.locations.first(where: { $0.type == .school }) {
            cameraPosition = .region(MKCoordinateRegion(
                center: school.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            ))
        } else if let userLoc = appState.currentLocation {
            cameraPosition = .region(MKCoordinateRegion(
                center: userLoc,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }

    private func centerOnUser() {
        guard let userLoc = appState.currentLocation else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: userLoc,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            ))
        }
    }

    private func centerOnSchool() {
        guard let school = appState.locations.first(where: { $0.type == .school }) else {
            // Fallback to first location
            guard let first = appState.locations.first else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: first.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
            }
            return
        }
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: school.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
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

// MARK: - No Locations Card (for empty state overlay)
struct NoLocationsOverlay: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 40))
                .foregroundStyle(Color.textSecondary)

            Text("No Locations Added")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            Text("Add your school location to see it on the map.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 32)
    }
}

// MARK: - Location Detail Sheet
struct LocationDetailSheet: View {
    let location: SavedLocation
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Map
                    MapWidget(
                        coordinate: location.coordinate,
                        userLocation: appState.currentLocation,
                        showsRoute: true,
                        height: 200
                    )
                    .padding(.horizontal)

                    // Location Info
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: location.iconName)
                                .font(.title2)
                                .foregroundStyle(iconColor)

                            VStack(alignment: .leading) {
                                Text(location.name)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.textPrimary)

                                if let address = location.address {
                                    Text(address)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                        }

                        if let userLocation = appState.currentLocation {
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                Text(location.formattedDistance(from: userLocation) + " away")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(Color.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Lessons at this location
                    LessonsAtLocationList(location: location)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.background)
            .navigationTitle("Location Details")
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

    private var iconColor: Color {
        switch location.type {
        case .home: return Color.locationHome
        case .school: return Color.locationSchool
        case .library: return Color.locationLibrary
        case .office: return Color.locationOffice
        case .other: return Color.locationOther
        }
    }
}

// MARK: - Lessons at Location List
struct LessonsAtLocationList: View {
    let location: SavedLocation
    @EnvironmentObject var appState: AppState

    var lessonsAtLocation: [Lesson] {
        appState.lessons.filter { $0.locationId == location.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Classes at this location")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            if lessonsAtLocation.isEmpty {
                Text("No classes scheduled at this location")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(lessonsAtLocation) { lesson in
                        LessonRow(lesson: lesson, location: nil)

                        if lesson.id != lessonsAtLocation.last?.id {
                            Rectangle()
                                .fill(Color.cardBorder)
                                .frame(height: 0.5)
                                .padding(.leading, 36)
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

// MARK: - Dashboard Liquid Glass Header
struct DashboardLiquidGlassHeader: View {
    @Binding var selectedDay: DayOfWeek
    let weatherService: WeatherService
    let onWeatherTap: () -> Void

    @State private var showingClassCreator = false

    private var selectedDate: Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday - 2 + 7) % 7
        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return today
        }
        let orderedDays: [DayOfWeek] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        let dayIndex = orderedDays.firstIndex(of: selectedDay) ?? 0
        return calendar.date(byAdding: .day, value: dayIndex, to: startOfWeek) ?? today
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        let day = Calendar.current.component(.day, from: selectedDate)
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        formatter.dateFormat = "MMMM d'\(suffix)', yyyy"
        return formatter.string(from: selectedDate)
    }

    private var weekDays: [(day: DayOfWeek, date: Int, isToday: Bool)] {
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
            return (dayOfWeek, dayNumber, isToday)
        }
    }

    var body: some View {
        ZStack {
            // Variable blur background
            TintFreeGradientBlur(maxBlurRadius: 24.0, direction: VariableBlurDirection.blurredTopClearBottom, startOffset: 0)
                .ignoresSafeArea(edges: .top)

            // Content
            VStack(spacing: 6) {
                // Top row: Weather widget and action buttons
                HStack(alignment: .top) {
                    // Weather widget (left)
                    Button {
                        onWeatherTap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: weatherService.weatherSymbol)
                                .font(.system(size: 14, weight: .medium))
                            Text(weatherService.temperature)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(DashboardGlassButtonStyle())

                    Spacer()

                    // Action buttons (right)
                    HStack(spacing: 0) {
                        Button {
                            HapticManager.shared.buttonTap()
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .frame(width: 36, height: 32)
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 0.5, height: 16)

                        Button {
                            HapticManager.shared.buttonTap()
                            showingClassCreator = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .frame(width: 36, height: 32)
                        }
                    }
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                    )
                    .buttonStyle(DashboardGlassButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)

                // Day name (large serif)
                Text(dayName)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                // Date subtitle
                Text(formattedDate)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                // Week day picker
                HStack(spacing: 6) {
                    ForEach(weekDays, id: \.day) { item in
                        Button {
                            if selectedDay != item.day {
                                HapticManager.shared.selection()
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedDay = item.day
                            }
                        } label: {
                            VStack(spacing: 3) {
                                ZStack {
                                    Circle()
                                        .fill(selectedDay == item.day ? Color.textPrimary : Color.clear)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    selectedDay == item.day ? Color.clear : Color.white.opacity(0.12),
                                                    lineWidth: 1
                                                )
                                        )

                                    Text("\(item.date)")
                                        .font(.system(size: 14, weight: item.isToday || selectedDay == item.day ? .bold : .medium))
                                        .foregroundStyle(selectedDay == item.day ? Color.background : Color.textPrimary)
                                }
                                .frame(width: 36, height: 36)

                                Text(item.day.shortName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(item.isToday ? Color.red : Color.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 200)
        .sheet(isPresented: $showingClassCreator) {
            ClassCreatorView(selectedDay: selectedDay)
        }
    }
}

// MARK: - Dashboard Glass Button Style
struct DashboardGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    DashboardView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
