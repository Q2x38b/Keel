import ActivityKit
import SwiftUI

struct LessonActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var lessonName: String
        var room: String
        var building: String?
        var startTime: Date
        var endTime: Date
        var colorHex: String
        var isLive: Bool
        var progress: Double
        var timeRemaining: TimeInterval
    }

    var locationName: String
    var lessonId: String
}

// MARK: - Activity Manager
@MainActor
class LessonActivityManager: ObservableObject {
    static let shared = LessonActivityManager()

    @Published private(set) var currentActivity: Activity<LessonActivityAttributes>?
    @Published private(set) var hasActiveActivity: Bool = false
    private var currentLessonId: String?
    private var isCreatingActivity = false // Prevent concurrent creation

    // Callback for when activity state changes (used to enable/disable background location)
    var onActivityStateChanged: ((Bool) -> Void)?

    private init() {
        // Clean up any orphaned activities on init
        cleanupOrphanedActivities()
    }

    /// Clean up any activities that may have been left over from a previous session
    private func cleanupOrphanedActivities() {
        Task {
            for activity in Activity<LessonActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func startLiveActivity(for lesson: Lesson, locationName: String, isLive: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Activities not enabled")
            return
        }

        // Prevent concurrent activity creation
        guard !isCreatingActivity else {
            print("[LiveActivity] Already creating activity, skipping")
            return
        }

        let lessonIdString = lesson.id.uuidString

        // Check if we already have an activity for this exact lesson
        if let activity = currentActivity, currentLessonId == lessonIdString {
            // Verify the activity is still valid
            if activity.activityState == .active || activity.activityState == .stale {
                updateActivity(lesson: lesson, isLive: isLive)
                return
            }
        }

        // Check if there's already an active activity in the system for this lesson
        if let existingActivity = Activity<LessonActivityAttributes>.activities.first(where: {
            $0.attributes.lessonId == lessonIdString &&
            ($0.activityState == .active || $0.activityState == .stale)
        }) {
            // Use the existing activity
            currentActivity = existingActivity
            currentLessonId = lessonIdString
            updateActivity(lesson: lesson, isLive: isLive)
            print("[LiveActivity] Reusing existing activity for: \(lesson.name)")
            return
        }

        // Need to create a new activity - first clean up
        isCreatingActivity = true
        endAllActivities()

        // Small delay to ensure cleanup completes, then create new activity
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.createActivity(for: lesson, locationName: locationName, isLive: isLive)
        }
    }

    /// Aggressively ends ALL activities - both tracked and orphaned
    private func endAllActivities() {
        // End our tracked activity
        if let activity = currentActivity {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
        currentLessonId = nil

        // End ALL activities in case there are orphans
        for activity in Activity<LessonActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func createActivity(for lesson: Lesson, locationName: String, isLive: Bool) {
        // Check for existing activities (excluding ended/dismissed ones)
        let activeActivities = Activity<LessonActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }

        if !activeActivities.isEmpty {
            print("[LiveActivity] Still have \(activeActivities.count) active activities, cleaning up")

            // End all active activities
            for activity in activeActivities {
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }

            // Try again after another delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.doCreateActivity(for: lesson, locationName: locationName, isLive: isLive)
            }
            return
        }

        doCreateActivity(for: lesson, locationName: locationName, isLive: isLive)
    }

    private func doCreateActivity(for lesson: Lesson, locationName: String, isLive: Bool) {
        defer { isCreatingActivity = false }

        let lessonIdString = lesson.id.uuidString
        let now = Date()
        let calendar = Calendar.current

        // Double-check no duplicate exists
        if Activity<LessonActivityAttributes>.activities.contains(where: {
            $0.attributes.lessonId == lessonIdString &&
            ($0.activityState == .active || $0.activityState == .stale)
        }) {
            print("[LiveActivity] Activity already exists, skipping creation")
            return
        }

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
            print("[LiveActivity] Failed to create dates")
            return
        }

        let total = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        let progress = isLive ? min(max(elapsed / total, 0), 1) : 0
        let timeRemaining = isLive ? end.timeIntervalSince(now) : start.timeIntervalSince(now)

        let attributes = LessonActivityAttributes(
            locationName: locationName,
            lessonId: lessonIdString
        )

        let state = LessonActivityAttributes.ContentState(
            lessonName: lesson.name,
            room: lesson.room,
            building: lesson.building,
            startTime: start,
            endTime: end,
            colorHex: lesson.color.hexString,
            isLive: isLive,
            progress: progress,
            timeRemaining: timeRemaining
        )

        // Use a shorter stale date for more frequent updates
        let staleDate = Calendar.current.date(byAdding: .minute, value: 1, to: now) ?? end

        let content = ActivityContent(state: state, staleDate: staleDate)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            currentLessonId = lessonIdString
            hasActiveActivity = true
            onActivityStateChanged?(true)
            print("[LiveActivity] Started activity for: \(lesson.name)")
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    func updateActivity(lesson: Lesson, isLive: Bool) {
        guard let activity = currentActivity else { return }

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
              let end = calendar.date(from: todayEnd) else { return }

        let total = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        let progress = isLive ? min(max(elapsed / total, 0), 1) : 0
        let timeRemaining = isLive ? end.timeIntervalSince(now) : start.timeIntervalSince(now)

        let state = LessonActivityAttributes.ContentState(
            lessonName: lesson.name,
            room: lesson.room,
            building: lesson.building,
            startTime: start,
            endTime: end,
            colorHex: lesson.color.hexString,
            isLive: isLive,
            progress: progress,
            timeRemaining: timeRemaining
        )

        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: end.addingTimeInterval(60)),
                alertConfiguration: nil
            )
        }
    }

    func endActivity() {
        endAllActivities()
        hasActiveActivity = false
        onActivityStateChanged?(false)
        print("[LiveActivity] Ended all activities")
    }
}

// MARK: - Lesson Color Hex Extension
extension LessonColor {
    var hexString: String {
        switch self {
        case .red: return "#FF3B30"
        case .orange: return "#FF9500"
        case .yellow: return "#FFCC00"
        case .green: return "#34C759"
        case .blue: return "#007AFF"
        case .purple: return "#AF52DE"
        case .pink: return "#FF2D55"
        case .teal: return "#5AC8FA"
        }
    }
}
