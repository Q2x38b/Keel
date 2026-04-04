import WidgetKit
import SwiftUI

// MARK: - Countdown Widget
struct CountdownWidget: Widget {
    let kind: String = "CountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CountdownProvider()) { entry in
            CountdownWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Session Countdown")
        .description("Countdown timer to your next session")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Provider
struct CountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(
            date: Date(),
            className: "Physics",
            room: "A-32",
            startTime: Date().addingTimeInterval(3600),
            colorHex: "#007AFF",
            iconName: "atom",
            isEmpty: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> Void) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard

        if let data = defaults.data(forKey: "nextClassWidget"),
           let classData = try? JSONDecoder().decode(WidgetClassData.self, from: data) {

            let entry = CountdownEntry(
                date: Date(),
                className: classData.name,
                room: classData.room,
                startTime: classData.startTime,
                colorHex: classData.colorHex,
                iconName: classData.iconName,
                isEmpty: false
            )

            // Update every minute for accurate countdown
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        } else {
            let entry = CountdownEntry(
                date: Date(),
                className: "",
                room: "",
                startTime: Date(),
                colorHex: "#007AFF",
                iconName: "book.fill",
                isEmpty: true
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Entry
struct CountdownEntry: TimelineEntry {
    let date: Date
    let className: String
    let room: String
    let startTime: Date
    let colorHex: String
    let iconName: String
    let isEmpty: Bool

    var timeUntilStart: TimeInterval {
        startTime.timeIntervalSince(Date())
    }

    var isStarted: Bool {
        timeUntilStart <= 0
    }
}

// MARK: - Widget View
struct CountdownWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: CountdownEntry

    var body: some View {
        if entry.isEmpty {
            noClassView
        } else if entry.isStarted {
            inProgressView
        } else {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            default:
                smallView
            }
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.fromHex(entry.colorHex).opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: entry.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.fromHex(entry.colorHex))
            }

            // Class name
            Text(entry.className)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Countdown
            VStack(spacing: 2) {
                Text(countdownText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fromHex(entry.colorHex))
                    .contentTransition(.numericText())

                Text(countdownUnit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left side - Icon and info
            VStack(alignment: .leading, spacing: 8) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.fromHex(entry.colorHex).opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: entry.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.fromHex(entry.colorHex))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.className)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "door.left.hand.open")
                            .font(.system(size: 9, weight: .medium))
                        Text(entry.room)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9, weight: .medium))
                        Text(formattedStartTime)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Right side - Countdown
            VStack(spacing: 4) {
                Text("STARTS IN")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                Text(countdownText)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fromHex(entry.colorHex))
                    .contentTransition(.numericText())

                Text(countdownUnit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 90)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    private var inProgressView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text(entry.className)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)

            Text("In Progress")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noClassView: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 32))
                .foregroundStyle(.purple)

            Text("All Done!")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Text("No more sessions today")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var countdownText: String {
        let totalSeconds = Int(max(0, entry.timeUntilStart))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes))"
        } else {
            return "\(minutes)"
        }
    }

    private var countdownUnit: String {
        let totalSeconds = Int(max(0, entry.timeUntilStart))
        let hours = totalSeconds / 3600

        if hours > 0 {
            return "hours"
        } else {
            return "minutes"
        }
    }

    private var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: entry.startTime)
    }
}

#Preview(as: .systemSmall) {
    CountdownWidget()
} timeline: {
    CountdownEntry(
        date: Date(),
        className: "Physics",
        room: "A-32",
        startTime: Date().addingTimeInterval(2700),
        colorHex: "#007AFF",
        iconName: "atom",
        isEmpty: false
    )
}

#Preview(as: .systemMedium) {
    CountdownWidget()
} timeline: {
    CountdownEntry(
        date: Date(),
        className: "Biology Lab",
        room: "Science B-15",
        startTime: Date().addingTimeInterval(5400),
        colorHex: "#34C759",
        iconName: "leaf.fill",
        isEmpty: false
    )
}

#Preview("No Classes", as: .systemSmall) {
    CountdownWidget()
} timeline: {
    CountdownEntry(
        date: Date(),
        className: "",
        room: "",
        startTime: Date(),
        colorHex: "#007AFF",
        iconName: "book.fill",
        isEmpty: true
    )
}
