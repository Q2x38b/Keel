import WidgetKit
import SwiftUI

// MARK: - Next Session Widget
struct NextClassWidget: Widget {
    let kind: String = "NextClassWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextClassProvider()) { entry in
            NextClassWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Session")
        .description("Shows your next upcoming session")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Provider
struct NextClassProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextClassEntry {
        NextClassEntry(
            date: Date(),
            className: "Physics",
            room: "Room A-32",
            startTime: Date().addingTimeInterval(1800),
            colorHex: "#007AFF",
            iconName: "atom"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextClassEntry) -> Void) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextClassEntry>) -> Void) {
        // Try to load from shared UserDefaults
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard

        if let data = defaults.data(forKey: "nextClassWidget"),
           let widgetData = try? JSONDecoder().decode(WidgetClassData.self, from: data) {
            let entry = NextClassEntry(
                date: Date(),
                className: widgetData.name,
                room: widgetData.room,
                startTime: widgetData.startTime,
                colorHex: widgetData.colorHex,
                iconName: widgetData.iconName
            )

            // Refresh every 5 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        } else {
            // No class data - show placeholder
            let entry = NextClassEntry(
                date: Date(),
                className: nil,
                room: nil,
                startTime: nil,
                colorHex: nil,
                iconName: nil
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Entry
struct NextClassEntry: TimelineEntry {
    let date: Date
    let className: String?
    let room: String?
    let startTime: Date?
    let colorHex: String?
    let iconName: String?

    var timeUntilStart: String? {
        guard let start = startTime else { return nil }
        let interval = start.timeIntervalSince(Date())
        if interval < 0 { return "Now" }

        let minutes = Int(interval / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Widget View
struct NextClassWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: NextClassEntry

    var body: some View {
        if let className = entry.className {
            switch family {
            case .systemSmall:
                smallView(className: className)
            case .systemMedium:
                mediumView(className: className)
            default:
                smallView(className: className)
            }
        } else {
            noClassView
        }
    }

    private func smallView(className: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let iconName = entry.iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.fromHex(entry.colorHex ?? "#007AFF"))
                }
                Text("NEXT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(className)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            if let room = entry.room {
                Text(room)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let time = entry.timeUntilStart {
                Text(time)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fromHex(entry.colorHex ?? "#007AFF"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    private func mediumView(className: String) -> some View {
        HStack(spacing: 16) {
            // Left side - Class info
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    if let iconName = entry.iconName {
                        Image(systemName: iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.fromHex(entry.colorHex ?? "#007AFF"))
                    }
                    Text("UP NEXT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                Text(className)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let room = entry.room {
                    HStack(spacing: 4) {
                        Image(systemName: "door.left.hand.open")
                            .font(.system(size: 11))
                        Text(room)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Right side - Time
            VStack(alignment: .trailing, spacing: 4) {
                if let time = entry.timeUntilStart {
                    Text(time)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fromHex(entry.colorHex ?? "#007AFF"))

                    Text("until start")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noClassView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)

            Text("No Upcoming Sessions")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview(as: .systemSmall) {
    NextClassWidget()
} timeline: {
    NextClassEntry(
        date: Date(),
        className: "Physics",
        room: "Room A-32",
        startTime: Date().addingTimeInterval(1800),
        colorHex: "#007AFF",
        iconName: "atom"
    )
}

#Preview(as: .systemMedium) {
    NextClassWidget()
} timeline: {
    NextClassEntry(
        date: Date(),
        className: "Biology Lab",
        room: "Science Building B-15",
        startTime: Date().addingTimeInterval(2700),
        colorHex: "#34C759",
        iconName: "leaf.fill"
    )
}
