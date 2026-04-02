import SwiftUI

struct CurrentClassCard: View {
    let currentLesson: Lesson?
    let nextLesson: (lesson: Lesson, startsIn: TimeInterval)?
    let nearestLocation: SavedLocation?
    let onTap: () -> Void

    private var activeLesson: Lesson? {
        currentLesson ?? nextLesson?.lesson
    }

    private var isLive: Bool {
        currentLesson != nil
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            onTap()
        }) {
            HStack(spacing: 10) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                // Content
                if let lesson = activeLesson {
                    Text(lesson.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text("•")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)

                    Text(lesson.room)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)

                    if let timeText = timeIndicatorText {
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)

                        Text(timeText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(statusColor)
                    }
                } else {
                    Text("No upcoming classes")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        if isLive {
            return .red
        } else if nextLesson != nil {
            return .orange
        } else {
            return Color.textTertiary
        }
    }

    private var timeIndicatorText: String? {
        if isLive, let lesson = currentLesson {
            let now = Date()
            let calendar = Calendar.current
            let endComponents = calendar.dateComponents([.hour, .minute], from: lesson.endTime)
            var todayEnd = calendar.dateComponents([.year, .month, .day], from: now)
            todayEnd.hour = endComponents.hour
            todayEnd.minute = endComponents.minute

            if let end = calendar.date(from: todayEnd) {
                let minutes = Int(end.timeIntervalSince(now) / 60)
                return "\(minutes)m left"
            }
        } else if let (_, startsIn) = nextLesson {
            let minutes = Int(startsIn / 60)
            if minutes >= 60 {
                let hours = minutes / 60
                let mins = minutes % 60
                return "in \(hours)h \(mins)m"
            }
            return "in \(minutes)m"
        }
        return nil
    }
}
