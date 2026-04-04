import SwiftUI
import ActivityKit
import CoreLocation
import WidgetKit

@main
struct KeelApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var activityManager = LessonActivityManager.shared
    @State private var showSplash = true

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(appState)
                    .preferredColorScheme(.dark)
                    .tint(Color.accent)
                    .onAppear {
                        appState.requestPermissions()
                    }

                if showSplash {
                    SplashScreen()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showSplash = false
                    }
                }
            }
        }
    }

    private func configureAppearance() {
        // Force dark mode
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = .dark }

        // Configure navigation bar appearance for dark mode
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.background)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(Color.accent)

        // Tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color.background)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}

// MARK: - Unit System
enum UnitSystem: String, CaseIterable {
    case metric
    case imperial

    var distanceUnit: String {
        switch self {
        case .metric: return "km"
        case .imperial: return "mi"
        }
    }

    var temperatureUnit: String {
        switch self {
        case .metric: return "C"
        case .imperial: return "F"
        }
    }
}

// MARK: - Week Start Day
enum WeekStartDay: String, CaseIterable {
    case sunday
    case monday

    var name: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        }
    }

    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        }
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var locations: [SavedLocation] = []
    @Published var lessons: [Lesson] = []
    @Published var scheduledLessons: [ScheduledLesson] = []
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var isOnline: Bool = true
    @Published var unitSystem: UnitSystem = .imperial {
        didSet {
            UserDefaults.standard.set(unitSystem.rawValue, forKey: "unitSystem")
        }
    }
    @Published var weekStartDay: WeekStartDay = .sunday {
        didSet {
            UserDefaults.standard.set(weekStartDay.rawValue, forKey: "weekStartDay")
        }
    }
    @Published var liveActivityLeadTime: Int = 30 {
        didSet {
            UserDefaults.standard.set(liveActivityLeadTime, forKey: "liveActivityLeadTime")
        }
    }
    @Published var leaveNowNotifications: Bool = true {
        didSet {
            UserDefaults.standard.set(leaveNowNotifications, forKey: "leaveNowNotifications")
            if leaveNowNotifications {
                scheduleAllLeaveNowNotifications()
            } else {
                notificationService.cancelLeaveNowNotifications()
            }
        }
    }
    @Published var focusModeEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(focusModeEnabled, forKey: "focusModeEnabled")
        }
    }
    @Published var showCalendarEvents: Bool = true {
        didSet {
            UserDefaults.standard.set(showCalendarEvents, forKey: "showCalendarEvents")
            if showCalendarEvents {
                refreshCalendarEvents()
            }
        }
    }
    @Published var syncSessionsToCalendar: Bool = false {
        didSet {
            UserDefaults.standard.set(syncSessionsToCalendar, forKey: "syncSessionsToCalendar")
        }
    }
    @Published var liveActivityEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(liveActivityEnabled, forKey: "liveActivityEnabled")
            if !liveActivityEnabled {
                // End any running live activities
                LessonActivityManager.shared.endActivity()
            }
        }
    }

    // This triggers view updates for time-sensitive displays (upcoming -> live transitions)
    @Published var refreshTrigger: Date = Date()

    // Calendar events for today
    @Published var calendarEvents: [CalendarEvent] = []

    let storageService = LocalStorageService()
    let locationService = LocationService()
    let notificationService = NotificationService()
    let calendarService = CalendarService.shared

    private var activityUpdateTimer: Timer?
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?

    init() {
        // Load saved unit system preference
        if let savedUnit = UserDefaults.standard.string(forKey: "unitSystem"),
           let unit = UnitSystem(rawValue: savedUnit) {
            unitSystem = unit
        }

        // Load saved week start day preference
        if let savedWeekStart = UserDefaults.standard.string(forKey: "weekStartDay"),
           let weekStart = WeekStartDay(rawValue: savedWeekStart) {
            weekStartDay = weekStart
        }

        // Load saved live activity lead time preference
        let savedLeadTime = UserDefaults.standard.integer(forKey: "liveActivityLeadTime")
        if savedLeadTime > 0 {
            liveActivityLeadTime = savedLeadTime
        }

        // Load saved leave now notifications preference (default to true)
        if UserDefaults.standard.object(forKey: "leaveNowNotifications") != nil {
            leaveNowNotifications = UserDefaults.standard.bool(forKey: "leaveNowNotifications")
        }

        // Load saved focus mode preference
        focusModeEnabled = UserDefaults.standard.bool(forKey: "focusModeEnabled")

        // Load saved show calendar events preference (default to true)
        if UserDefaults.standard.object(forKey: "showCalendarEvents") != nil {
            showCalendarEvents = UserDefaults.standard.bool(forKey: "showCalendarEvents")
        }

        // Load saved sync sessions to calendar preference
        syncSessionsToCalendar = UserDefaults.standard.bool(forKey: "syncSessionsToCalendar")

        // Load saved live activity enabled preference (default to true)
        if UserDefaults.standard.object(forKey: "liveActivityEnabled") != nil {
            liveActivityEnabled = UserDefaults.standard.bool(forKey: "liveActivityEnabled")
        }

        setupLocationUpdates()
        setupActivityStateCallback()
        loadData()
        setupActivityTimer()
        setupForegroundObserver()
        setupBackgroundObserver()
        setupCalendarService()
    }

    private func setupCalendarService() {
        // Request calendar access if showing calendar events is enabled or sync is enabled
        if showCalendarEvents || syncSessionsToCalendar {
            Task {
                let granted = await calendarService.requestAccess()
                if granted {
                    calendarService.fetchAvailableCalendars()
                    calendarService.fetchTodayEvents()
                    calendarEvents = calendarService.todayEvents
                }
            }
        }
    }

    func refreshCalendarEvents() {
        guard showCalendarEvents else {
            calendarEvents = []
            return
        }

        if calendarService.isAuthorized {
            calendarService.fetchTodayEvents()
            calendarEvents = calendarService.todayEvents
        } else {
            Task {
                let granted = await calendarService.requestAccess()
                if granted {
                    calendarService.fetchTodayEvents()
                    calendarEvents = calendarService.todayEvents
                }
            }
        }
    }

    func fetchCalendarEventsForDay(_ dayOfWeek: DayOfWeek, weekOffset: Int = 0) -> [CalendarEvent] {
        guard showCalendarEvents && calendarService.isAuthorized else { return [] }

        // DayOfWeek.rawValue matches Calendar's weekday (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
        calendarService.fetchEventsForDay(dayOfWeek.rawValue, weekOffset: weekOffset)
        return calendarService.todayEvents
    }

    private func setupActivityStateCallback() {
        // Enable/disable background location updates based on live activity state
        LessonActivityManager.shared.onActivityStateChanged = { [weak self] isActive in
            if isActive {
                self?.locationService.enableBackgroundUpdates()
            } else {
                self?.locationService.disableBackgroundUpdates()
            }
        }
    }

    private func setupActivityTimer() {
        // Update Live Activity and UI every 15 seconds for better accuracy
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLiveActivity()
                // Trigger view refresh for time-sensitive UI (upcoming -> live transitions)
                self?.refreshTrigger = Date()
            }
        }
        // Add to common run loop mode so it fires during scrolling
        RunLoop.main.add(timer, forMode: .common)
        activityUpdateTimer = timer

        // Fire immediately
        timer.fire()
    }

    private func setupForegroundObserver() {
        // Update Live Activity and UI when app comes to foreground
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateLiveActivity()
                // Trigger view refresh for time-sensitive UI
                self?.refreshTrigger = Date()
                // Sync widget data
                self?.syncWidgetData()
                // Refresh calendar events
                self?.refreshCalendarEvents()
            }
        }
    }

    private func setupBackgroundObserver() {
        // When entering background, ensure we have latest activity state
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // Update live activity one more time before background
                self?.updateLiveActivity()
                // Sync widget data before going to background
                self?.syncWidgetData()
                // Only enable background updates if there's an active live activity
                if LessonActivityManager.shared.hasActiveActivity {
                    self?.locationService.enableBackgroundUpdates()
                }
            }
        }
    }

    func requestPermissions() {
        locationService.requestPermission()
        notificationService.requestPermission()

        // Start tracking once permissions are requested
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.locationService.startTracking()
            self?.locationService.requestCurrentLocation()
        }
    }

    private func setupLocationUpdates() {
        locationService.onLocationUpdate = { [weak self] coordinate in
            Task { @MainActor in
                self?.currentLocation = coordinate
                self?.updateOnlineStatus()
                // Update live activity when location changes (works in background too)
                self?.updateLiveActivity()
            }
        }
    }

    private func updateOnlineStatus() {
        // User is "online" if location was updated recently
        isOnline = locationService.lastUpdateTime.timeIntervalSinceNow > -300 // 5 minutes
    }

    func loadData() {
        // Load from local storage
        locations = storageService.fetchLocations()
        lessons = storageService.fetchLessons()
        scheduledLessons = storageService.fetchScheduledLessons()

        // Clean up orphaned scheduled lessons (those that reference non-existent lessons)
        let validLessonIds = Set(lessons.map { $0.id })
        let orphanedScheduledLessons = scheduledLessons.filter { !validLessonIds.contains($0.lessonId) }
        if !orphanedScheduledLessons.isEmpty {
            scheduledLessons.removeAll { !validLessonIds.contains($0.lessonId) }
            storageService.saveScheduledLessons(scheduledLessons)
        }

        // Update Live Activity after data loads
        updateLiveActivity()

        // Sync widget and intent data
        syncWidgetData()
    }

    func saveLesson(_ lesson: Lesson) {
        // Update in-memory state
        if let index = lessons.firstIndex(where: { $0.id == lesson.id }) {
            lessons[index] = lesson
        } else {
            lessons.append(lesson)
        }

        // Persist to local storage
        storageService.saveLesson(lesson)

        // Schedule notification
        notificationService.scheduleNotification(for: lesson, scheduledLessons: scheduledLessons)

        // Sync to Apple Calendar if enabled
        if syncSessionsToCalendar {
            syncLessonToCalendar(lesson)
        }

        // Sync widget data
        syncWidgetData()
    }

    func deleteLesson(_ lesson: Lesson) {
        // Remove synced calendar event if exists
        if syncSessionsToCalendar {
            deleteLessonFromCalendar(lesson)
        }

        // Remove from local storage
        storageService.deleteLesson(lesson)

        // Update in-memory state
        lessons.removeAll { $0.id == lesson.id }
        scheduledLessons.removeAll { $0.lessonId == lesson.id }

        // Cancel notifications
        notificationService.cancelNotifications(for: lesson)

        // Sync widget data
        syncWidgetData()
    }

    // MARK: - Calendar Sync

    private var calendarEventIds: [String: String] {
        get {
            UserDefaults.standard.dictionary(forKey: "calendarEventIds") as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "calendarEventIds")
        }
    }

    private func syncLessonToCalendar(_ lesson: Lesson) {
        let location = locations.first(where: { $0.id == lesson.locationId })
        let scheduledDays = scheduledLessons.filter { $0.lessonId == lesson.id }

        for scheduled in scheduledDays {
            let existingEventId = calendarEventIds["\(lesson.id.uuidString)_\(scheduled.dayOfWeek.rawValue)"]

            if let eventId = calendarService.syncSession(
                name: lesson.name,
                room: lesson.room,
                locationName: location?.name,
                locationAddress: location?.address,
                startTime: lesson.startTime,
                endTime: lesson.endTime,
                dayOfWeek: scheduled.dayOfWeek.rawValue,
                repeatWeekly: scheduled.repeatPattern == .weekly,
                existingEventId: existingEventId
            ) {
                var ids = calendarEventIds
                ids["\(lesson.id.uuidString)_\(scheduled.dayOfWeek.rawValue)"] = eventId
                calendarEventIds = ids
            }
        }
    }

    private func deleteLessonFromCalendar(_ lesson: Lesson) {
        let scheduledDays = scheduledLessons.filter { $0.lessonId == lesson.id }
        var ids = calendarEventIds

        for scheduled in scheduledDays {
            let key = "\(lesson.id.uuidString)_\(scheduled.dayOfWeek.rawValue)"
            if let eventId = ids[key] {
                calendarService.deleteSession(eventId: eventId)
                ids.removeValue(forKey: key)
            }
        }

        calendarEventIds = ids
    }

    func saveLocation(_ location: SavedLocation) {
        // Update in-memory state
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            locations[index] = location
        } else {
            locations.append(location)
        }

        // Persist to local storage
        storageService.saveLocation(location)
    }

    func deleteLocation(_ location: SavedLocation) {
        // Remove from local storage
        storageService.deleteLocation(location)

        // Update in-memory state
        locations.removeAll { $0.id == location.id }
    }

    func saveScheduledLesson(_ scheduledLesson: ScheduledLesson) {
        // Update in-memory state
        if let index = scheduledLessons.firstIndex(where: { $0.id == scheduledLesson.id }) {
            scheduledLessons[index] = scheduledLesson
        } else {
            scheduledLessons.append(scheduledLesson)
        }

        // Persist to local storage
        storageService.saveScheduledLesson(scheduledLesson)

        // Update notification
        if let lesson = lessons.first(where: { $0.id == scheduledLesson.lessonId }) {
            notificationService.scheduleNotification(for: lesson, scheduledLessons: scheduledLessons)
        }

        // Sync widget data
        syncWidgetData()
    }

    // MARK: - Computed Properties

    func lessonsForToday() -> [ScheduledLesson] {
        let today = DayOfWeek.current
        return scheduledLessons.filter { $0.dayOfWeek == today }
            .sorted { lesson1, lesson2 in
                guard let l1 = lessons.first(where: { $0.id == lesson1.lessonId }),
                      let l2 = lessons.first(where: { $0.id == lesson2.lessonId }) else {
                    return false
                }
                return l1.startTime < l2.startTime
            }
    }

    func currentLesson() -> Lesson? {
        let now = Date()
        let todayLessons = lessonsForToday()

        for scheduled in todayLessons {
            if let lesson = lessons.first(where: { $0.id == scheduled.lessonId }) {
                let calendar = Calendar.current
                let startComponents = calendar.dateComponents([.hour, .minute], from: lesson.startTime)
                let endComponents = calendar.dateComponents([.hour, .minute], from: lesson.endTime)

                var todayStart = calendar.dateComponents([.year, .month, .day], from: now)
                todayStart.hour = startComponents.hour
                todayStart.minute = startComponents.minute

                var todayEnd = calendar.dateComponents([.year, .month, .day], from: now)
                todayEnd.hour = endComponents.hour
                todayEnd.minute = endComponents.minute

                if let start = calendar.date(from: todayStart),
                   let end = calendar.date(from: todayEnd),
                   now >= start && now <= end {
                    return lesson
                }
            }
        }
        return nil
    }

    func nextLesson() -> (lesson: Lesson, startsIn: TimeInterval)? {
        let now = Date()
        let todayLessons = lessonsForToday()
        let calendar = Calendar.current

        for scheduled in todayLessons {
            if let lesson = lessons.first(where: { $0.id == scheduled.lessonId }) {
                let startComponents = calendar.dateComponents([.hour, .minute], from: lesson.startTime)

                var todayStart = calendar.dateComponents([.year, .month, .day], from: now)
                todayStart.hour = startComponents.hour
                todayStart.minute = startComponents.minute

                if let start = calendar.date(from: todayStart), now < start {
                    return (lesson, start.timeIntervalSince(now))
                }
            }
        }
        return nil
    }

    func lessonEndTime() -> Date? {
        let todayLessons = lessonsForToday()
        guard let lastScheduled = todayLessons.last,
              let lastLesson = lessons.first(where: { $0.id == lastScheduled.lessonId }) else {
            return nil
        }

        let calendar = Calendar.current
        let endComponents = calendar.dateComponents([.hour, .minute], from: lastLesson.endTime)
        var todayEnd = calendar.dateComponents([.year, .month, .day], from: Date())
        todayEnd.hour = endComponents.hour
        todayEnd.minute = endComponents.minute

        return calendar.date(from: todayEnd)
    }

    func lessonsForDay(_ day: DayOfWeek) -> [ScheduledLesson] {
        scheduledLessons.filter { $0.dayOfWeek == day }
            .sorted { lesson1, lesson2 in
                guard let l1 = lessons.first(where: { $0.id == lesson1.lessonId }),
                      let l2 = lessons.first(where: { $0.id == lesson2.lessonId }) else {
                    return false
                }
                return l1.startTime < l2.startTime
            }
    }

    // MARK: - Live Activities

    func updateLiveActivity() {
        let activityManager = LessonActivityManager.shared

        // If live activities are disabled, end any running activity
        guard liveActivityEnabled else {
            activityManager.endActivity()
            return
        }

        // Check for current lesson
        if let currentLesson = currentLesson() {
            let location = locations.first(where: { $0.id == currentLesson.locationId })
            let locationName = location?.name ?? "School"
            let destinationCoordinate = currentLesson.buildingCoordinate ?? location?.coordinate
            activityManager.startLiveActivity(
                for: currentLesson,
                locationName: locationName,
                isLive: true,
                destinationCoordinate: destinationCoordinate,
                userLocation: currentLocation
            )
        }
        // Check for upcoming lesson (only if within lead time)
        else if let (nextLesson, startsIn) = nextLesson() {
            let leadTimeSeconds = TimeInterval(liveActivityLeadTime * 60)
            if startsIn <= leadTimeSeconds {
                let location = locations.first(where: { $0.id == nextLesson.locationId })
                let locationName = location?.name ?? "School"
                let destinationCoordinate = nextLesson.buildingCoordinate ?? location?.coordinate
                activityManager.startLiveActivity(
                    for: nextLesson,
                    locationName: locationName,
                    isLive: false,
                    destinationCoordinate: destinationCoordinate,
                    userLocation: currentLocation
                )
            } else {
                activityManager.endActivity()
            }
        }
        // No lessons - end activity
        else {
            activityManager.endActivity()
        }
    }

    // MARK: - Leave Now Notifications

    func scheduleAllLeaveNowNotifications() {
        guard leaveNowNotifications else { return }

        for lesson in lessons {
            let scheduledDays = scheduledLessons.filter { $0.lessonId == lesson.id }.map { $0.dayOfWeek }
            for day in scheduledDays {
                scheduleLeaveNowNotification(for: lesson, on: day)
            }
        }
    }

    func scheduleLeaveNowNotification(for lesson: Lesson, on day: DayOfWeek) {
        guard leaveNowNotifications else { return }

        // Get destination coordinate
        let location = locations.first(where: { $0.id == lesson.locationId })
        guard let destinationCoordinate = lesson.buildingCoordinate ?? location?.coordinate else { return }

        // Calculate travel time based on current location or default
        let userCoordinate = currentLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        guard userCoordinate.latitude != 0 else { return }

        let userLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let destination = CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude)
        let distance = userLocation.distance(from: destination)

        // Estimate driving time: ~30 km/h average with buffer
        let drivingSpeedMps = 8.3
        let estimatedSeconds = (distance / drivingSpeedMps) * 1.3
        let estimatedMinutes = Int(ceil(estimatedSeconds / 60))

        // Add 5 minute buffer for parking/walking
        let totalLeadTime = estimatedMinutes + 5

        notificationService.scheduleLeaveNowNotification(
            for: lesson,
            on: day,
            travelTimeMinutes: totalLeadTime,
            destinationName: location?.name ?? "class"
        )
    }

    // MARK: - Widget & Intent Data Sync

    func syncWidgetData() {
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard

        // Sync next class widget data
        if let (nextLesson, _) = nextLesson() {
            let widgetData = WidgetClassData(
                name: nextLesson.name,
                room: nextLesson.room,
                startTime: nextLesson.startTime,
                endTime: nextLesson.endTime,
                colorHex: nextLesson.color.hexString,
                iconName: nextLesson.icon.systemName
            )
            if let data = try? JSONEncoder().encode(widgetData) {
                defaults.set(data, forKey: "nextClassWidget")
            }
        } else {
            defaults.removeObject(forKey: "nextClassWidget")
        }

        // Sync today's schedule widget data
        let todaySchedule = lessonsForToday().compactMap { scheduled -> ScheduleWidgetClass? in
            guard let lesson = lessons.first(where: { $0.id == scheduled.lessonId }) else { return nil }
            let isActive = currentLesson()?.id == lesson.id
            return ScheduleWidgetClass(
                name: lesson.name,
                room: lesson.room,
                startTime: lesson.formattedStartTime,
                endTime: lesson.formattedEndTime,
                colorHex: lesson.color.hexString,
                iconName: lesson.icon.systemName,
                isActive: isActive
            )
        }
        if let data = try? JSONEncoder().encode(todaySchedule) {
            defaults.set(data, forKey: "todayScheduleWidget")
        }

        // Sync intent data (lessons and today's schedule)
        let intentLessons = lessons.map { lesson in
            IntentLesson(
                id: lesson.id,
                name: lesson.name,
                room: lesson.room,
                building: lesson.building,
                startTime: lesson.startTime,
                endTime: lesson.endTime,
                colorHex: lesson.color.hexString,
                iconSystemName: lesson.icon.systemName
            )
        }
        if let data = try? JSONEncoder().encode(intentLessons) {
            defaults.set(data, forKey: "intentLessons")
        }

        let intentSchedule = lessonsForToday().map { scheduled in
            IntentScheduledLesson(
                id: scheduled.id,
                lessonId: scheduled.lessonId,
                dayOfWeek: scheduled.dayOfWeek.rawValue
            )
        }
        if let data = try? JSONEncoder().encode(intentSchedule) {
            defaults.set(data, forKey: "intentTodaySchedule")
        }

        // Reload widgets
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Widget Data Models
struct WidgetClassData: Codable {
    let name: String
    let room: String
    let startTime: Date
    let endTime: Date
    let colorHex: String
    let iconName: String
}

struct ScheduleWidgetClass: Codable {
    let name: String
    let room: String
    let startTime: String
    let endTime: String
    let colorHex: String
    let iconName: String
    let isActive: Bool
}

// MARK: - Intent Data Models
struct IntentLesson: Codable, Identifiable {
    let id: UUID
    var name: String
    var room: String
    var building: String?
    var startTime: Date
    var endTime: Date
    var colorHex: String
    var iconSystemName: String
}

struct IntentScheduledLesson: Codable, Identifiable {
    let id: UUID
    let lessonId: UUID
    let dayOfWeek: Int
}
