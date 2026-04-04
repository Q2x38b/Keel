import ActivityKit
import WidgetKit
import SwiftUI

struct LessonLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LessonActivityAttributes.self) { context in
            // Lock screen / banner view - compact and sleek
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(.black.opacity(0.75))
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded View (shows on long-press)
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.isLive {
                        // IN SESSION layout - emphasize the lesson
                        VStack(alignment: .leading, spacing: 6) {
                            Spacer()

                            // Lesson name prominently
                            Text(context.state.lessonName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            // Room with icon
                            HStack(spacing: 4) {
                                Image(systemName: "door.left.hand.open")
                                    .font(.system(size: 10, weight: .medium))
                                Text(context.state.room)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.leading, 12)
                    } else {
                        // UP NEXT layout
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.walk.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("UP NEXT")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.yellow)

                            Text(context.state.lessonName)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            HStack(spacing: 4) {
                                Image(systemName: "door.left.hand.open")
                                    .font(.system(size: 9, weight: .medium))
                                Text(context.state.room)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.leading, 4)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isLive {
                        // IN SESSION - circular progress with time
                        VStack(alignment: .trailing, spacing: 2) {
                            ZStack {
                                // Background circle
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                                    .frame(width: 44, height: 44)

                                // Progress circle
                                Circle()
                                    .trim(from: 0, to: context.state.progress)
                                    .stroke(
                                        Color.fromHex(context.state.colorHex),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                    )
                                    .frame(width: 44, height: 44)
                                    .rotationEffect(.degrees(-90))

                                // Percentage text
                                Text("\(Int(context.state.progress * 100))%")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.trailing, 4)
                    } else {
                        // UP NEXT - time until start
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(compactTimeText(context.state.timeRemaining))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())

                            Text("until start")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.trailing, 4)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isLive {
                        // IN SESSION bottom - time remaining and end time
                        VStack(spacing: 6) {
                            // Time remaining prominently
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.fromHex(context.state.colorHex))

                                Text(compactTimeText(context.state.timeRemaining))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())

                                Text("remaining")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))

                                Spacer()

                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10, weight: .medium))
                                    Text("Ends \(formatTime(context.state.endTime))")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 12)

                            // Full width progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.15))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.fromHex(context.state.colorHex))
                                        .frame(width: geo.size.width * context.state.progress)
                                }
                            }
                            .frame(height: 5)
                            .padding(.horizontal, 12)
                        }
                        .padding(.top, 4)
                    } else {
                        // UP NEXT bottom - start time and travel times
                        HStack(spacing: 0) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10, weight: .medium))
                                Text("Starts \(formatTime(context.state.startTime))")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.7))

                            Spacer()

                            HStack(spacing: 10) {
                                if let walkingTime = context.state.walkingTimeMinutes {
                                    HStack(spacing: 3) {
                                        Image(systemName: "figure.walk")
                                            .font(.system(size: 10, weight: .medium))
                                        Text("\(walkingTime)m")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundStyle(.green)
                                }

                                if let drivingTime = context.state.travelTimeMinutes {
                                    HStack(spacing: 3) {
                                        Image(systemName: "car.fill")
                                            .font(.system(size: 10, weight: .medium))
                                        Text("\(drivingTime)m")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundStyle(.cyan)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    }
                }
            } compactLeading: {
                // MARK: - Compact Leading - Icon + time text
                HStack(spacing: 5) {
                    Image(systemName: context.state.isLive ? "arrow.up.right.circle.fill" : "figure.walk.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(context.state.isLive ? .green : .yellow)

                    Text(compactTimeText(context.state.timeRemaining))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(context.state.isLive ? .green : .yellow)
                        .contentTransition(.numericText())
                }
                .padding(.leading, 2)
            } compactTrailing: {
                // MARK: - Compact Trailing - Class icon
                Image(systemName: context.state.iconSystemName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(context.state.isLive ? .green : .yellow)
                    .padding(.trailing, 4)
            } minimal: {
                // MARK: - Minimal View - Just the lesson icon
                Image(systemName: context.state.iconSystemName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(context.state.isLive ? .green : .yellow)
            }
        }
    }

    // MARK: - Helper Functions

    private func compactTimeText(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(abs(interval) / 60)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours):\(String(format: "%02d", mins))"
        }
        return "\(totalMinutes)m"
    }

    private func miniTimeText(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(abs(interval) / 60)
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60)"
        }
        return "\(totalMinutes)"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Lock Screen View
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<LessonActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Left side - Lesson icon/thumbnail with color
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.fromHex(context.state.colorHex).opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: context.state.iconSystemName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.fromHex(context.state.colorHex))
            }

            // Middle - Lesson info
            VStack(alignment: .leading, spacing: 4) {
                // Status + Name row
                HStack(spacing: 6) {
                    Image(systemName: context.state.isLive ? "arrow.up.right.circle.fill" : "figure.walk.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(context.state.isLive ? .green : .yellow)

                    Text(context.state.lessonName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                // Details row
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "door.left.hand.open")
                            .font(.system(size: 9, weight: .medium))
                        Text(context.state.room)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.7))

                    // Show end time for live, or travel times for upcoming
                    if context.state.isLive {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9, weight: .medium))
                            Text("Ends \(formatTime(context.state.endTime))")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    } else {
                        // Walking time
                        if let walkingTime = context.state.walkingTimeMinutes {
                            HStack(spacing: 3) {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 9, weight: .medium))
                                Text("\(walkingTime)m")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.green)
                        }

                        // Driving time
                        if let drivingTime = context.state.travelTimeMinutes {
                            HStack(spacing: 3) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 9, weight: .medium))
                                Text("\(drivingTime)m")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.cyan)
                        }
                    }
                }
            }

            Spacer()

            // Right side - Time display
            VStack(alignment: .trailing, spacing: 2) {
                Text(centerTimeText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(context.state.isLive ? "left" : "to go")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                // Progress bar for live lessons
                if context.state.isLive {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.fromHex(context.state.colorHex))
                                .frame(width: geo.size.width * context.state.progress, height: 4)
                        }
                    }
                    .frame(width: 50, height: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var centerTimeText: String {
        let totalMinutes = Int(abs(context.state.timeRemaining) / 60)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours):\(String(format: "%02d", mins))"
        }
        return "\(totalMinutes)m"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Previews
#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: LessonActivityAttributes(locationName: "School", lessonId: "123")) {
    LessonLiveActivity()
} contentStates: {
    LessonActivityAttributes.ContentState(
        lessonName: "Physics",
        room: "A-32",
        building: nil,
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        colorHex: "#34C759",
        iconSystemName: "atom",
        isLive: true,
        progress: 0.55,
        timeRemaining: 1920,
        travelTimeMinutes: nil,
        walkingTimeMinutes: nil,
        distanceMeters: nil
    )
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: LessonActivityAttributes(locationName: "School", lessonId: "123")) {
    LessonLiveActivity()
} contentStates: {
    LessonActivityAttributes.ContentState(
        lessonName: "Physics",
        room: "Room A-32",
        building: "Science Building",
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        colorHex: "#007AFF",
        iconSystemName: "atom",
        isLive: true,
        progress: 0.4,
        timeRemaining: 2160,
        travelTimeMinutes: nil,
        walkingTimeMinutes: nil,
        distanceMeters: nil
    )
}

#Preview("Dynamic Island Expanded Upcoming", as: .dynamicIsland(.expanded), using: LessonActivityAttributes(locationName: "School", lessonId: "123")) {
    LessonLiveActivity()
} contentStates: {
    LessonActivityAttributes.ContentState(
        lessonName: "Biology",
        room: "Room B-15",
        building: "Life Sciences",
        startTime: Date().addingTimeInterval(900),
        endTime: Date().addingTimeInterval(4500),
        colorHex: "#34C759",
        iconSystemName: "leaf.fill",
        isLive: false,
        progress: 0,
        timeRemaining: 900,
        travelTimeMinutes: 8,
        walkingTimeMinutes: 18,
        distanceMeters: 2400
    )
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: LessonActivityAttributes(locationName: "School", lessonId: "123")) {
    LessonLiveActivity()
} contentStates: {
    LessonActivityAttributes.ContentState(
        lessonName: "Physics",
        room: "A-32",
        building: nil,
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        colorHex: "#FF9500",
        iconSystemName: "atom",
        isLive: true,
        progress: 0.7,
        timeRemaining: 1080,
        travelTimeMinutes: nil,
        walkingTimeMinutes: nil,
        distanceMeters: nil
    )
}

#Preview("Lock Screen Live", as: .content, using: LessonActivityAttributes(locationName: "School", lessonId: "123")) {
    LessonLiveActivity()
} contentStates: {
    LessonActivityAttributes.ContentState(
        lessonName: "Physics",
        room: "Room A-32",
        building: "Science Building",
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        colorHex: "#007AFF",
        iconSystemName: "atom",
        isLive: true,
        progress: 0.65,
        timeRemaining: 1260,
        travelTimeMinutes: nil,
        walkingTimeMinutes: nil,
        distanceMeters: nil
    )
}

#Preview("Lock Screen Upcoming", as: .content, using: LessonActivityAttributes(locationName: "School", lessonId: "123")) {
    LessonLiveActivity()
} contentStates: {
    LessonActivityAttributes.ContentState(
        lessonName: "Chemistry",
        room: "Lab C-10",
        building: "Science Building",
        startTime: Date().addingTimeInterval(1200),
        endTime: Date().addingTimeInterval(4800),
        colorHex: "#FF9500",
        iconSystemName: "flask.fill",
        isLive: false,
        progress: 0,
        timeRemaining: 1200,
        travelTimeMinutes: 5,
        walkingTimeMinutes: 12,
        distanceMeters: 850
    )
}
