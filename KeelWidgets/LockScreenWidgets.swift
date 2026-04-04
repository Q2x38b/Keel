import WidgetKit
import SwiftUI

// MARK: - Lock Screen Next Session Widget
struct LockScreenNextClassWidget: Widget {
    let kind: String = "LockScreenNextClassWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenNextClassProvider()) { entry in
            LockScreenNextClassView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Next Session")
        .description("Shows your next session on the lock screen")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Provider
struct LockScreenNextClassProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenNextClassEntry {
        LockScreenNextClassEntry(
            date: Date(),
            className: "Physics",
            room: "A-32",
            startTime: Date().addingTimeInterval(1800),
            iconName: "atom",
            isEmpty: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenNextClassEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenNextClassEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard

        if let data = defaults.data(forKey: "nextClassWidget"),
           let classData = try? JSONDecoder().decode(WidgetClassData.self, from: data) {
            let entry = LockScreenNextClassEntry(
                date: Date(),
                className: classData.name,
                room: classData.room,
                startTime: classData.startTime,
                iconName: classData.iconName,
                isEmpty: false
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        } else {
            let entry = LockScreenNextClassEntry(
                date: Date(),
                className: nil,
                room: nil,
                startTime: nil,
                iconName: nil,
                isEmpty: true
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
}

// MARK: - Entry
struct LockScreenNextClassEntry: TimelineEntry {
    let date: Date
    let className: String?
    let room: String?
    let startTime: Date?
    let iconName: String?
    let isEmpty: Bool

    var timeUntilStart: String {
        guard let start = startTime else { return "--" }
        let interval = start.timeIntervalSince(Date())
        if interval <= 0 { return "Now" }

        let minutes = Int(interval / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins == 0 ? "\(hours)h" : "\(hours):\(String(format: "%02d", mins))"
        }
        return "\(minutes)m"
    }
}

// MARK: - Views
struct LockScreenNextClassView: View {
    @Environment(\.widgetFamily) var family
    var entry: LockScreenNextClassEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            if entry.isEmpty {
                AccessoryWidgetBackground()
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .semibold))
            } else {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: entry.iconName ?? "book.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(entry.timeUntilStart)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
            }
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            if entry.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                Text("No more sessions")
                    .font(.system(size: 13, weight: .medium))
            } else {
                Image(systemName: entry.iconName ?? "book.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.className ?? "Class")
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(entry.room ?? "")
                            .font(.system(size: 11, weight: .medium))
                        Text("•")
                            .font(.system(size: 11))
                        Text(entry.timeUntilStart)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var inlineView: some View {
        if entry.isEmpty {
            Label("No sessions", systemImage: "checkmark.circle")
        } else {
            Label("\(entry.className ?? "Class") in \(entry.timeUntilStart)", systemImage: entry.iconName ?? "book.fill")
        }
    }
}

// MARK: - Lock Screen Schedule Widget
struct LockScreenScheduleWidget: Widget {
    let kind: String = "LockScreenScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenScheduleProvider()) { entry in
            LockScreenScheduleView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Today's Sessions")
        .description("Shows session count on lock screen")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Provider
struct LockScreenScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenScheduleEntry {
        LockScreenScheduleEntry(date: Date(), classCount: 4, nextClassName: "Physics", completedCount: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenScheduleEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenScheduleEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard

        var classCount = 0
        var nextClassName: String?
        var completedCount = 0

        if let data = defaults.data(forKey: "todayScheduleWidget"),
           let classes = try? JSONDecoder().decode([ScheduleWidgetClass].self, from: data) {
            classCount = classes.count

            // Find next session (first non-active one)
            if let activeIndex = classes.firstIndex(where: { $0.isActive }) {
                completedCount = activeIndex
                if activeIndex + 1 < classes.count {
                    nextClassName = classes[activeIndex + 1].name
                }
            } else {
                // No active class, find first one that hasn't started
                nextClassName = classes.first?.name
            }
        }

        let entry = LockScreenScheduleEntry(
            date: Date(),
            classCount: classCount,
            nextClassName: nextClassName,
            completedCount: completedCount
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Entry
struct LockScreenScheduleEntry: TimelineEntry {
    let date: Date
    let classCount: Int
    let nextClassName: String?
    let completedCount: Int

    var remainingCount: Int {
        classCount - completedCount
    }
}

// MARK: - Views
struct LockScreenScheduleView: View {
    @Environment(\.widgetFamily) var family
    var entry: LockScreenScheduleEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(entry.remainingCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(entry.classCount) sessions today")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(entry.completedCount)/\(entry.classCount)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.secondary.opacity(0.3))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(.primary)
                        .frame(width: entry.classCount > 0 ? geo.size.width * CGFloat(entry.completedCount) / CGFloat(entry.classCount) : 0)
                }
            }
            .frame(height: 4)

            if let next = entry.nextClassName {
                Text("Next: \(next)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Previews
#Preview("Circular", as: .accessoryCircular) {
    LockScreenNextClassWidget()
} timeline: {
    LockScreenNextClassEntry(date: Date(), className: "Physics", room: "A-32", startTime: Date().addingTimeInterval(1800), iconName: "atom", isEmpty: false)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    LockScreenNextClassWidget()
} timeline: {
    LockScreenNextClassEntry(date: Date(), className: "Physics Lab", room: "Science A-32", startTime: Date().addingTimeInterval(2700), iconName: "atom", isEmpty: false)
}

#Preview("Inline", as: .accessoryInline) {
    LockScreenNextClassWidget()
} timeline: {
    LockScreenNextClassEntry(date: Date(), className: "Physics", room: "A-32", startTime: Date().addingTimeInterval(1800), iconName: "atom", isEmpty: false)
}

#Preview("Schedule Circular", as: .accessoryCircular) {
    LockScreenScheduleWidget()
} timeline: {
    LockScreenScheduleEntry(date: Date(), classCount: 5, nextClassName: "Biology", completedCount: 2)
}

#Preview("Schedule Rectangular", as: .accessoryRectangular) {
    LockScreenScheduleWidget()
} timeline: {
    LockScreenScheduleEntry(date: Date(), classCount: 5, nextClassName: "Biology", completedCount: 2)
}
