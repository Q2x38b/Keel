import WidgetKit
import SwiftUI

// MARK: - Session Progress Widget (Fitness-style stats widget)
struct ClassProgressWidget: Widget {
    let kind: String = "ClassProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClassProgressProvider()) { entry in
            ClassProgressWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Session Progress")
        .description("Shows your daily session progress with stats")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Provider
struct ClassProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClassProgressEntry {
        ClassProgressEntry(
            date: Date(),
            totalSessions: 5,
            completedSessions: 2,
            remainingSessions: 3,
            minutesInClass: 120,
            nextClassName: "Physics",
            nextClassIn: 25
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ClassProgressEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClassProgressEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.keel.scheduler") ?? UserDefaults.standard

        var totalSessions = 0
        var completedSessions = 0
        var minutesInClass = 0
        var nextClassName: String? = nil
        var nextClassIn: Int? = nil

        if let data = defaults.data(forKey: "todayScheduleWidget"),
           let classes = try? JSONDecoder().decode([ScheduleWidgetClass].self, from: data) {
            totalSessions = classes.count

            // Find active class index to determine completed count
            if let activeIndex = classes.firstIndex(where: { $0.isActive }) {
                completedSessions = activeIndex
                // Calculate approximate minutes in session based on completed classes
                // Assuming average 50 min per class
                minutesInClass = completedSessions * 50

                // Next class is after active
                if activeIndex + 1 < classes.count {
                    nextClassName = classes[activeIndex + 1].name
                }
            } else {
                // No active class - check if we have upcoming classes
                if let firstClass = classes.first {
                    nextClassName = firstClass.name
                }
            }
        }

        // Get next class time
        if let data = defaults.data(forKey: "nextClassWidget"),
           let classData = try? JSONDecoder().decode(WidgetClassData.self, from: data) {
            let interval = classData.startTime.timeIntervalSince(Date())
            if interval > 0 {
                nextClassIn = Int(interval / 60)
                nextClassName = classData.name
            }
        }

        let entry = ClassProgressEntry(
            date: Date(),
            totalSessions: totalSessions,
            completedSessions: completedSessions,
            remainingSessions: totalSessions - completedSessions,
            minutesInClass: minutesInClass,
            nextClassName: nextClassName,
            nextClassIn: nextClassIn
        )

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Entry
struct ClassProgressEntry: TimelineEntry {
    let date: Date
    let totalSessions: Int
    let completedSessions: Int
    let remainingSessions: Int
    let minutesInClass: Int
    let nextClassName: String?
    let nextClassIn: Int? // minutes
}

// MARK: - Widget View
struct ClassProgressWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: ClassProgressEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // Small widget - Bold remaining count like fitness widget
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Big number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(entry.remainingSessions)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Sessions")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
            }

            Text("remaining today,")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            // Stats row
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                Text("\(entry.completedSessions)")
                    .font(.system(size: 13, weight: .semibold))
                Text("done")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                if let nextIn = entry.nextClassIn, nextIn > 0 {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    Text("\(formatTime(nextIn))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    // Medium widget - Full stats display like fitness widget
    private var mediumView: some View {
        HStack(spacing: 0) {
            // Left side - Main stat
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(entry.remainingSessions)")
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Sessions left,")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }

                // Stats line
                HStack(spacing: 6) {
                    // Completed
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                    Text("\(entry.completedSessions)/\(entry.totalSessions)")
                        .font(.system(size: 14, weight: .semibold))
                    Text("completed,")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)

                    // Time in session
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("\(entry.minutesInClass)min")
                        .font(.system(size: 14, weight: .semibold))
                    Text("in session")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Next class
                if let nextName = entry.nextClassName, let nextIn = entry.nextClassIn, nextIn > 0 {
                    HStack(spacing: 4) {
                        Text("and")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                        Text(nextName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("in \(formatTime(nextIn))!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Text("and")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundStyle(.purple)
                        Text("done for today!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.purple)
                    }
                }
            }

            Spacer()

            // Right side - Circular progress (optional visual)
            if entry.totalSessions > 0 {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                        .frame(width: 50, height: 50)

                    Circle()
                        .trim(from: 0, to: CGFloat(entry.completedSessions) / CGFloat(entry.totalSessions))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(Double(entry.completedSessions) / Double(entry.totalSessions) * 100))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text("%")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    private func formatTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Previews
#Preview(as: .systemSmall) {
    ClassProgressWidget()
} timeline: {
    ClassProgressEntry(
        date: Date(),
        totalSessions: 5,
        completedSessions: 2,
        remainingSessions: 3,
        minutesInClass: 100,
        nextClassName: "Physics",
        nextClassIn: 25
    )
}

#Preview(as: .systemMedium) {
    ClassProgressWidget()
} timeline: {
    ClassProgressEntry(
        date: Date(),
        totalSessions: 5,
        completedSessions: 2,
        remainingSessions: 3,
        minutesInClass: 100,
        nextClassName: "Biology Lab",
        nextClassIn: 45
    )
}

#Preview("All Done", as: .systemSmall) {
    ClassProgressWidget()
} timeline: {
    ClassProgressEntry(
        date: Date(),
        totalSessions: 4,
        completedSessions: 4,
        remainingSessions: 0,
        minutesInClass: 200,
        nextClassName: nil,
        nextClassIn: nil
    )
}
