import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Next Session Control
@available(iOS 18.0, *)
struct NextClassControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.keel.nextclass") {
            ControlWidgetButton(action: OpenAppIntent()) {
                Label {
                    Text(nextClassName)
                    Text(nextClassTime)
                } icon: {
                    Image(systemName: nextClassIcon)
                }
            }
        }
        .displayName("Next Session")
        .description("Shows your next upcoming session")
    }

    private var nextClassName: String {
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard
        if let data = defaults.data(forKey: "nextClassWidget"),
           let classData = try? JSONDecoder().decode(WidgetClassData.self, from: data) {
            return classData.name
        }
        return "No Session"
    }

    private var nextClassTime: String {
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard
        if let data = defaults.data(forKey: "nextClassWidget"),
           let classData = try? JSONDecoder().decode(WidgetClassData.self, from: data) {
            let interval = classData.startTime.timeIntervalSince(Date())
            if interval <= 0 { return "Now" }
            let minutes = Int(interval / 60)
            if minutes >= 60 {
                return "\(minutes / 60)h \(minutes % 60)m"
            }
            return "in \(minutes)m"
        }
        return ""
    }

    private var nextClassIcon: String {
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard
        if let data = defaults.data(forKey: "nextClassWidget"),
           let classData = try? JSONDecoder().decode(WidgetClassData.self, from: data) {
            return classData.iconName
        }
        return "book.fill"
    }
}

// MARK: - Class Count Control
@available(iOS 18.0, *)
struct ClassCountControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.keel.classcount") {
            ControlWidgetButton(action: OpenAppIntent()) {
                Label {
                    Text("\(classCount) Sessions")
                    Text("Today")
                } icon: {
                    Image(systemName: "calendar")
                }
            }
        }
        .displayName("Today's Sessions")
        .description("Shows how many sessions you have today")
    }

    private var classCount: Int {
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard
        if let data = defaults.data(forKey: "todayScheduleWidget"),
           let classes = try? JSONDecoder().decode([ScheduleWidgetClass].self, from: data) {
            return classes.count
        }
        return 0
    }
}

// MARK: - Study Timer Control
@available(iOS 18.0, *)
struct StudyTimerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.keel.studytimer") {
            ControlWidgetButton(action: OpenStudyTimerIntent()) {
                Label {
                    Text("Study Timer")
                    Text("Start Focus")
                } icon: {
                    Image(systemName: "timer")
                }
            }
        }
        .displayName("Study Timer")
        .description("Quick access to the Pomodoro timer")
    }
}

// MARK: - Quick Schedule Control
@available(iOS 18.0, *)
struct QuickScheduleControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.keel.schedule") {
            ControlWidgetButton(action: OpenAppIntent()) {
                Label {
                    Text(currentStatus)
                    Text(statusDetail)
                } icon: {
                    Image(systemName: statusIcon)
                }
            }
        }
        .displayName("Session Status")
        .description("Shows if you're in a session or free")
    }

    private var currentStatus: String {
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard
        if let data = defaults.data(forKey: "todayScheduleWidget"),
           let classes = try? JSONDecoder().decode([ScheduleWidgetClass].self, from: data) {
            if let active = classes.first(where: { $0.isActive }) {
                return active.name
            }
            return "Free Time"
        }
        return "No Sessiones"
    }

    private var statusDetail: String {
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard
        if let data = defaults.data(forKey: "todayScheduleWidget"),
           let classes = try? JSONDecoder().decode([ScheduleWidgetClass].self, from: data) {
            if classes.first(where: { $0.isActive }) != nil {
                return "In Progress"
            }
            if let next = classes.first {
                return "Next: \(next.name)"
            }
        }
        return "Enjoy!"
    }

    private var statusIcon: String {
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard
        if let data = defaults.data(forKey: "todayScheduleWidget"),
           let classes = try? JSONDecoder().decode([ScheduleWidgetClass].self, from: data) {
            if classes.first(where: { $0.isActive }) != nil {
                return "arrow.up.right.circle.fill"
            }
        }
        return "checkmark.circle.fill"
    }
}

// MARK: - App Intents for Controls
struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Keel"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct OpenStudyTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Study Timer"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Set a flag to open study timer
        UserDefaults.standard.set(true, forKey: "openStudyTimer")
        return .result()
    }
}

// Data models are in WidgetModels.swift
