import SwiftUI
import ActivityKit
import CoreLocation

@main
struct GyreApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var activityManager = LessonActivityManager.shared

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .tint(Color.accent)
                .onAppear {
                    appState.requestPermissions()
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

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var locations: [SavedLocation] = []
    @Published var lessons: [Lesson] = []
    @Published var scheduledLessons: [ScheduledLesson] = []
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var isOnline: Bool = true

    let storageService = LocalStorageService()
    let locationService = LocationService()
    let notificationService = NotificationService()

    private var activityUpdateTimer: Timer?
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?

    init() {
        setupLocationUpdates()
        setupActivityStateCallback()
        loadData()
        setupActivityTimer()
        setupForegroundObserver()
        setupBackgroundObserver()
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
        // Update Live Activity every 15 seconds for better accuracy
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLiveActivity()
            }
        }
        // Add to common run loop mode so it fires during scrolling
        RunLoop.main.add(timer, forMode: .common)
        activityUpdateTimer = timer

        // Fire immediately
        timer.fire()
    }

    private func setupForegroundObserver() {
        // Update Live Activity when app comes to foreground
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateLiveActivity()
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

        // Update Live Activity after data loads
        updateLiveActivity()
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
    }

    func deleteLesson(_ lesson: Lesson) {
        // Remove from local storage
        storageService.deleteLesson(lesson)

        // Update in-memory state
        lessons.removeAll { $0.id == lesson.id }
        scheduledLessons.removeAll { $0.lessonId == lesson.id }

        // Cancel notifications
        notificationService.cancelNotifications(for: lesson)
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

        // Check for current lesson
        if let currentLesson = currentLesson() {
            let locationName = locations.first(where: { $0.id == currentLesson.locationId })?.name ?? "School"
            activityManager.startLiveActivity(for: currentLesson, locationName: locationName, isLive: true)
        }
        // Check for upcoming lesson
        else if let (nextLesson, _) = nextLesson() {
            let locationName = locations.first(where: { $0.id == nextLesson.locationId })?.name ?? "School"
            activityManager.startLiveActivity(for: nextLesson, locationName: locationName, isLive: false)
        }
        // No lessons - end activity
        else {
            activityManager.endActivity()
        }
    }
}
