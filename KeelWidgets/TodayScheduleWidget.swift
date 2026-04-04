import WidgetKit
import SwiftUI

// MARK: - Today Schedule Widget
struct TodayScheduleWidget: Widget {
    let kind: String = "TodayScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayScheduleProvider()) { entry in
            TodayScheduleWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Schedule")
        .description("Shows all your sessions for today")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Provider
struct TodayScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayScheduleEntry {
        TodayScheduleEntry(
            date: Date(),
            sessions: [
                ScheduleWidgetClass(name: "Physics", room: "A-32", startTime: "9:00 AM", endTime: "10:00 AM", colorHex: "#007AFF", iconName: "atom", isActive: true),
                ScheduleWidgetClass(name: "Biology", room: "B-15", startTime: "11:00 AM", endTime: "12:00 PM", colorHex: "#34C759", iconName: "leaf.fill", isActive: false),
                ScheduleWidgetClass(name: "Math", room: "C-20", startTime: "1:00 PM", endTime: "2:00 PM", colorHex: "#FF9500", iconName: "function", isActive: false)
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayScheduleEntry) -> Void) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayScheduleEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard

        if let data = defaults.data(forKey: "todayScheduleWidget"),
           let sessions = try? JSONDecoder().decode([ScheduleWidgetClass].self, from: data) {
            let entry = TodayScheduleEntry(date: Date(), sessions: sessions)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        } else {
            let entry = TodayScheduleEntry(date: Date(), sessions: [])
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Entry
struct TodayScheduleEntry: TimelineEntry {
    let date: Date
    let sessions: [ScheduleWidgetClass]
}

// MARK: - Widget View
struct TodayScheduleWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: TodayScheduleEntry

    var body: some View {
        if entry.sessions.isEmpty {
            noClassesView
        } else {
            switch family {
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView
            default:
                mediumView
            }
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(dayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(entry.sessions.count) sessions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Class list (show up to 3)
            ForEach(entry.sessions.prefix(3)) { classItem in
                classRow(classItem)
            }

            if entry.sessions.count > 3 {
                Text("+\(entry.sessions.count - 3) more")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(dateString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.sessions.count)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("sessions")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 4)

            Divider()

            // Class list
            ForEach(entry.sessions) { classItem in
                classRowLarge(classItem)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }

    private func classRow(_ classItem: ScheduleWidgetClass) -> some View {
        HStack(spacing: 10) {
            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.fromHex(classItem.colorHex))
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(classItem.name)
                    .font(.system(size: 13, weight: classItem.isActive ? .bold : .medium))
                    .foregroundStyle(classItem.isActive ? Color.fromHex(classItem.colorHex) : .primary)
                    .lineLimit(1)

                Text(classItem.startTime)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if classItem.isActive {
                Text("NOW")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green)
                    .clipShape(Capsule())
            }
        }
    }

    private func classRowLarge(_ classItem: ScheduleWidgetClass) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: classItem.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.fromHex(classItem.colorHex))
                .frame(width: 28, height: 28)
                .background(Color.fromHex(classItem.colorHex).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(classItem.name)
                    .font(.system(size: 14, weight: classItem.isActive ? .bold : .medium))
                    .foregroundStyle(classItem.isActive ? Color.fromHex(classItem.colorHex) : .primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(classItem.room)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("\(classItem.startTime) - \(classItem.endTime)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if classItem.isActive {
                Text("NOW")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var noClassesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 32))
                .foregroundStyle(.green)

            Text("No Sessions Today")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Enjoy your day off!")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date())
    }
}

#Preview(as: .systemMedium) {
    TodayScheduleWidget()
} timeline: {
    TodayScheduleEntry(
        date: Date(),
        sessions: [
            ScheduleWidgetClass(name: "Physics", room: "A-32", startTime: "9:00 AM", endTime: "10:00 AM", colorHex: "#007AFF", iconName: "atom", isActive: true),
            ScheduleWidgetClass(name: "Biology", room: "B-15", startTime: "11:00 AM", endTime: "12:00 PM", colorHex: "#34C759", iconName: "leaf.fill", isActive: false),
            ScheduleWidgetClass(name: "Math", room: "C-20", startTime: "1:00 PM", endTime: "2:00 PM", colorHex: "#FF9500", iconName: "function", isActive: false)
        ]
    )
}

#Preview(as: .systemLarge) {
    TodayScheduleWidget()
} timeline: {
    TodayScheduleEntry(
        date: Date(),
        sessions: [
            ScheduleWidgetClass(name: "Physics Lab", room: "Science A-32", startTime: "9:00 AM", endTime: "10:30 AM", colorHex: "#007AFF", iconName: "atom", isActive: true),
            ScheduleWidgetClass(name: "Biology", room: "Life Sciences B-15", startTime: "11:00 AM", endTime: "12:00 PM", colorHex: "#34C759", iconName: "leaf.fill", isActive: false),
            ScheduleWidgetClass(name: "Calculus II", room: "Math Building C-20", startTime: "1:00 PM", endTime: "2:00 PM", colorHex: "#FF9500", iconName: "function", isActive: false),
            ScheduleWidgetClass(name: "History", room: "Humanities D-10", startTime: "3:00 PM", endTime: "4:00 PM", colorHex: "#AF52DE", iconName: "building.columns.fill", isActive: false)
        ]
    )
}
