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
                    HStack(spacing: 10) {
                        // Lesson color indicator
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.fromHex(context.state.colorHex))
                            .frame(width: 4, height: 40)

                        VStack(alignment: .leading, spacing: 3) {
                            // Status badge
                            Text(context.state.isLive ? "IN CLASS" : "UP NEXT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(context.state.isLive ? Color.red : Color.orange)

                            // Lesson name
                            Text(context.state.lessonName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    // Circular progress with time
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 3.5)
                            .frame(width: 40, height: 40)

                        Circle()
                            .trim(from: 0, to: context.state.isLive ? context.state.progress : 0)
                            .stroke(
                                Color.fromHex(context.state.colorHex),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))

                        Text(compactTimeText(context.state.timeRemaining))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 14) {
                        // Room
                        HStack(spacing: 4) {
                            Image(systemName: "door.left.hand.open")
                                .font(.system(size: 11, weight: .medium))
                            Text(context.state.room)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white)

                        Spacer()

                        // Time
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11, weight: .medium))
                            Text(context.state.isLive ? "Ends \(formatTime(context.state.endTime))" : "Starts \(formatTime(context.state.startTime))")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 6)
                }
            } compactLeading: {
                // MARK: - Compact Leading - Icon + time text
                HStack(spacing: 4) {
                    Image(systemName: context.state.isLive ? "book.fill" : "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.fromHex(context.state.colorHex))

                    Text(compactTimeText(context.state.timeRemaining))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fromHex(context.state.colorHex))
                        .contentTransition(.numericText())
                }
            } compactTrailing: {
                // MARK: - Compact Trailing - Small circular progress
                // Keep it small to avoid being cut off
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 2)

                    Circle()
                        .trim(from: 0, to: context.state.isLive ? context.state.progress : 1.0)
                        .stroke(
                            Color.fromHex(context.state.colorHex),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text(miniTimeText(context.state.timeRemaining))
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                .frame(width: 20, height: 20)
            } minimal: {
                // MARK: - Minimal View - Just colored progress ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 2)

                    Circle()
                        .trim(from: 0, to: context.state.isLive ? context.state.progress : 1.0)
                        .stroke(
                            Color.fromHex(context.state.colorHex),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text(miniTimeText(context.state.timeRemaining))
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                .frame(width: 18, height: 18)
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.fromHex(context.state.colorHex).opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "book.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.fromHex(context.state.colorHex))
            }

            // Middle - Lesson info
            VStack(alignment: .leading, spacing: 3) {
                Text(context.state.lessonName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    HStack(spacing: 2) {
                        Image(systemName: "door.left.hand.open")
                            .font(.system(size: 9, weight: .medium))
                        Text(context.state.room)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.7))

                    if context.state.isLive {
                        Text("LIVE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.red.opacity(0.2)))
                    }
                }
            }

            Spacer()

            // Right side - Circular progress with time
            ZStack {
                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3.5)

                // Progress arc
                Circle()
                    .trim(from: 0, to: context.state.isLive ? context.state.progress : 1.0)
                    .stroke(
                        Color.fromHex(context.state.colorHex),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Time number in center
                Text(centerTimeText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var centerTimeText: String {
        let totalMinutes = Int(abs(context.state.timeRemaining) / 60)
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60)h"
        }
        return "\(totalMinutes)"
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
        isLive: true,
        progress: 0.55,
        timeRemaining: 1920
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
        isLive: true,
        progress: 0.4,
        timeRemaining: 2160
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
        isLive: true,
        progress: 0.7,
        timeRemaining: 1080
    )
}

#Preview("Lock Screen", as: .content, using: LessonActivityAttributes(locationName: "School", lessonId: "123")) {
    LessonLiveActivity()
} contentStates: {
    LessonActivityAttributes.ContentState(
        lessonName: "Physics",
        room: "Room A-32",
        building: "Science Building",
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        colorHex: "#007AFF",
        isLive: true,
        progress: 0.65,
        timeRemaining: 1260
    )
}
