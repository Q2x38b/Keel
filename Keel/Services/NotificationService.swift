import Foundation
import UserNotifications

class NotificationService {
    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Permission

    func requestPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Schedule Notifications

    func scheduleNotification(for lesson: Lesson, scheduledLessons: [ScheduledLesson]) {
        guard lesson.notifyMinutesBefore > 0 else { return }

        // Get all days this lesson is scheduled
        let scheduledDays = scheduledLessons
            .filter { $0.lessonId == lesson.id }
            .map { $0.dayOfWeek }

        for day in scheduledDays {
            scheduleNotification(for: lesson, on: day)
        }
    }

    private func scheduleNotification(for lesson: Lesson, on day: DayOfWeek) {
        guard lesson.notifyMinutesBefore > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Session"
        content.body = "\(lesson.name) starts in \(lesson.notifyMinutesBefore) minutes"
        content.subtitle = lesson.room
        content.sound = .default
        content.categoryIdentifier = "LESSON_REMINDER"

        // Add lesson info to userInfo for handling taps
        content.userInfo = [
            "lessonId": lesson.id.uuidString,
            "lessonName": lesson.name
        ]

        // Calculate trigger time
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: lesson.startTime)

        var dateComponents = DateComponents()
        dateComponents.weekday = day.rawValue
        dateComponents.hour = startComponents.hour
        dateComponents.minute = (startComponents.minute ?? 0) - lesson.notifyMinutesBefore

        // Handle negative minutes (e.g., 9:10 - 15 minutes = 8:55)
        if let minute = dateComponents.minute, minute < 0 {
            dateComponents.minute = 60 + minute
            dateComponents.hour = (dateComponents.hour ?? 0) - 1

            // Handle midnight rollover
            if let hour = dateComponents.hour, hour < 0 {
                dateComponents.hour = 23
                dateComponents.weekday = (day.rawValue - 1 == 0) ? 7 : day.rawValue - 1
            }
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let identifier = notificationIdentifier(for: lesson, on: day)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cancel Notifications

    func cancelNotifications(for lesson: Lesson) {
        // Cancel all notifications for this lesson (all days)
        let identifiers = DayOfWeek.allCases.map { notificationIdentifier(for: lesson, on: $0) }
        let leaveNowIds = DayOfWeek.allCases.map { leaveNowIdentifier(for: lesson, on: $0) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers + leaveNowIds)
    }

    func cancelNotification(for lesson: Lesson, on day: DayOfWeek) {
        let identifier = notificationIdentifier(for: lesson, on: day)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - List Pending Notifications

    func getPendingNotifications() async -> [UNNotificationRequest] {
        await notificationCenter.pendingNotificationRequests()
    }

    // MARK: - Leave Now Notifications

    func scheduleLeaveNowNotification(for lesson: Lesson, on day: DayOfWeek, travelTimeMinutes: Int, destinationName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Leave"
        content.body = "Leave now to arrive at \(lesson.name) on time (~\(travelTimeMinutes) min drive to \(destinationName))"
        content.subtitle = lesson.room
        content.sound = .default
        content.categoryIdentifier = "LEAVE_NOW"
        content.interruptionLevel = .timeSensitive

        content.userInfo = [
            "lessonId": lesson.id.uuidString,
            "lessonName": lesson.name,
            "type": "leaveNow"
        ]

        // Calculate trigger time: class start - travel time
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: lesson.startTime)

        var dateComponents = DateComponents()
        dateComponents.weekday = day.rawValue
        dateComponents.hour = startComponents.hour
        dateComponents.minute = (startComponents.minute ?? 0) - travelTimeMinutes

        // Handle negative minutes
        if let minute = dateComponents.minute, minute < 0 {
            dateComponents.minute = 60 + minute
            dateComponents.hour = (dateComponents.hour ?? 0) - 1

            if let hour = dateComponents.hour, hour < 0 {
                dateComponents.hour = 23
                dateComponents.weekday = (day.rawValue - 1 == 0) ? 7 : day.rawValue - 1
            }
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let identifier = leaveNowIdentifier(for: lesson, on: day)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule leave now notification: \(error.localizedDescription)")
            }
        }
    }

    func cancelLeaveNowNotifications() {
        notificationCenter.getPendingNotificationRequests { requests in
            let leaveNowIds = requests
                .filter { $0.identifier.contains("-leaveNow-") }
                .map { $0.identifier }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: leaveNowIds)
        }
    }

    func cancelLeaveNowNotification(for lesson: Lesson) {
        let identifiers = DayOfWeek.allCases.map { leaveNowIdentifier(for: lesson, on: $0) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Helpers

    private func notificationIdentifier(for lesson: Lesson, on day: DayOfWeek) -> String {
        "\(lesson.id.uuidString)-\(day.rawValue)"
    }

    private func leaveNowIdentifier(for lesson: Lesson, on day: DayOfWeek) -> String {
        "\(lesson.id.uuidString)-leaveNow-\(day.rawValue)"
    }
}

// MARK: - Notification Actions
extension NotificationService {
    func registerNotificationCategories() {
        // Define actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_LESSON",
            title: "View Details",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )

        let navigateAction = UNNotificationAction(
            identifier: "NAVIGATE",
            title: "Get Directions",
            options: [.foreground]
        )

        // Define categories
        let lessonCategory = UNNotificationCategory(
            identifier: "LESSON_REMINDER",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let leaveNowCategory = UNNotificationCategory(
            identifier: "LEAVE_NOW",
            actions: [navigateAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([lessonCategory, leaveNowCategory])
    }
}

// MARK: - Notification Delegate Handler
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var onLessonTapped: ((UUID) -> Void)?

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is open
        completionHandler([.banner, .sound])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case "VIEW_LESSON", UNNotificationDefaultActionIdentifier:
            if let lessonIdString = userInfo["lessonId"] as? String,
               let lessonId = UUID(uuidString: lessonIdString) {
                onLessonTapped?(lessonId)
            }

        case "DISMISS":
            break

        default:
            break
        }

        completionHandler()
    }
}
