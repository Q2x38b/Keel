import AppIntents
import SwiftUI

// MARK: - App Shortcuts Provider
struct KeelShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextClassIntent(),
            phrases: [
                "What's my next session in \(.applicationName)",
                "Show my next session in \(.applicationName)",
                "What session do I have next in \(.applicationName)",
                "Next session in \(.applicationName)"
            ],
            shortTitle: "Next Session",
            systemImageName: "book.fill"
        )

        AppShortcut(
            intent: TodayScheduleIntent(),
            phrases: [
                "What's my schedule today in \(.applicationName)",
                "What sessions do I have today in \(.applicationName)",
                "Show my schedule in \(.applicationName)",
                "Today's sessions in \(.applicationName)"
            ],
            shortTitle: "Today's Schedule",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: CurrentClassIntent(),
            phrases: [
                "What session am I in right now in \(.applicationName)",
                "What's my current session in \(.applicationName)",
                "Am I in a session right now in \(.applicationName)",
                "Current session in \(.applicationName)"
            ],
            shortTitle: "Current Session",
            systemImageName: "arrow.up.right.circle.fill"
        )
    }
}

// MARK: - Next Session Intent
struct NextClassIntent: AppIntent {
    static var title: LocalizedStringResource = "What's My Next Session"
    static var description = IntentDescription("Find out what your next session is and when it starts")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let nextClass = await MainActor.run {
            ScheduleDataProvider.shared.nextClass
        }

        guard let nextClass = nextClass else {
            return .result(
                dialog: "You don't have any more sessions scheduled for today.",
                view: NoSessionView(message: "No More Sessions Today")
            )
        }

        let timeText = formatTimeUntil(nextClass.startsIn)

        return .result(
            dialog: "Your next session is \(nextClass.lesson.name) in \(nextClass.lesson.room), starting \(timeText).",
            view: NextClassSnippetView(lesson: nextClass.lesson, startsIn: nextClass.startsIn)
        )
    }

    private func formatTimeUntil(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "in \(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let hours = minutes / 60
            let remainingMins = minutes % 60
            if remainingMins == 0 {
                return "in \(hours) hour\(hours == 1 ? "" : "s")"
            }
            return "in \(hours) hour\(hours == 1 ? "" : "s") and \(remainingMins) minute\(remainingMins == 1 ? "" : "s")"
        }
    }
}

// MARK: - When Does Session End Intent
struct WhenDoesClassEndIntent: AppIntent {
    static var title: LocalizedStringResource = "When Does Session End"
    static var description = IntentDescription("Find out when a specific session ends")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Session Name")
    var className: String

    static var parameterSummary: some ParameterSummary {
        Summary("When does \(\.$className) end")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let searchTerm = className.lowercased()

        let (lesson, todayLessons) = await MainActor.run {
            let data = ScheduleDataProvider.shared
            let foundLesson = data.lessons.first(where: {
                $0.name.lowercased().contains(searchTerm) || searchTerm.contains($0.name.lowercased())
            })
            return (foundLesson, data.todayLessons)
        }

        // Find matching session (case-insensitive partial match)
        guard let lesson = lesson else {
            return .result(dialog: "I couldn't find a session called \(className) in your schedule.")
        }

        // Check if this session is scheduled today
        let isScheduledToday = todayLessons.contains { $0.lessonId == lesson.id }

        guard isScheduledToday else {
            return .result(dialog: "\(lesson.name) is not scheduled for today.")
        }

        // Check if session is currently in progress
        let now = Date()
        let calendar = Calendar.current
        let endComponents = calendar.dateComponents([.hour, .minute], from: lesson.endTime)
        var todayEnd = calendar.dateComponents([.year, .month, .day], from: now)
        todayEnd.hour = endComponents.hour
        todayEnd.minute = endComponents.minute

        guard let endTime = calendar.date(from: todayEnd) else {
            return .result(dialog: "I couldn't determine when \(lesson.name) ends.")
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let endTimeString = formatter.string(from: endTime)

        if now > endTime {
            return .result(dialog: "\(lesson.name) has already ended today. It finished at \(endTimeString).")
        }

        let timeRemaining = endTime.timeIntervalSince(now)
        let minutesRemaining = Int(timeRemaining / 60)

        if minutesRemaining < 60 {
            return .result(dialog: "\(lesson.name) ends at \(endTimeString), which is in \(minutesRemaining) minute\(minutesRemaining == 1 ? "" : "s").")
        } else {
            let hours = minutesRemaining / 60
            let mins = minutesRemaining % 60
            if mins == 0 {
                return .result(dialog: "\(lesson.name) ends at \(endTimeString), which is in \(hours) hour\(hours == 1 ? "" : "s").")
            }
            return .result(dialog: "\(lesson.name) ends at \(endTimeString), which is in \(hours) hour\(hours == 1 ? "" : "s") and \(mins) minute\(mins == 1 ? "" : "s").")
        }
    }
}

// MARK: - Today's Schedule Intent
struct TodayScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Schedule"
    static var description = IntentDescription("Get your complete schedule for today")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let (todayLessons, lessons) = await MainActor.run {
            let data = ScheduleDataProvider.shared
            return (data.todayLessons, data.lessons)
        }

        guard !todayLessons.isEmpty else {
            return .result(
                dialog: "You don't have any sessions scheduled for today.",
                view: NoSessionView(message: "No Sessions Today")
            )
        }

        // Build list of sessions
        let sessionNames = todayLessons.compactMap { scheduled -> String? in
            lessons.first(where: { $0.id == scheduled.lessonId })?.name
        }

        let sessionListText = sessionNames.joined(separator: ", ")

        return .result(
            dialog: "You have \(todayLessons.count) session\(todayLessons.count == 1 ? "" : "s") today: \(sessionListText).",
            view: TodayScheduleSnippetView(
                lessons: todayLessons.compactMap { scheduled in
                    lessons.first(where: { $0.id == scheduled.lessonId })
                }
            )
        )
    }
}

// MARK: - Current Session Intent
struct CurrentClassIntent: AppIntent {
    static var title: LocalizedStringResource = "Current Session"
    static var description = IntentDescription("Find out what session you're currently in")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let (currentClass, nextClass) = await MainActor.run {
            let data = ScheduleDataProvider.shared
            return (data.currentClass, data.nextClass)
        }

        guard let currentClass = currentClass else {
            // Check if there's a next session
            if let nextClass = nextClass {
                let timeText = formatTimeUntil(nextClass.startsIn)
                return .result(
                    dialog: "You're not in a session right now. Your next session is \(nextClass.lesson.name), starting \(timeText).",
                    view: NoSessionView(message: "Not In Session")
                )
            }
            return .result(
                dialog: "You're not in a session right now, and you don't have any more sessions today.",
                view: NoSessionView(message: "Not In Session")
            )
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let endTimeString = formatter.string(from: currentClass.endTime)

        return .result(
            dialog: "You're currently in \(currentClass.name) in \(currentClass.room). It ends at \(endTimeString).",
            view: CurrentClassSnippetView(lesson: currentClass)
        )
    }

    private func formatTimeUntil(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "in \(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let hours = minutes / 60
            let remainingMins = minutes % 60
            if remainingMins == 0 {
                return "in \(hours) hour\(hours == 1 ? "" : "s")"
            }
            return "in \(hours) hour\(hours == 1 ? "" : "s") and \(remainingMins) minute\(remainingMins == 1 ? "" : "s")"
        }
    }
}

// MARK: - Schedule Data Provider
@MainActor
class ScheduleDataProvider {
    static let shared = ScheduleDataProvider()

    private let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard

    var lessons: [IntentLesson] {
        guard let data = defaults.data(forKey: "intentLessons"),
              let lessons = try? JSONDecoder().decode([IntentLesson].self, from: data) else {
            return []
        }
        return lessons
    }

    var todayLessons: [IntentScheduledLesson] {
        guard let data = defaults.data(forKey: "intentTodaySchedule"),
              let scheduled = try? JSONDecoder().decode([IntentScheduledLesson].self, from: data) else {
            return []
        }
        return scheduled
    }

    var nextClass: (lesson: IntentLesson, startsIn: TimeInterval)? {
        let now = Date()
        let calendar = Calendar.current

        for scheduled in todayLessons {
            guard let lesson = lessons.first(where: { $0.id == scheduled.lessonId }) else { continue }

            let startComponents = calendar.dateComponents([.hour, .minute], from: lesson.startTime)
            var todayStart = calendar.dateComponents([.year, .month, .day], from: now)
            todayStart.hour = startComponents.hour
            todayStart.minute = startComponents.minute

            guard let startTime = calendar.date(from: todayStart), now < startTime else { continue }
            return (lesson, startTime.timeIntervalSince(now))
        }
        return nil
    }

    var currentClass: IntentLesson? {
        let now = Date()
        let calendar = Calendar.current

        for scheduled in todayLessons {
            guard let lesson = lessons.first(where: { $0.id == scheduled.lessonId }) else { continue }

            let startComponents = calendar.dateComponents([.hour, .minute], from: lesson.startTime)
            let endComponents = calendar.dateComponents([.hour, .minute], from: lesson.endTime)

            var todayStart = calendar.dateComponents([.year, .month, .day], from: now)
            todayStart.hour = startComponents.hour
            todayStart.minute = startComponents.minute

            var todayEnd = calendar.dateComponents([.year, .month, .day], from: now)
            todayEnd.hour = endComponents.hour
            todayEnd.minute = endComponents.minute

            guard let startTime = calendar.date(from: todayStart),
                  let endTime = calendar.date(from: todayEnd),
                  now >= startTime && now <= endTime else { continue }

            // Create a copy with today's end time
            var currentLesson = lesson
            currentLesson.endTime = endTime
            return currentLesson
        }
        return nil
    }
}

// MARK: - Snippet Views
struct NextClassSnippetView: View {
    let lesson: IntentLesson
    let startsIn: TimeInterval

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.fromHex(lesson.colorHex).opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: lesson.iconSystemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.fromHex(lesson.colorHex))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.name)
                    .font(.system(size: 16, weight: .bold))

                HStack(spacing: 6) {
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 10))
                    Text(lesson.room)
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(startsIn))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fromHex(lesson.colorHex))

                Text("until start")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins == 0 ? "\(hours)h" : "\(hours):\(String(format: "%02d", mins))"
        }
        return "\(minutes)m"
    }
}

struct CurrentClassSnippetView: View {
    let lesson: IntentLesson

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.fromHex(lesson.colorHex).opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: lesson.iconSystemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.fromHex(lesson.colorHex))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                    Text("IN SESSION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                }

                Text(lesson.name)
                    .font(.system(size: 16, weight: .bold))

                HStack(spacing: 6) {
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 10))
                    Text(lesson.room)
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatEndTime)
                    .font(.system(size: 16, weight: .semibold))

                Text("ends at")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var formatEndTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: lesson.endTime)
    }
}

struct TodayScheduleSnippetView: View {
    let lessons: [IntentLesson]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lessons.prefix(4)) { lesson in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.fromHex(lesson.colorHex))
                        .frame(width: 3, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lesson.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        Text(formatTime(lesson.startTime))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(lesson.room)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            if lessons.count > 4 {
                Text("+\(lessons.count - 4) more")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct NoSessionView: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green)

            Text(message)
                .font(.system(size: 14, weight: .medium))
        }
        .padding()
    }
}

// MARK: - Color Extension for Intents
extension Color {
    static func fromHex(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        return Color(red: r, green: g, blue: b)
    }
}
