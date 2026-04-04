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

    // Calendar Popover State
    @State private var showCalendarPopover = false
    @State private var currentWeekOffset: Int = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.background
                .ignoresSafeArea()

            // Scrollable content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Spacer for sticky header
                    Color.clear.frame(height: 56)

                    // Calendar content (day name, date, day picker)
                    CalendarContent(selectedDay: $selectedDay, weekOffset: $currentWeekOffset)

                    // Content area
                    VStack(spacing: 20) {
                        // Schedule list widget
                        ScheduleListWidget(
                            selectedDay: selectedDay,
                            lessonsForDay: lessonsForSelectedDay,
                            allLessons: appState.lessons,
                            locations: appState.locations,
                            currentLesson: currentLessonForToday,
                            userLocation: appState.currentLocation,
                            calendarEvents: calendarEventsForSelectedDay
                        )
                        .padding(.horizontal, 16)

                        // Map widget with lesson overlay (below schedule)
                        ClassLocationMapWidget(
                            currentLesson: currentLessonForToday,
                            nextLesson: nextLessonForToday?.lesson,
                            locations: appState.locations,
                            userLocation: appState.currentLocation,
                            todayLessons: todayLessonsSorted,
                            lessonIndex: currentLessonIndex,
                            onTap: {
                                HapticManager.shared.buttonTap()
                                showExpandedMap = true
                            }
                        )
                        .padding(.horizontal, 16)

                        // Stats section
                        StatsSection()
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }

            // Sticky top bar
            StickyTopBar(
                showSettings: $showSettings,
                showingClassCreator: $showingClassCreator,
                showCalendarPopover: $showCalendarPopover,
                selectedDay: $selectedDay,
                currentWeekOffset: $currentWeekOffset,
                weatherService: weatherService,
                onWeatherTap: {
                    HapticManager.shared.buttonTap()
                    showWeatherSheet = true
                }
            )

            // Calendar Popover overlay
            if showCalendarPopover {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showCalendarPopover = false
                        }
                    }

                VStack {
                    HStack {
                        CalendarPopoverView(
                            selectedDay: $selectedDay,
                            currentWeekOffset: $currentWeekOffset,
                            isPresented: $showCalendarPopover
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9, anchor: .topLeading).combined(with: .opacity),
                            removal: .scale(scale: 0.9, anchor: .topLeading).combined(with: .opacity)
                        ))

                        Spacer()
                    }
                    .padding(.leading, 16)
                    .padding(.top, 56)

                    Spacer()
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showCalendarPopover)
            }
        }
        .sheet(isPresented: $showExpandedMap) {
            ExpandedMapView(
                currentLesson: currentLessonForToday,
                nextLesson: nextLessonForToday?.lesson,
                locations: appState.locations,
                userLocation: appState.currentLocation
            )
            .environmentObject(appState)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
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
                .presentationDetents([.height(385)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(24)
                .presentationBackground(Color.secondaryBackground)
                .interactiveDismissDisabled(false)
        }
        .onAppear {
            fetchWeatherIfNeeded()
        }
        .onChange(of: appState.currentLocation?.latitude) { _, _ in
            // Fetch weather when user location becomes available or changes
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
                // Use the user's actual GPS location
                await weatherService.fetchWeather(for: location)
            }
            // If no user location available, don't fetch weather
            // (wait for location services to provide user's position)
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
        // When comparing, ensure we use the actual day value
        // .current returns the current day (e.g., .thursday), but we need to compare properly
        let targetDay = selectedDay
        return appState.scheduledLessons.filter { scheduled in
            // Compare raw values to ensure enum comparison works correctly
            scheduled.dayOfWeek.rawValue == targetDay.rawValue
        }
        .sorted { lesson1, lesson2 in
            guard let l1 = appState.lessons.first(where: { $0.id == lesson1.lessonId }),
                  let l2 = appState.lessons.first(where: { $0.id == lesson2.lessonId }) else {
                return false
            }
            return l1.startTime < l2.startTime
        }
    }

    // These computed properties reference refreshTrigger to ensure they recompute when timer fires
    private var currentLessonForToday: Lesson? {
        _ = appState.refreshTrigger
        return appState.currentLesson()
    }

    private var nextLessonForToday: (lesson: Lesson, startsIn: TimeInterval)? {
        _ = appState.refreshTrigger
        return appState.nextLesson()
    }

    private var todayLessonsSorted: [Lesson] {
        let todayScheduled = appState.scheduledLessons.filter { $0.dayOfWeek == .current }
        return todayScheduled
            .compactMap { scheduled in
                appState.lessons.first { $0.id == scheduled.lessonId }
            }
            .sorted { $0.startTime < $1.startTime }
    }

    private var currentLessonIndex: Int {
        guard let current = currentLessonForToday ?? nextLessonForToday?.lesson else {
            return 1
        }
        if let index = todayLessonsSorted.firstIndex(where: { $0.id == current.id }) {
            return index + 1
        }
        return 1
    }

    private var calendarEventsForSelectedDay: [CalendarEvent] {
        _ = appState.refreshTrigger
        // Only use cached today events if viewing today (current day AND current week)
        if selectedDay == .current && currentWeekOffset == 0 {
            return appState.calendarEvents
        } else {
            return appState.fetchCalendarEventsForDay(selectedDay, weekOffset: currentWeekOffset)
        }
    }
}

// MARK: - Sticky Top Bar
struct StickyTopBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var showSettings: Bool
    @Binding var showingClassCreator: Bool
    @Binding var showCalendarPopover: Bool
    @Binding var selectedDay: DayOfWeek
    @Binding var currentWeekOffset: Int
    @ObservedObject var weatherService: WeatherService
    let onWeatherTap: () -> Void

    var body: some View {
        HStack {
            // Calendar button (left side) with popover
            Button {
                HapticManager.shared.buttonTap()
                showCalendarPopover.toggle()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.secondaryBackground)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            // Weather quick glance
            Button(action: onWeatherTap) {
                HStack(spacing: 4) {
                    Image(systemName: weatherService.weatherSymbol)
                        .font(.system(size: 14, weight: .medium))
                    Text("\(weatherService.temperature(for: appState.unitSystem) ?? 0)°")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.secondaryBackground)
                )
            }
            .buttonStyle(.plain)

            // Settings button
            Button {
                HapticManager.shared.buttonTap()
                showSettings = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.secondaryBackground)
                    )
            }
            .buttonStyle(.plain)

            // Add class button
            Button {
                HapticManager.shared.buttonTap()
                showingClassCreator = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.secondaryBackground)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Calendar Content (scrollable part)
struct CalendarContent: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedDay: DayOfWeek
    @Binding var weekOffset: Int
    @State private var previousDay: DayOfWeek = .current
    @State private var isMovingForward: Bool = true
    @State private var previousMonthDay: String = ""
    @State private var previousYear: String = ""

    private var weekDays: [(day: DayOfWeek, date: Int, isToday: Bool, fullDate: Date)] {
        let calendar = Calendar.current
        let today = Date()

        // Apply week offset to get the target week
        guard let targetDate = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: today) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: targetDate)

        // Calculate start of week based on user's preference
        let weekStartOffset = appState.weekStartDay == .monday ? 2 : 1
        var daysFromStart = weekday - weekStartOffset
        if daysFromStart < 0 { daysFromStart += 7 }

        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromStart, to: targetDate) else {
            return []
        }

        // Order days based on week start preference
        let orderedDays: [DayOfWeek] = appState.weekStartDay == .monday
            ? [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
            : [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

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

    private var formattedMonthDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd"
        return formatter.string(from: dateForSelectedDay)
    }

    private var formattedYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: dateForSelectedDay)
    }

    private func dayIndex(_ day: DayOfWeek) -> Int {
        let order: [DayOfWeek] = appState.weekStartDay == .monday
            ? [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
            : [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        return order.firstIndex(of: day) ?? 0
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header row: Day name on left, date on right
            HStack(alignment: .center) {
                // Large day name with staggered letter animation
                StaggeredText(
                    text: selectedDay.shortName,
                    isMovingForward: isMovingForward
                )
                .id("day-\(selectedDay.rawValue)")

                Spacer()

                // Date stacked on right - smart animation only for changed characters
                VStack(alignment: .trailing, spacing: -2) {
                    SmartAnimatedText(
                        text: formattedMonthDay,
                        previousText: previousMonthDay,
                        isMovingForward: isMovingForward
                    )
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.textTertiary)

                    SmartAnimatedText(
                        text: formattedYear,
                        previousText: previousYear,
                        isMovingForward: isMovingForward
                    )
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.horizontal, 20)
            .onChange(of: selectedDay) { oldValue, newValue in
                // Store previous values for comparison before they change
                let formatter = DateFormatter()
                let oldDate = weekDays.first { $0.day == oldValue }?.fullDate ?? Date()
                formatter.dateFormat = "MMMM dd"
                previousMonthDay = formatter.string(from: oldDate)
                formatter.dateFormat = "yyyy"
                previousYear = formatter.string(from: oldDate)
            }

            // Week day picker - no backgrounds except selected
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.day) { item in
                    let isSelected = selectedDay == item.day
                    Button {
                        if !isSelected {
                            HapticManager.shared.selection()
                            let newIndex = dayIndex(item.day)
                            let oldIndex = dayIndex(selectedDay)
                            isMovingForward = newIndex > oldIndex
                            previousDay = selectedDay
                        }
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                            selectedDay = item.day
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(item.date)")
                                .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)

                            // Day abbreviation - red for today
                            Text(item.day.shortName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(item.isToday ? .red : Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected ? Color.secondaryBackground : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 8)
        .onAppear {
            previousDay = selectedDay
            // Initialize previous values to current values on appear
            previousMonthDay = formattedMonthDay
            previousYear = formattedYear
        }
    }
}

// MARK: - Staggered Text Animation
struct StaggeredText: View {
    let text: String
    let isMovingForward: Bool

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .offset(x: appeared ? 0 : (isMovingForward ? 20 : -20))
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response: 0.25, dampingFraction: 0.85)
                        .delay(Double(index) * 0.03),
                        value: appeared
                    )
            }
        }
        .onAppear {
            appeared = true
        }
    }
}

// MARK: - Smart Animated Text (only animates changed characters)
struct SmartAnimatedText: View {
    let text: String
    let previousText: String
    let isMovingForward: Bool

    // Create a unique ID that changes when the text changes
    private var textId: String {
        text + "-" + previousText
    }

    var body: some View {
        HStack(spacing: 0) {
            // Pad arrays to same length for comparison
            let maxLength = max(text.count, previousText.count)
            let currentChars = Array(text.padding(toLength: maxLength, withPad: " ", startingAt: 0))
            let previousChars = Array(previousText.padding(toLength: maxLength, withPad: " ", startingAt: 0))

            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                let charString = String(character)
                let previousChar = index < previousText.count ? String(previousChars[index]) : ""
                let hasChanged = index >= previousText.count || previousChars[index] != currentChars[index]

                if hasChanged && !previousText.isEmpty {
                    // Animate only changed characters - use character in id to force recreation
                    AnimatedCharacter(
                        character: charString,
                        isMovingForward: isMovingForward,
                        delay: Double(index) * 0.02
                    )
                    .id("\(index)-\(charString)-\(previousChar)")
                } else {
                    // Static character (no animation needed)
                    Text(charString)
                }
            }
        }
    }
}

// MARK: - Animated Character
struct AnimatedCharacter: View {
    let character: String
    let isMovingForward: Bool
    let delay: Double

    @State private var appeared = false

    var body: some View {
        Text(character)
            .offset(y: appeared ? 0 : (isMovingForward ? 10 : -10))
            .opacity(appeared ? 1 : 0)
            .animation(
                .spring(response: 0.25, dampingFraction: 0.85)
                .delay(delay),
                value: appeared
            )
            .onAppear {
                appeared = true
            }
    }
}

// MARK: - Class Location Map Widget
struct ClassLocationMapWidget: View {
    let currentLesson: Lesson?
    let nextLesson: Lesson?
    let locations: [SavedLocation]
    let userLocation: CLLocationCoordinate2D?
    let todayLessons: [Lesson]
    let lessonIndex: Int
    let onTap: () -> Void

    @State private var mapSnapshot: UIImage?
    @State private var isLoading = true
    @State private var lastSnapshotCenter: CLLocationCoordinate2D?

    private var hasActiveClass: Bool {
        currentLesson != nil
    }

    private var hasUpcomingClass: Bool {
        nextLesson != nil && currentLesson == nil
    }

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
        if let location = displayLocation {
            return location.coordinate
        }
        if let userLoc = userLocation {
            return userLoc
        }
        return CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
    }

    private var locationTitle: String {
        if let location = displayLocation {
            return location.name
        }
        return "Current Location"
    }

    private var locationSubtitle: String {
        if hasActiveClass {
            return displayLocation?.name ?? "On the Way"
        }
        return "On the Way"
    }

    private var mapHeight: CGFloat {
        displayLesson != nil ? 320 : 220
    }

    private var lastLessonEndTime: String {
        guard let lastLesson = todayLessons.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: lastLesson.endTime)
    }

    private var lessonsRemaining: Int {
        guard hasActiveClass, let current = currentLesson else {
            return todayLessons.count
        }
        let currentIndex = todayLessons.firstIndex(where: { $0.id == current.id }) ?? 0
        return todayLessons.count - currentIndex - 1
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                // Map snapshot
                ZStack(alignment: .topLeading) {
                    if let snapshot = mapSnapshot {
                        Image(uiImage: snapshot)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                    } else {
                        Rectangle()
                            .fill(Color.tertiaryBackground)
                            .overlay {
                                if isLoading {
                                    ProgressView()
                                        .tint(Color.textTertiary)
                                }
                            }
                    }

                    // Top overlay with location info and status
                    HStack {
                        // Location info
                        HStack(spacing: 8) {
                            // Location icon
                            ZStack {
                                Circle()
                                    .fill(displayLocation != nil ? locationColor(for: displayLocation!.type) : Color.blue)
                                    .frame(width: 32, height: 32)
                                Image(systemName: displayLocation?.iconName ?? "location.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Current Location")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.textTertiary)
                                Text(hasActiveClass ? (displayLocation?.name ?? "School") : (hasUpcomingClass ? "On the Way" : locationTitle))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondaryBackground.opacity(0.95))
                        )

                        Spacer(minLength: 8)
                    }
                    .padding(12)

                    // User location marker overlay
                    if let userLoc = userLocation {
                        GeometryReader { geometry in
                            let point = mapPointForCoordinate(userLoc, in: geometry.size)
                            Circle()
                                .fill(Color.statusOnline)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                .position(point)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: mapHeight)

                // Lesson overlay card (only show when there's an active or upcoming lesson)
                if let lesson = displayLesson {
                    LessonOverlayCard(
                        lesson: lesson,
                        isLive: hasActiveClass,
                        lessonIndex: lessonIndex,
                        lessonsRemaining: lessonsRemaining,
                        totalLessons: todayLessons.count,
                        lastLessonEndTime: lastLessonEndTime
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.cardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            generateMapSnapshotIfNeeded()
        }
        .onChange(of: currentLesson?.id) { _, _ in
            generateMapSnapshotIfNeeded()
        }
        .onChange(of: userLocation?.latitude) { _, _ in
            generateMapSnapshotIfNeeded()
        }
        .onChange(of: userLocation?.longitude) { _, _ in
            generateMapSnapshotIfNeeded()
        }
    }

    private func locationColor(for type: LocationType) -> Color {
        switch type {
        case .home: return Color.locationHome
        case .school: return Color.locationSchool
        case .library: return Color.locationLibrary
        case .office: return Color.locationOffice
        case .other: return Color.locationOther
        }
    }

    private func mapPointForCoordinate(_ coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        let span = MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        let latDiff = mapCenter.latitude - coordinate.latitude
        let lonDiff = coordinate.longitude - mapCenter.longitude
        let x = size.width / 2 + CGFloat(lonDiff / span.longitudeDelta) * size.width
        let y = size.height / 2 + CGFloat(latDiff / span.latitudeDelta) * size.height
        return CGPoint(x: x, y: y)
    }

    private func generateMapSnapshotIfNeeded() {
        if let last = lastSnapshotCenter {
            let latDiff = abs(last.latitude - mapCenter.latitude)
            let lonDiff = abs(last.longitude - mapCenter.longitude)
            if latDiff < 0.0001 && lonDiff < 0.0001 {
                return
            }
        }

        lastSnapshotCenter = mapCenter
        isLoading = true

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: mapCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        )
        options.size = CGSize(width: 400, height: Int(mapHeight) + 40)
        options.scale = UIScreen.main.scale
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        options.mapType = .mutedStandard
        options.showsBuildings = true
        options.pointOfInterestFilter = .excludingAll

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            DispatchQueue.main.async {
                isLoading = false
                guard let snapshot = snapshot, error == nil else { return }

                let image = snapshot.image
                UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
                image.draw(at: .zero)

                // Draw location marker
                if let location = displayLocation {
                    let point = snapshot.point(for: location.coordinate)
                    let color = locationColor(for: location.type)
                    let uiColor = UIColor(color)

                    // Outer ring
                    let outerSize: CGFloat = 36
                    let outerRect = CGRect(x: point.x - outerSize/2, y: point.y - outerSize/2, width: outerSize, height: outerSize)
                    uiColor.withAlphaComponent(0.25).setFill()
                    UIBezierPath(ovalIn: outerRect).fill()

                    // Inner circle
                    let innerSize: CGFloat = 24
                    let innerRect = CGRect(x: point.x - innerSize/2, y: point.y - innerSize/2, width: innerSize, height: innerSize)
                    uiColor.setFill()
                    UIBezierPath(ovalIn: innerRect).fill()

                    // Icon
                    let iconConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
                    if let iconImage = UIImage(systemName: location.iconName, withConfiguration: iconConfig)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                        let iconSize: CGFloat = 11
                        let iconRect = CGRect(x: point.x - iconSize/2, y: point.y - iconSize/2, width: iconSize, height: iconSize)
                        iconImage.draw(in: iconRect)
                    }
                }

                mapSnapshot = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
            }
        }
    }
}

// MARK: - Lesson Overlay Card
struct LessonOverlayCard: View {
    let lesson: Lesson
    let isLive: Bool
    let lessonIndex: Int
    let lessonsRemaining: Int
    let totalLessons: Int
    let lastLessonEndTime: String

    // Timer for auto-refresh of time-dependent values
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timeIndicator: String {
        // Reference currentTime to force recalculation when timer fires
        _ = currentTime
        let now = Date()
        let calendar = Calendar.current

        if isLive {
            // Calculate minutes until end
            let endComponents = calendar.dateComponents([.hour, .minute], from: lesson.endTime)
            var todayEnd = calendar.dateComponents([.year, .month, .day], from: now)
            todayEnd.hour = endComponents.hour
            todayEnd.minute = endComponents.minute

            if let end = calendar.date(from: todayEnd) {
                let minutes = max(0, Int(end.timeIntervalSince(now) / 60))
                return "\(minutes) mins left"
            }
            return "Ending soon"
        } else {
            // Calculate minutes until start
            let startComponents = calendar.dateComponents([.hour, .minute], from: lesson.startTime)
            var todayStart = calendar.dateComponents([.year, .month, .day], from: now)
            todayStart.hour = startComponents.hour
            todayStart.minute = startComponents.minute

            if let start = calendar.date(from: todayStart) {
                let minutes = max(0, Int(start.timeIntervalSince(now) / 60))
                if minutes >= 60 {
                    let hours = minutes / 60
                    let mins = minutes % 60
                    return "Starts in \(hours)h \(mins)m"
                }
                return "Starts in \(minutes) min"
            }
            return "Starting soon"
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        if isLive {
            return "Ends at \(formatter.string(from: lesson.endTime))"
        } else {
            return "Start at \(formatter.string(from: lesson.startTime))"
        }
    }

    private var statusColor: Color {
        isLive ? Color.green : Color.yellow
    }

    private var lessonProgress: Double {
        guard isLive else { return 0 }
        // Reference currentTime to force recalculation when timer fires
        let now = currentTime
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
              let end = calendar.date(from: todayEnd) else { return 0 }

        let totalDuration = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)

        return min(1, max(0, elapsed / totalDuration))
    }

    private var footerText: String {
        if isLive {
            return "\(lessonsRemaining) session\(lessonsRemaining == 1 ? "" : "s") remaining"
        } else {
            return "\(totalLessons) Session\(totalLessons == 1 ? "" : "s") Today"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            VStack(spacing: 8) {
                // Header row: Status label + Time indicator
                HStack {
                    // Status label
                    HStack(spacing: 4) {
                        Image(systemName: isLive ? "arrow.up.right.circle.fill" : "figure.walk.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(isLive ? "In Session" : "Up Next")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(statusColor)

                    Spacer(minLength: 8)

                    // Time indicator
                    Text(timeIndicator)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                }

                // Lesson name
                Text(lesson.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Time and room row
                HStack(spacing: 16) {
                    // Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .medium))
                        Text(formattedTime)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.textSecondary)

                    // Room
                    HStack(spacing: 4) {
                        Image(systemName: "door.left.hand.open")
                            .font(.system(size: 11, weight: .medium))
                        Text(lesson.room)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.textSecondary)

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                ZStack(alignment: .leading) {
                    // Base background with shadow casting down and rounded bottom
                    UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 20, style: .continuous)
                        .fill(Color.secondaryBackground)
                        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 4)

                    // Progress background for live lessons (matching container shape)
                    if isLive {
                        GeometryReader { geometry in
                            UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 10, style: .continuous)
                                .fill(lesson.color.color.opacity(0.18))
                                .frame(width: geometry.size.width * lessonProgress, height: geometry.size.height)
                        }
                    }
                }
            }
            .zIndex(1) // Ensure main card shadow appears above footer

            // Footer bar (inset style - narrower)
            HStack {
                // Lessons count
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 10, weight: .semibold))
                    Text(footerText)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.textTertiary)

                Spacer(minLength: 8)

                // Day end time
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10, weight: .medium))
                    Text("Ends at \(lastLessonEndTime)")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 0, style: .continuous)
                    .fill(Color.tertiaryBackground)
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onReceive(timer) { time in
            currentTime = time
        }
    }
}

// MARK: - Expanded Map View
struct ExpandedMapView: View {
    @EnvironmentObject var appState: AppState
    let currentLesson: Lesson?
    let nextLesson: Lesson?
    let locations: [SavedLocation]
    let userLocation: CLLocationCoordinate2D?

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedLocationId: UUID?
    @State private var travelTimeWalking: TimeInterval?
    @State private var travelTimeDriving: TimeInterval?
    @State private var distanceMeters: Double?
    @State private var selectedTransport: TransportMode = .walking
    @Environment(\.dismiss) private var dismiss

    enum TransportMode {
        case walking, driving
    }

    private var displayLesson: Lesson? {
        currentLesson ?? nextLesson
    }

    private var selectedLocation: SavedLocation? {
        locations.first { $0.id == selectedLocationId }
    }

    // Quick estimate based on straight-line distance
    private var estimatedDistance: Double? {
        guard let userLoc = userLocation, let loc = selectedLocation else { return nil }
        let userCLLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let destCLLocation = CLLocation(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        return userCLLocation.distance(from: destCLLocation)
    }

    private var estimatedWalkingTime: TimeInterval? {
        guard let dist = estimatedDistance else { return nil }
        // Average walking speed: ~5 km/h = 1.4 m/s, add 20% for non-straight paths
        return (dist / 1.4) * 1.2
    }

    private var estimatedDrivingTime: TimeInterval? {
        guard let dist = estimatedDistance else { return nil }
        // Average city driving: ~30 km/h = 8.3 m/s, add 30% for traffic/non-straight
        return (dist / 8.3) * 1.3
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    private var leaveByTime: Date? {
        guard let lesson = displayLesson else { return nil }
        // Use actual time if available, otherwise use estimate
        let actualTime = selectedTransport == .walking ? travelTimeWalking : travelTimeDriving
        let estimatedTime = selectedTransport == .walking ? estimatedWalkingTime : estimatedDrivingTime
        guard let travel = actualTime ?? estimatedTime else { return nil }
        // Add 5 minute buffer
        return lesson.startTime.addingTimeInterval(-(travel + 300))
    }

    private var formattedTravelTime: String? {
        // Use actual time if available, otherwise use estimate
        let actualTime = selectedTransport == .walking ? travelTimeWalking : travelTimeDriving
        let estimatedTime = selectedTransport == .walking ? estimatedWalkingTime : estimatedDrivingTime
        guard let travel = actualTime ?? estimatedTime else { return nil }
        let minutes = Int(travel / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMins = minutes % 60
            return "\(hours)h \(remainingMins)m"
        }
    }

    private var formattedDistance: String? {
        // Use actual distance if available, otherwise use estimate
        guard let meters = distanceMeters ?? estimatedDistance else { return nil }
        switch appState.unitSystem {
        case .metric:
            if meters < 1000 {
                return "\(Int(meters)) m"
            } else {
                let km = meters / 1000
                return String(format: "%.1f km", km)
            }
        case .imperial:
            let feet = meters * 3.28084
            if feet < 5280 {
                return "\(Int(feet)) ft"
            } else {
                let miles = meters / 1609.344
                return String(format: "%.1f mi", miles)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    if userLocation != nil {
                        UserAnnotation()
                    }

                    ForEach(locations) { location in
                        Annotation(location.name, coordinate: location.coordinate) {
                            MinimalLocationPin(
                                type: location.type,
                                isSelected: selectedLocationId == location.id
                            )
                            .onTapGesture {
                                HapticManager.shared.selection()
                                selectedLocationId = location.id
                                goToLocation(location)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
                .mapControls {
                    MapCompass()
                }

                // Bottom controls
                VStack(spacing: 12) {
                    // Travel info overlay (only when a location is selected and we have travel data)
                    if selectedLocationId != nil, let leaveBy = leaveByTime, let travelStr = formattedTravelTime {
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Leave by")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.textTertiary)
                                    Text(timeFormatter.string(from: leaveBy))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(Color.textPrimary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(travelStr)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)
                                    if let dist = formattedDistance {
                                        Text(dist)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            // Transport mode toggle
                            HStack(spacing: 0) {
                                Button {
                                    HapticManager.shared.selection()
                                    selectedTransport = .walking
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "figure.walk")
                                            .font(.system(size: 14))
                                        Text("Walk")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(selectedTransport == .walking ? .white : Color.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedTransport == .walking ? Color.blue : Color.tertiaryBackground)
                                }

                                Button {
                                    HapticManager.shared.selection()
                                    selectedTransport = .driving
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "car.fill")
                                            .font(.system(size: 14))
                                        Text("Drive")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(selectedTransport == .driving ? .white : Color.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedTransport == .driving ? Color.blue : Color.tertiaryBackground)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(.horizontal, 16)
                    }

                    // Location picker pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // My Location button
                            Button {
                                HapticManager.shared.selection()
                                selectedLocationId = nil
                                goToUserLocation()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("My Location")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(selectedLocationId == nil ? .white : Color.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(selectedLocationId == nil ? Color.blue : Color.secondaryBackground)
                                )
                            }

                            ForEach(locations) { location in
                                Button {
                                    HapticManager.shared.selection()
                                    selectedLocationId = location.id
                                    goToLocation(location)
                                    calculateTravelTime(to: location)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: location.iconName)
                                            .font(.system(size: 12, weight: .medium))
                                        Text(location.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(selectedLocationId == location.id ? .white : Color.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(selectedLocationId == location.id ? markerColor(for: location) : Color.secondaryBackground)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle(selectedLocation?.name ?? "Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Start at first location or user location
                if let location = locations.first(where: { $0.type == .school }) ?? locations.first {
                    selectedLocationId = location.id
                    goToLocation(location)
                    calculateTravelTime(to: location)
                } else if userLocation != nil {
                    goToUserLocation()
                }
            }
        }
    }

    private func calculateTravelTime(to location: SavedLocation) {
        guard let userLoc = userLocation else { return }

        let source = MKPlacemark(coordinate: userLoc)
        let destination = MKPlacemark(coordinate: location.coordinate)

        // Calculate walking time
        let walkingRequest = MKDirections.Request()
        walkingRequest.source = MKMapItem(placemark: source)
        walkingRequest.destination = MKMapItem(placemark: destination)
        walkingRequest.transportType = .walking

        let walkingDirections = MKDirections(request: walkingRequest)
        walkingDirections.calculate { response, error in
            if let route = response?.routes.first {
                DispatchQueue.main.async {
                    self.travelTimeWalking = route.expectedTravelTime
                    self.distanceMeters = route.distance
                }
            }
        }

        // Calculate driving time
        let drivingRequest = MKDirections.Request()
        drivingRequest.source = MKMapItem(placemark: source)
        drivingRequest.destination = MKMapItem(placemark: destination)
        drivingRequest.transportType = .automobile

        let drivingDirections = MKDirections(request: drivingRequest)
        drivingDirections.calculate { response, error in
            if let route = response?.routes.first {
                DispatchQueue.main.async {
                    self.travelTimeDriving = route.expectedTravelTime
                }
            }
        }
    }

    private func goToLocation(_ location: SavedLocation) {
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            ))
        }
    }

    private func goToUserLocation() {
        guard let userLoc = userLocation else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: userLoc,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            ))
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

// MARK: - Minimal Location Pin
struct MinimalLocationPin: View {
    let type: LocationType
    let isSelected: Bool

    private var pinColor: Color {
        switch type {
        case .home: return .orange
        case .school: return .green
        case .library: return .blue
        case .office: return .purple
        case .other: return .gray
        }
    }

    var body: some View {
        ZStack {
            // Shadow
            Circle()
                .fill(.black.opacity(0.2))
                .frame(width: isSelected ? 28 : 20, height: isSelected ? 28 : 20)
                .blur(radius: 3)
                .offset(y: 2)

            // Pin
            Circle()
                .fill(pinColor)
                .frame(width: isSelected ? 24 : 16, height: isSelected ? 24 : 16)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: isSelected ? 3 : 2)
                )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Lesson Selection for Details Sheet
struct LessonSelection: Identifiable {
    let id: UUID
    let lesson: Lesson
    let scheduledLesson: ScheduledLesson

    init(lesson: Lesson, scheduledLesson: ScheduledLesson) {
        self.id = lesson.id
        self.lesson = lesson
        self.scheduledLesson = scheduledLesson
    }
}

// MARK: - Schedule Item (unified type for lessons and calendar events)
enum ScheduleItem: Identifiable {
    case lesson(Lesson, ScheduledLesson)
    case calendarEvent(CalendarEvent)

    var id: String {
        switch self {
        case .lesson(let lesson, _):
            return "lesson-\(lesson.id.uuidString)"
        case .calendarEvent(let event):
            return "event-\(event.id)"
        }
    }

    var startTime: Date {
        switch self {
        case .lesson(let lesson, _):
            return lesson.startTime
        case .calendarEvent(let event):
            return event.startDate
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
    let userLocation: CLLocationCoordinate2D?
    let calendarEvents: [CalendarEvent]

    @State private var selectedLessonForDetails: LessonSelection?
    @State private var selectedCalendarEvent: CalendarEvent?

    private var dayTitle: String {
        // Check if the selected day matches today's actual day
        let todayDay = DayOfWeek.current
        if selectedDay.rawValue == todayDay.rawValue {
            return "Today's Schedule"
        } else {
            return "\(selectedDay.name)'s Schedule"
        }
    }

    // Only count lessons that actually exist in allLessons
    private var validLessonsCount: Int {
        lessonsForDay.filter { scheduled in
            allLessons.contains { $0.id == scheduled.lessonId }
        }.count
    }

    // Combined and sorted schedule items
    private var combinedScheduleItems: [ScheduleItem] {
        var items: [ScheduleItem] = []

        // Add valid lessons
        for scheduled in lessonsForDay {
            if let lesson = allLessons.first(where: { $0.id == scheduled.lessonId }) {
                items.append(.lesson(lesson, scheduled))
            }
        }

        // Add calendar events
        for event in calendarEvents {
            items.append(.calendarEvent(event))
        }

        // Sort by start time (using hour and minute for lessons)
        return items.sorted { item1, item2 in
            let calendar = Calendar.current
            let time1 = calendar.dateComponents([.hour, .minute], from: item1.startTime)
            let time2 = calendar.dateComponents([.hour, .minute], from: item2.startTime)
            let minutes1 = (time1.hour ?? 0) * 60 + (time1.minute ?? 0)
            let minutes2 = (time2.hour ?? 0) * 60 + (time2.minute ?? 0)
            return minutes1 < minutes2
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Schedule list
            if combinedScheduleItems.isEmpty {
                EmptyScheduleCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(combinedScheduleItems.enumerated()), id: \.element.id) { index, item in
                        switch item {
                        case .lesson(let lesson, let scheduled):
                            Button {
                                HapticManager.shared.buttonTap()
                                selectedLessonForDetails = LessonSelection(lesson: lesson, scheduledLesson: scheduled)
                            } label: {
                                ScheduleListRow(
                                    lesson: lesson,
                                    location: locations.first(where: { $0.id == lesson.locationId }),
                                    isActive: selectedDay == .current && currentLesson?.id == lesson.id,
                                    repeatPattern: scheduled.repeatPattern
                                )
                            }
                            .buttonStyle(.plain)

                        case .calendarEvent(let event):
                            Button {
                                HapticManager.shared.buttonTap()
                                selectedCalendarEvent = event
                            } label: {
                                CalendarEventRow(event: event)
                            }
                            .buttonStyle(.plain)
                        }

                        if index < combinedScheduleItems.count - 1 {
                            Rectangle()
                                .fill(Color.cardBorder)
                                .frame(height: 0.5)
                                .padding(.horizontal, 14)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.secondaryBackground)
                )
            }
        }
        .sheet(item: $selectedLessonForDetails) { selection in
            ClassDetailsSheet(
                lesson: selection.lesson,
                scheduledLesson: selection.scheduledLesson,
                location: locations.first(where: { $0.id == selection.lesson.locationId }),
                userLocation: userLocation,
                isActive: selectedDay == .current && currentLesson?.id == selection.lesson.id
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
            .presentationBackground(Color.secondaryBackground)
        }
        .sheet(item: $selectedCalendarEvent) { event in
            CalendarEventDetailsSheet(event: event, userLocation: userLocation)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground(Color.secondaryBackground)
        }
    }
}

// MARK: - Calendar Event Row
struct CalendarEventRow: View {
    let event: CalendarEvent

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter
    }

    private var eventColor: Color {
        if let cgColor = event.calendarColor {
            return Color(cgColor: cgColor)
        }
        return Color.blue
    }

    var body: some View {
        HStack(spacing: 10) {
            // Dotted line indicator (simple dashed line)
            VStack(spacing: 3) {
                ForEach(0..<6, id: \.self) { _ in
                    Circle()
                        .fill(eventColor)
                        .frame(width: 3, height: 3)
                }
            }
            .frame(width: 3, height: 36)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                    }
                    Text(event.calendarTitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Time
            Text("\(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Calendar Event Details Sheet
struct CalendarEventDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    let event: CalendarEvent
    let userLocation: CLLocationCoordinate2D?

    @State private var mapSnapshot: UIImage?
    @State private var isLoadingMap = false
    @State private var eventCoordinate: CLLocationCoordinate2D?
    @State private var travelTimeWalking: TimeInterval?
    @State private var travelTimeDriving: TimeInterval?
    @State private var distanceMeters: Double?
    @State private var selectedTransport: TransportMode = .walking
    @State private var isLoadingLocation = false

    enum TransportMode {
        case walking, driving
    }

    private var hasLocation: Bool {
        event.location != nil && !event.location!.isEmpty
    }

    private var eventColor: Color {
        if let cgColor = event.calendarColor {
            return Color(cgColor: cgColor)
        }
        return Color.blue
    }

    private var estimatedDistance: Double? {
        guard let userLoc = userLocation, let eventLoc = eventCoordinate else { return nil }
        let userCLLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let destCLLocation = CLLocation(latitude: eventLoc.latitude, longitude: eventLoc.longitude)
        return userCLLocation.distance(from: destCLLocation)
    }

    private var estimatedWalkingTime: TimeInterval? {
        guard let dist = estimatedDistance else { return nil }
        return (dist / 1.4) * 1.2
    }

    private var estimatedDrivingTime: TimeInterval? {
        guard let dist = estimatedDistance else { return nil }
        return (dist / 8.3) * 1.3
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }

    private var leaveByTime: Date? {
        let actualTime = selectedTransport == .walking ? travelTimeWalking : travelTimeDriving
        let estimatedTime = selectedTransport == .walking ? estimatedWalkingTime : estimatedDrivingTime
        guard let travel = actualTime ?? estimatedTime else { return nil }
        return event.startDate.addingTimeInterval(-(travel + 300))
    }

    private var formattedTravelTime: String? {
        let actualTime = selectedTransport == .walking ? travelTimeWalking : travelTimeDriving
        let estimatedTime = selectedTransport == .walking ? estimatedWalkingTime : estimatedDrivingTime
        guard let travel = actualTime ?? estimatedTime else { return nil }
        let minutes = Int(travel / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMins = minutes % 60
            return "\(hours)h \(remainingMins)m"
        }
    }

    private var formattedDistance: String? {
        guard let meters = distanceMeters ?? estimatedDistance else { return nil }
        switch appState.unitSystem {
        case .metric:
            if meters < 1000 {
                return "\(Int(meters)) m"
            } else {
                let km = meters / 1000
                return String(format: "%.1f km", km)
            }
        case .imperial:
            let feet = meters * 3.28084
            if feet < 5280 {
                return "\(Int(feet)) ft"
            } else {
                let miles = meters / 1609.344
                return String(format: "%.1f mi", miles)
            }
        }
    }

    private var duration: TimeInterval {
        event.endDate.timeIntervalSince(event.startDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Map section (only if we have a location coordinate)
                    if let coordinate = eventCoordinate {
                        Button {
                            HapticManager.shared.buttonTap()
                            openInMaps(coordinate: coordinate)
                        } label: {
                            ZStack(alignment: .bottom) {
                                if let snapshot = mapSnapshot {
                                    Image(uiImage: snapshot)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 280)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color.tertiaryBackground)
                                        .frame(height: 280)
                                        .overlay {
                                            if isLoadingMap {
                                                ProgressView()
                                                    .tint(Color.textTertiary)
                                            }
                                        }
                                }

                                // Overlay info card
                                if let leaveBy = leaveByTime, let travelStr = formattedTravelTime {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Leave by")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(Color.textTertiary)
                                            Text(timeFormatter.string(from: leaveBy))
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundStyle(Color.textPrimary)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(travelStr)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(Color.textPrimary)
                                            if let dist = formattedDistance {
                                                Text(dist)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(Color.textSecondary)
                                            }
                                        }
                                    }
                                    .padding(16)
                                    .background(Color.secondaryBackground)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(height: 280)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.cardBorder, lineWidth: 0.5)
                        )
                        .padding(.top, 8)

                        // Transport mode toggle
                        if leaveByTime != nil && formattedTravelTime != nil {
                            HStack(spacing: 0) {
                                Button {
                                    HapticManager.shared.selection()
                                    selectedTransport = .walking
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "figure.walk")
                                            .font(.system(size: 14))
                                        Text("Walk")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(selectedTransport == .walking ? .white : Color.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedTransport == .walking ? Color.blue : Color.tertiaryBackground)
                                }

                                Button {
                                    HapticManager.shared.selection()
                                    selectedTransport = .driving
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "car.fill")
                                            .font(.system(size: 14))
                                        Text("Drive")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(selectedTransport == .driving ? .white : Color.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedTransport == .driving ? Color.blue : Color.tertiaryBackground)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.top, 8)
                        }

                        // Location row
                        if let location = event.location, !location.isEmpty {
                            Button {
                                HapticManager.shared.buttonTap()
                                openInMaps(coordinate: coordinate)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(eventColor)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(location)
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundStyle(Color.textPrimary)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.textTertiary)
                                }
                                .padding(16)
                                .background(Color.tertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .padding(.top, 12)
                        }
                    } else if hasLocation && isLoadingLocation {
                        // Loading state while geocoding
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.tertiaryBackground)
                            .frame(height: 150)
                            .overlay {
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .tint(Color.textTertiary)
                                    Text("Finding location...")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                            .padding(.top, 8)
                    } else if hasLocation && eventCoordinate == nil {
                        // Location text without coordinates
                        if let location = event.location {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(eventColor)

                                Text(location)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(2)

                                Spacer()
                            }
                            .padding(16)
                            .background(Color.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.top, 8)
                        }
                    }

                    // Event Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Event Details")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                            .padding(.top, eventCoordinate == nil && !hasLocation ? 16 : 20)

                        // Event name with color indicator
                        HStack(spacing: 14) {
                            // Dotted indicator circle
                            ZStack {
                                Circle()
                                    .fill(eventColor.opacity(0.2))
                                    .frame(width: 48, height: 48)

                                Circle()
                                    .strokeBorder(eventColor, style: StrokeStyle(lineWidth: 3, dash: [4, 3]))
                                    .frame(width: 32, height: 32)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)

                                Text(event.calendarTitle)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(14)
                        .background(Color.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // Date row
                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.textTertiary)

                            Text("Date")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.textSecondary)

                            Spacer()

                            Text(dateFormatter.string(from: event.startDate))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .padding(14)
                        .background(Color.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // Time row
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.textTertiary)
                                Text(timeFormatter.string(from: event.startDate))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textTertiary)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("End")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.textTertiary)
                                Text(timeFormatter.string(from: event.endDate))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }
                        .padding(14)
                        .background(Color.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // Duration
                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.textTertiary)

                            Text("Duration")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.textSecondary)

                            Spacer()

                            Text(formatDuration(duration))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .padding(14)
                        .background(Color.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // Open in Calendar button
                        Button {
                            HapticManager.shared.buttonTap()
                            openInCalendar()
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 16))
                                Text("View in Calendar")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(eventColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(eventColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
            }
            .background(Color.secondaryBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.secondaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
        .onAppear {
            if hasLocation {
                geocodeLocation()
            }
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMins = minutes % 60
            if remainingMins == 0 {
                return "\(hours) hr"
            }
            return "\(hours) hr \(remainingMins) min"
        }
    }

    private func geocodeLocation() {
        guard let location = event.location, !location.isEmpty else { return }
        isLoadingLocation = true

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location) { placemarks, error in
            DispatchQueue.main.async {
                isLoadingLocation = false
                if let placemark = placemarks?.first, let coordinate = placemark.location?.coordinate {
                    eventCoordinate = coordinate
                    generateMapSnapshot(for: coordinate)
                    calculateTravelTime(to: coordinate)
                }
            }
        }
    }

    private func generateMapSnapshot(for coordinate: CLLocationCoordinate2D) {
        isLoadingMap = true

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )
        options.size = CGSize(width: 400, height: 280)
        options.scale = UIScreen.main.scale
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        options.mapType = .mutedStandard
        options.showsBuildings = true
        options.pointOfInterestFilter = .excludingAll

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            DispatchQueue.main.async {
                isLoadingMap = false
                guard let snapshot = snapshot, error == nil else { return }

                let image = snapshot.image
                UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
                image.draw(at: .zero)

                // Draw pin
                let point = snapshot.point(for: coordinate)
                let pinSize: CGFloat = 28
                let pinRect = CGRect(
                    x: point.x - pinSize / 2,
                    y: point.y - pinSize - 4,
                    width: pinSize,
                    height: pinSize
                )

                // Use event color for pin
                var pinColor = UIColor.systemBlue
                if let cgColor = event.calendarColor {
                    pinColor = UIColor(cgColor: cgColor)
                }

                let pinPath = UIBezierPath(ovalIn: pinRect)
                pinColor.setFill()
                pinPath.fill()

                // White inner circle
                let innerRect = pinRect.insetBy(dx: 6, dy: 6)
                let innerPath = UIBezierPath(ovalIn: innerRect)
                UIColor.white.setFill()
                innerPath.fill()

                let finalImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()

                mapSnapshot = finalImage
            }
        }
    }

    private func calculateTravelTime(to coordinate: CLLocationCoordinate2D) {
        guard let userLoc = userLocation else { return }

        let source = MKPlacemark(coordinate: userLoc)
        let destination = MKPlacemark(coordinate: coordinate)

        // Walking
        let walkingRequest = MKDirections.Request()
        walkingRequest.source = MKMapItem(placemark: source)
        walkingRequest.destination = MKMapItem(placemark: destination)
        walkingRequest.transportType = .walking

        let walkingDirections = MKDirections(request: walkingRequest)
        walkingDirections.calculate { response, error in
            if let route = response?.routes.first {
                DispatchQueue.main.async {
                    self.travelTimeWalking = route.expectedTravelTime
                    self.distanceMeters = route.distance
                }
            }
        }

        // Driving
        let drivingRequest = MKDirections.Request()
        drivingRequest.source = MKMapItem(placemark: source)
        drivingRequest.destination = MKMapItem(placemark: destination)
        drivingRequest.transportType = .automobile

        let drivingDirections = MKDirections(request: drivingRequest)
        drivingDirections.calculate { response, error in
            if let route = response?.routes.first {
                DispatchQueue.main.async {
                    self.travelTimeDriving = route.expectedTravelTime
                }
            }
        }
    }

    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = event.location ?? event.title
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func openInCalendar() {
        // Open the Calendar app
        if let url = URL(string: "calshow://") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Schedule List Row (compact version)
struct ScheduleListRow: View {
    let lesson: Lesson
    let location: SavedLocation?
    let isActive: Bool
    let repeatPattern: RepeatPattern

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter
    }

    private var indicatorColor: Color {
        lesson.color.color
    }

    var body: some View {
        HStack(spacing: 10) {
            // Colored indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(indicatorColor)
                .frame(width: 3, height: 36)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(lesson.room)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.textSecondary)

                    if location != nil {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                        Text(location!.name)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Time
            Text("\(timeFormatter.string(from: lesson.startTime)) - \(timeFormatter.string(from: lesson.endTime))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Empty Schedule Card
struct EmptyScheduleCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 32))
                .foregroundStyle(Color.textTertiary)

            Text("No sessions scheduled")
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
    @State private var showingAddLocation = false
    @State private var editingLocation: SavedLocation?
    @State private var showingStudyTimer = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(appState.locations) { location in
                        Button {
                            editingLocation = location
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: location.iconName)
                                    .font(.system(size: 16))
                                    .foregroundStyle(locationColor(for: location.type))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(locationColor(for: location.type).opacity(0.15))
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(location.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.textPrimary)
                                    Text(location.type.name)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let location = appState.locations[index]
                            appState.deleteLocation(location)
                        }
                    }

                    Button {
                        HapticManager.shared.buttonTap()
                        showingAddLocation = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)

                            Text("Add Location")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("Locations")
                }

                Section("Notifications") {
                    SettingsRow(icon: "bell.fill", iconColor: .red, title: "Session Reminders") {
                        Toggle("", isOn: $classReminders)
                            .labelsHidden()
                            .onChange(of: classReminders) { _, _ in
                                HapticManager.shared.toggle()
                            }
                    }
                    SettingsRow(icon: "clock.fill", iconColor: .orange, title: "Reminder Time") {
                        Picker("", selection: $reminderTime) {
                            Text("5 min").tag(5)
                            Text("10 min").tag(10)
                            Text("15 min").tag(15)
                            Text("30 min").tag(30)
                        }
                        .labelsHidden()
                        .onChange(of: reminderTime) { _, _ in
                            HapticManager.shared.selection()
                        }
                    }
                    SettingsRow(icon: "car.fill", iconColor: .cyan, title: "Leave Now Alerts") {
                        Toggle("", isOn: $appState.leaveNowNotifications)
                            .labelsHidden()
                            .onChange(of: appState.leaveNowNotifications) { _, _ in
                                HapticManager.shared.toggle()
                            }
                    }
                }

                Section("Focus") {
                    SettingsRow(icon: "moon.fill", iconColor: .indigo, title: "Focus Mode") {
                        Toggle("", isOn: $appState.focusModeEnabled)
                            .labelsHidden()
                            .onChange(of: appState.focusModeEnabled) { _, _ in
                                HapticManager.shared.toggle()
                            }
                    }
                    if appState.focusModeEnabled {
                        SettingsRow(icon: "gear", iconColor: .gray, title: "Configure in Shortcuts") {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticManager.shared.buttonTap()
                            if let url = URL(string: "shortcuts://") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                Section {
                    SettingsRow(icon: "calendar", iconColor: .red, title: "Show Calendar Events") {
                        Toggle("", isOn: $appState.showCalendarEvents)
                            .labelsHidden()
                            .onChange(of: appState.showCalendarEvents) { _, _ in
                                HapticManager.shared.toggle()
                            }
                    }

                    if appState.showCalendarEvents && appState.calendarService.isAuthorized {
                        // Calendar selection
                        NavigationLink {
                            CalendarSelectionView()
                        } label: {
                            SettingsRow(icon: "checklist", iconColor: .orange, title: "Select Calendars") {
                                Text("\(appState.calendarService.selectedCalendarIds.count)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }
                    }

                    SettingsRow(icon: "arrow.triangle.2.circlepath", iconColor: .green, title: "Sync Sessions to Calendar") {
                        Toggle("", isOn: $appState.syncSessionsToCalendar)
                            .labelsHidden()
                            .onChange(of: appState.syncSessionsToCalendar) { _, _ in
                                HapticManager.shared.toggle()
                            }
                    }

                    if appState.syncSessionsToCalendar {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                            Text("Your sessions will be synced to a \"Keel Sessions\" calendar in Apple Calendar.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Calendar Integration")
                }

                Section("Live Activities") {
                    SettingsRow(icon: "lock.fill", iconColor: .purple, title: "Show on Lock Screen") {
                        Toggle("", isOn: $showOnLockScreen)
                            .labelsHidden()
                            .onChange(of: showOnLockScreen) { _, _ in
                                HapticManager.shared.toggle()
                            }
                    }
                    SettingsRow(icon: "capsule.portrait.fill", iconColor: .indigo, title: "Dynamic Island") {
                        Toggle("", isOn: $dynamicIsland)
                            .labelsHidden()
                            .onChange(of: dynamicIsland) { _, _ in
                                HapticManager.shared.toggle()
                            }
                    }
                    SettingsRow(icon: "timer", iconColor: .cyan, title: "Start Before Session") {
                        Picker("", selection: $appState.liveActivityLeadTime) {
                            Text("15 min").tag(15)
                            Text("30 min").tag(30)
                            Text("45 min").tag(45)
                            Text("1 hr").tag(60)
                            Text("2 hr").tag(120)
                        }
                        .labelsHidden()
                        .onChange(of: appState.liveActivityLeadTime) { _, _ in
                            HapticManager.shared.selection()
                        }
                    }
                }

                Section("Preferences") {
                    SettingsRow(icon: "ruler.fill", iconColor: .blue, title: "Units") {
                        Picker("", selection: $appState.unitSystem) {
                            Text("Imperial").tag(UnitSystem.imperial)
                            Text("Metric").tag(UnitSystem.metric)
                        }
                        .labelsHidden()
                        .onChange(of: appState.unitSystem) { _, _ in
                            HapticManager.shared.selection()
                        }
                    }
                    SettingsRow(icon: "calendar", iconColor: .green, title: "Week Starts On") {
                        Picker("", selection: $appState.weekStartDay) {
                            ForEach(WeekStartDay.allCases, id: \.self) { day in
                                Text(day.name).tag(day)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: appState.weekStartDay) { _, _ in
                            HapticManager.shared.selection()
                        }
                    }
                }

                Section("Tools") {
                    SettingsRow(icon: "timer", iconColor: .orange, title: "Study Timer") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.shared.buttonTap()
                        showingStudyTimer = true
                    }
                }

                Section("Data") {
                    SettingsRow(icon: "icloud.fill", iconColor: .blue, title: "Sync with iCloud") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.shared.buttonTap()
                        appState.loadData()
                    }
                }

                Section("About") {
                    SettingsRow(icon: "info.circle.fill", iconColor: .gray, title: "Version") {
                        Text("1.0.0")
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.secondaryBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.secondaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.dismiss()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddLocation) {
                LocationEditorSheet(mode: .create)
            }
            .sheet(item: $editingLocation) { location in
                LocationEditorSheet(mode: .edit(location))
            }
            .fullScreenCover(isPresented: $showingStudyTimer) {
                StudyTimerView()
                    .environmentObject(appState)
            }
        }
    }

    private func locationColor(for type: LocationType) -> Color {
        switch type {
        case .home: return Color.locationHome
        case .school: return Color.locationSchool
        case .library: return Color.locationLibrary
        case .office: return Color.locationOffice
        case .other: return Color.locationOther
        }
    }
}

// MARK: - Settings Row
struct SettingsRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconColor)
                )

            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            content()
        }
    }
}

// MARK: - Calendar Selection View
struct CalendarSelectionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(appState.calendarService.availableCalendars) { calendar in
                    Button {
                        HapticManager.shared.selection()
                        appState.calendarService.toggleCalendar(calendar.id)
                        // Refresh events after toggling
                        appState.refreshCalendarEvents()
                    } label: {
                        HStack(spacing: 12) {
                            // Calendar color indicator
                            Circle()
                                .fill(Color(hex: calendar.colorHex))
                                .frame(width: 20, height: 20)

                            Text(calendar.title)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            if appState.calendarService.selectedCalendarIds.contains(calendar.id) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text("Available Calendars")
            } footer: {
                Text("Select which calendars to show events from in your schedule.")
            }

            Section {
                Button {
                    HapticManager.shared.buttonTap()
                    // Select all calendars
                    for calendar in appState.calendarService.availableCalendars {
                        if !appState.calendarService.selectedCalendarIds.contains(calendar.id) {
                            appState.calendarService.toggleCalendar(calendar.id)
                        }
                    }
                    appState.refreshCalendarEvents()
                } label: {
                    Text("Select All")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.blue)
                }

                Button {
                    HapticManager.shared.buttonTap()
                    // Deselect all calendars
                    for calendar in appState.calendarService.availableCalendars {
                        if appState.calendarService.selectedCalendarIds.contains(calendar.id) {
                            appState.calendarService.toggleCalendar(calendar.id)
                        }
                    }
                    appState.refreshCalendarEvents()
                } label: {
                    Text("Deselect All")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.secondaryBackground)
        .navigationTitle("Select Calendars")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            appState.calendarService.fetchAvailableCalendars()
        }
    }
}

// MARK: - Location Editor Sheet
enum LocationEditorMode: Identifiable {
    case create
    case edit(SavedLocation)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let loc): return loc.id.uuidString
        }
    }
}

struct LocationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let mode: LocationEditorMode

    @State private var name: String = ""
    @State private var selectedType: LocationType = .school
    @State private var searchText: String = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedAddress: String?
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @FocusState private var isSearchFocused: Bool

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func iconColor(for type: LocationType) -> Color {
        switch type {
        case .home: return .orange
        case .school: return .green
        case .library: return .blue
        case .office: return .purple
        case .other: return .gray
        }
    }

    init(mode: LocationEditorMode) {
        self.mode = mode

        if case .edit(let location) = mode {
            _name = State(initialValue: location.name)
            _selectedType = State(initialValue: location.type)
            _searchText = State(initialValue: location.address ?? "")
            _selectedAddress = State(initialValue: location.address)
            _selectedCoordinate = State(initialValue: location.coordinate)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        // Type icon
                        Image(systemName: selectedType.defaultIcon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(iconColor(for: selectedType))
                            )

                        // Name field
                        TextField("Location Name", text: $name)
                            .font(.system(size: 17))

                        // Type picker (compact)
                        Menu {
                            ForEach(LocationType.allCases) { type in
                                Button {
                                    selectedType = type
                                } label: {
                                    Label(type.name, systemImage: type.defaultIcon)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedType.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.textSecondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.textTertiary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.tertiaryBackground)
                            )
                        }
                    }
                }

                Section {
                    TextField("Search for address...", text: $searchText)
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { _, newValue in
                            searchCompleter.search(query: newValue)
                        }

                    if selectedAddress != nil && !isSearchFocused {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(selectedAddress!)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                } header: {
                    Text("Address")
                }

                if isSearchFocused && !searchCompleter.results.isEmpty {
                    Section {
                        ForEach(searchCompleter.results, id: \.self) { result in
                            Button {
                                selectSearchResult(result)
                            } label: {
                                HStack(spacing: 14) {
                                    // Icon circle
                                    Image(systemName: selectedType.defaultIcon)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            Circle()
                                                .fill(iconColor(for: selectedType))
                                        )

                                    // Text content
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(result.title)
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundStyle(Color.textPrimary)
                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(.system(size: 14))
                                                .foregroundStyle(Color.textTertiary)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .listSectionSpacing(12)
            .scrollContentBackground(.hidden)
            .background(Color.secondaryBackground)
            .navigationTitle(isEditing ? "Edit Location" : "New Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.secondaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        HapticManager.shared.dismiss()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        HapticManager.shared.success()
                        saveLocation()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func selectSearchResult(_ result: MKLocalSearchCompletion) {
        HapticManager.shared.selection()
        isSearchFocused = false

        // If name is empty, use the result title
        if name.isEmpty {
            name = result.title
        }

        searchText = result.title
        selectedAddress = [result.title, result.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")

        // Get coordinates from the search result
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else { return }
            selectedCoordinate = coordinate
        }
    }

    private func saveLocation() {
        let coordinate = selectedCoordinate ?? appState.currentLocation ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let existingId: UUID?
        if case .edit(let location) = mode {
            existingId = location.id
        } else {
            existingId = nil
        }

        let location = SavedLocation(
            id: existingId ?? UUID(),
            name: name,
            coordinate: coordinate,
            type: selectedType,
            address: selectedAddress
        )

        appState.saveLocation(location)
        dismiss()
    }
}

// MARK: - Location Search Completer
class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = Array(completer.results.prefix(5))
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
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

// MARK: - Session Details Sheet
struct ClassDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    let lesson: Lesson
    let scheduledLesson: ScheduledLesson
    let location: SavedLocation?
    let userLocation: CLLocationCoordinate2D?
    let isActive: Bool

    @State private var mapSnapshot: UIImage?
    @State private var isLoadingMap = true
    @State private var travelTimeWalking: TimeInterval?
    @State private var travelTimeDriving: TimeInterval?
    @State private var distanceMeters: Double?
    @State private var selectedTransport: TransportMode = .walking
    @State private var showingEditor = false
    @State private var isLoadingTravelTime = true

    enum TransportMode {
        case walking, driving
    }

    // Quick estimate based on straight-line distance
    private var estimatedDistance: Double? {
        guard let userLoc = userLocation, let loc = location else { return nil }
        let userCLLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let destCLLocation = CLLocation(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        return userCLLocation.distance(from: destCLLocation)
    }

    private var estimatedWalkingTime: TimeInterval? {
        guard let dist = estimatedDistance else { return nil }
        // Average walking speed: ~5 km/h = 1.4 m/s, add 20% for non-straight paths
        return (dist / 1.4) * 1.2
    }

    private var estimatedDrivingTime: TimeInterval? {
        guard let dist = estimatedDistance else { return nil }
        // Average city driving: ~30 km/h = 8.3 m/s, add 30% for traffic/non-straight
        return (dist / 8.3) * 1.3
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    private var leaveByTime: Date? {
        // Use actual time if available, otherwise use estimate
        let actualTime = selectedTransport == .walking ? travelTimeWalking : travelTimeDriving
        let estimatedTime = selectedTransport == .walking ? estimatedWalkingTime : estimatedDrivingTime
        guard let travel = actualTime ?? estimatedTime else { return nil }
        // Add 5 minute buffer
        return lesson.startTime.addingTimeInterval(-(travel + 300))
    }

    private var formattedTravelTime: String? {
        // Use actual time if available, otherwise use estimate
        let actualTime = selectedTransport == .walking ? travelTimeWalking : travelTimeDriving
        let estimatedTime = selectedTransport == .walking ? estimatedWalkingTime : estimatedDrivingTime
        guard let travel = actualTime ?? estimatedTime else { return nil }
        let minutes = Int(travel / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMins = minutes % 60
            return "\(hours)h \(remainingMins)m"
        }
    }

    private var formattedDistance: String? {
        // Use actual distance if available, otherwise use estimate
        guard let meters = distanceMeters ?? estimatedDistance else { return nil }
        switch appState.unitSystem {
        case .metric:
            if meters < 1000 {
                return "\(Int(meters)) m"
            } else {
                let km = meters / 1000
                return String(format: "%.1f km", km)
            }
        case .imperial:
            let feet = meters * 3.28084
            if feet < 5280 {
                return "\(Int(feet)) ft"
            } else {
                let miles = meters / 1609.344
                return String(format: "%.1f mi", miles)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Map with overlaid info (like the reference image)
                    if let location = location {
                        Button {
                            HapticManager.shared.buttonTap()
                            openInMaps(location: location)
                        } label: {
                            ZStack(alignment: .bottom) {
                                // Map
                                if let snapshot = mapSnapshot {
                                    Image(uiImage: snapshot)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 280)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color.tertiaryBackground)
                                        .frame(height: 280)
                                        .overlay {
                                            if isLoadingMap {
                                                ProgressView()
                                                    .tint(Color.textTertiary)
                                            }
                                        }
                                }

                                // Overlay info card
                                VStack(spacing: 0) {
                                    // Leave by time (if available)
                                    if let leaveBy = leaveByTime, let travelStr = formattedTravelTime {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Leave by")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(Color.textTertiary)
                                                Text(timeFormatter.string(from: leaveBy))
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundStyle(Color.textPrimary)
                                            }

                                            Spacer()

                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text(travelStr)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(Color.textPrimary)
                                                if let dist = formattedDistance {
                                                    Text(dist)
                                                        .font(.system(size: 13))
                                                        .foregroundStyle(Color.textSecondary)
                                                }
                                            }
                                        }
                                        .padding(16)
                                        .background(Color.secondaryBackground)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(height: 280)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.cardBorder, lineWidth: 0.5)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Transport mode toggle (moved outside the button)
                        if leaveByTime != nil && formattedTravelTime != nil {
                            HStack(spacing: 0) {
                                Button {
                                    HapticManager.shared.selection()
                                    selectedTransport = .walking
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "figure.walk")
                                            .font(.system(size: 14))
                                        Text("Walk")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(selectedTransport == .walking ? .white : Color.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedTransport == .walking ? Color.blue : Color.tertiaryBackground)
                                }

                                Button {
                                    HapticManager.shared.selection()
                                    selectedTransport = .driving
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "car.fill")
                                            .font(.system(size: 14))
                                        Text("Drive")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(selectedTransport == .driving ? .white : Color.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedTransport == .driving ? Color.blue : Color.tertiaryBackground)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

                        // Location row (like "Starbucks, Singapore, SG")
                        Button {
                            HapticManager.shared.buttonTap()
                            openInMaps(location: location)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: location.iconName)
                                    .font(.system(size: 18))
                                    .foregroundStyle(locationColor(for: location.type))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(location.name)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(Color.textPrimary)
                                    if let address = location.address {
                                        Text(address)
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.textSecondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textTertiary)
                            }
                            .padding(16)
                            .background(Color.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    // Session Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Session Details")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                            .padding(.top, location == nil ? 16 : 20)

                        // Class name and room with icon
                        HStack(spacing: 14) {
                            // Icon with color background
                            ZStack {
                                Circle()
                                    .fill(lesson.color.color.opacity(0.2))
                                    .frame(width: 48, height: 48)

                                Image(systemName: lesson.icon.systemName)
                                    .font(.system(size: 20))
                                    .foregroundStyle(lesson.color.color)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(lesson.name)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)

                                    if isActive {
                                        Text("LIVE")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(Color.red))
                                    }
                                }

                                Text(lesson.room)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(14)
                        .background(Color.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // Time row
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.textTertiary)
                                Text(timeFormatter.string(from: lesson.startTime))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textTertiary)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("End")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.textTertiary)
                                Text(timeFormatter.string(from: lesson.endTime))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }
                        .padding(14)
                        .background(Color.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // Duration
                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.textTertiary)

                            Text("Duration")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.textSecondary)

                            Spacer()

                            Text(formatDuration(lesson.duration))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .padding(14)
                        .background(Color.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
            }
            .background(Color.secondaryBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.secondaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.shared.buttonTap()
                        showingEditor = true
                    } label: {
                        Text("Edit")
                            .font(.system(size: 17))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                LessonEditorView(mode: .edit(lesson, scheduledLesson))
            }
        }
        .onAppear {
            if let location = location {
                generateMapSnapshot(for: location)
                calculateTravelTime(to: location)
            }
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMins = minutes % 60
            if remainingMins == 0 {
                return "\(hours) hr"
            }
            return "\(hours) hr \(remainingMins) min"
        }
    }

    private func locationColor(for type: LocationType) -> Color {
        switch type {
        case .home: return .orange
        case .school: return .green
        case .library: return .blue
        case .office: return .purple
        case .other: return .gray
        }
    }

    private func calculateTravelTime(to location: SavedLocation) {
        guard let userLoc = userLocation else { return }

        let source = MKPlacemark(coordinate: userLoc)
        let destination = MKPlacemark(coordinate: location.coordinate)

        // Calculate walking time
        let walkingRequest = MKDirections.Request()
        walkingRequest.source = MKMapItem(placemark: source)
        walkingRequest.destination = MKMapItem(placemark: destination)
        walkingRequest.transportType = .walking

        let walkingDirections = MKDirections(request: walkingRequest)
        walkingDirections.calculate { response, error in
            if let route = response?.routes.first {
                DispatchQueue.main.async {
                    self.travelTimeWalking = route.expectedTravelTime
                    self.distanceMeters = route.distance
                }
            }
        }

        // Calculate driving time
        let drivingRequest = MKDirections.Request()
        drivingRequest.source = MKMapItem(placemark: source)
        drivingRequest.destination = MKMapItem(placemark: destination)
        drivingRequest.transportType = .automobile

        let drivingDirections = MKDirections(request: drivingRequest)
        drivingDirections.calculate { response, error in
            if let route = response?.routes.first {
                DispatchQueue.main.async {
                    self.travelTimeDriving = route.expectedTravelTime
                }
            }
        }
    }

    private func generateMapSnapshot(for location: SavedLocation) {
        isLoadingMap = true

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )
        options.size = CGSize(width: 400, height: 280)
        options.scale = UIScreen.main.scale
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        options.mapType = .mutedStandard
        options.showsBuildings = true
        options.pointOfInterestFilter = .excludingAll

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            DispatchQueue.main.async {
                isLoadingMap = false
                guard let snapshot = snapshot, error == nil else { return }

                let image = snapshot.image
                UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
                image.draw(at: .zero)

                // Draw pin
                let point = snapshot.point(for: location.coordinate)
                let pinSize: CGFloat = 28
                let pinRect = CGRect(
                    x: point.x - pinSize / 2,
                    y: point.y - pinSize - 4,
                    width: pinSize,
                    height: pinSize
                )

                // Pin color based on location type
                let pinColor: UIColor
                switch location.type {
                case .home: pinColor = .systemOrange
                case .school: pinColor = .systemGreen
                case .library: pinColor = .systemBlue
                case .office: pinColor = .systemPurple
                case .other: pinColor = .systemGray
                }

                pinColor.setFill()
                UIBezierPath(ovalIn: pinRect).fill()

                // White inner dot
                let innerSize: CGFloat = 10
                let innerRect = CGRect(
                    x: point.x - innerSize / 2,
                    y: point.y - pinSize / 2 - 4 - innerSize / 2,
                    width: innerSize,
                    height: innerSize
                )
                UIColor.white.setFill()
                UIBezierPath(ovalIn: innerRect).fill()

                mapSnapshot = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
            }
        }
    }

    private func openInMaps(location: SavedLocation) {
        let coordinate = location.coordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = location.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: selectedTransport == .walking ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - Calendar Popover View (Liquid Glass Style)
struct CalendarPopoverView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedDay: DayOfWeek
    @Binding var currentWeekOffset: Int
    @Binding var isPresented: Bool

    @State private var selectedDate: Date = Date()

    private var displayedDate: Date {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date()) else {
            return Date()
        }
        return date
    }

    private var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedDate)
    }

    private var weeksInMonth: [[Date?]] {
        let calendar = Calendar.current
        let weekStart = appState.weekStartDay == .monday ? 2 : 1

        // Get start of month for the displayed date
        var components = calendar.dateComponents([.year, .month], from: displayedDate)
        components.day = 1
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        var offset = firstWeekday - weekStart
        if offset < 0 { offset += 7 }

        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = Array(repeating: nil, count: offset)

        for day in range {
            components.day = day
            if let date = calendar.date(from: components) {
                currentWeek.append(date)
                if currentWeek.count == 7 {
                    weeks.append(currentWeek)
                    currentWeek = []
                }
            }
        }

        // Fill remaining week
        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(nil)
            }
            weeks.append(currentWeek)
        }

        return weeks
    }

    private var weekdayHeaders: [String] {
        appState.weekStartDay == .monday
            ? ["M", "T", "W", "T", "F", "S", "S"]
            : ["S", "M", "T", "W", "T", "F", "S"]
    }

    var body: some View {
        VStack(spacing: 12) {
            // Month navigation header
            HStack {
                Button {
                    HapticManager.shared.selection()
                    navigateMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.tertiaryBackground))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(currentMonthYear)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Button {
                    HapticManager.shared.selection()
                    navigateMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.tertiaryBackground))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            VStack(spacing: 4) {
                ForEach(Array(weeksInMonth.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(Array(week.enumerated()), id: \.offset) { dayIndex, date in
                            if let date = date {
                                CalendarDayButton(
                                    date: date,
                                    isSelected: isDateSelected(date),
                                    isToday: Calendar.current.isDateInToday(date),
                                    onTap: {
                                        selectDate(date)
                                    }
                                )
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                            }
                        }
                    }
                }
            }

            // Today button
            Button {
                HapticManager.shared.selection()
                goToToday()
            } label: {
                Text("Today")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.blue.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
        .frame(width: 280)
        .onAppear {
            // Set initial date based on current week offset and selected day
            updateSelectedDateFromState()
        }
    }

    private func updateSelectedDateFromState() {
        let calendar = Calendar.current
        let today = Date()

        // Get the date for the current week offset
        guard let weekDate = calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: today) else { return }

        // Find the specific day in that week
        let weekday = calendar.component(.weekday, from: weekDate)
        let targetWeekday = selectedDay.rawValue
        let dayDiff = targetWeekday - weekday

        if let targetDate = calendar.date(byAdding: .day, value: dayDiff, to: weekDate) {
            selectedDate = targetDate
        }
    }

    private func isDateSelected(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func selectDate(_ date: Date) {
        HapticManager.shared.selection()
        selectedDate = date
        navigateToDate(date)

        // Dismiss popover after selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isPresented = false
        }
    }

    private func goToToday() {
        selectedDate = Date()
        currentWeekOffset = 0
        selectedDay = .current

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isPresented = false
        }
    }

    private func navigateMonth(_ direction: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: direction, to: displayedDate) {
            // Calculate the new week offset
            let today = Date()
            guard let todayWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
                  let newWeekStart = calendar.dateInterval(of: .weekOfYear, for: newDate)?.start else { return }

            let components = calendar.dateComponents([.weekOfYear], from: todayWeekStart, to: newWeekStart)
            currentWeekOffset = components.weekOfYear ?? 0

            // Update selected day to first day of month
            let weekday = calendar.component(.weekday, from: newDate)
            if let day = DayOfWeek(rawValue: weekday) {
                selectedDay = day
            }

            selectedDate = newDate
        }
    }

    private func navigateToDate(_ date: Date) {
        let calendar = Calendar.current
        let today = Date()

        let startOfToday = calendar.startOfDay(for: today)
        let startOfTarget = calendar.startOfDay(for: date)

        guard let todayWeekStart = calendar.dateInterval(of: .weekOfYear, for: startOfToday)?.start,
              let targetWeekStart = calendar.dateInterval(of: .weekOfYear, for: startOfTarget)?.start else {
            return
        }

        let components = calendar.dateComponents([.weekOfYear], from: todayWeekStart, to: targetWeekStart)
        currentWeekOffset = components.weekOfYear ?? 0

        let weekday = calendar.component(.weekday, from: date)
        if let day = DayOfWeek(rawValue: weekday) {
            selectedDay = day
        }
    }
}

// MARK: - Calendar Day Button
struct CalendarDayButton: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                } else if isToday {
                    Circle()
                        .stroke(Color.red, lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }

                Text("\(dayNumber)")
                    .font(.system(size: 14, weight: isSelected || isToday ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : (isToday ? .red : Color.textPrimary))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    DashboardView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
