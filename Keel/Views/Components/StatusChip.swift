import SwiftUI

// MARK: - Lesson Status
enum LessonStatus {
    case noLessons
    case upcoming(startsIn: TimeInterval)
    case live(endsIn: TimeInterval)
    case ended

    var title: String {
        switch self {
        case .noLessons: return "No Sessions Right Now"
        case .upcoming: return "Upcoming Session"
        case .live: return "Live Session"
        case .ended: return "Sessions Ended"
        }
    }

    var icon: String {
        switch self {
        case .noLessons: return "book.closed"
        case .upcoming: return "chevron.right.2"
        case .live: return "book.fill"
        case .ended: return "checkmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .noLessons, .ended: return .secondary
        case .upcoming: return .orange
        case .live: return .red
        }
    }

    var timeText: String? {
        switch self {
        case .noLessons, .ended: return nil
        case .upcoming(let startsIn):
            return formatTimeInterval(startsIn, prefix: "Starts in")
        case .live(let endsIn):
            return formatTimeInterval(endsIn, suffix: "left")
        }
    }

    private func formatTimeInterval(_ interval: TimeInterval, prefix: String = "", suffix: String = "") -> String {
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        var result = ""
        if !prefix.isEmpty { result += prefix + " " }

        if hours > 0 {
            result += "\(hours)h \(remainingMinutes)m"
        } else {
            result += "\(minutes) min"
        }

        if !suffix.isEmpty { result += " " + suffix }
        return result
    }
}

// MARK: - Status Chip
struct StatusChip: View {
    let status: LessonStatus

    var body: some View {
        HStack(spacing: 16) {
            // Status Label
            HStack(spacing: 6) {
                Image(systemName: status.icon)
                    .font(.caption.weight(.semibold))

                Text(status.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(status.color)

            Spacer()

            // Time Badge
            if let timeText = status.timeText {
                TimeBadge(text: timeText, status: status)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Time Badge
struct TimeBadge: View {
    let text: String
    let status: LessonStatus

    var backgroundColor: Color {
        switch status {
        case .live: return .red.opacity(0.1)
        case .upcoming: return .green.opacity(0.1)
        default: return .secondary.opacity(0.1)
        }
    }

    var textColor: Color {
        switch status {
        case .live: return .red
        case .upcoming: return .green
        default: return .secondary
        }
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
    }
}

// MARK: - Lesson Number Badge
struct LessonNumberBadge: View {
    let number: Int
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 28, height: 28)

            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Lesson Details Row
struct LessonDetailsRow: View {
    let lesson: Lesson
    let lessonNumber: Int
    let status: LessonStatus

    var body: some View {
        HStack(spacing: 12) {
            LessonNumberBadge(number: lessonNumber, color: lesson.color.color)

            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                HStack(spacing: 16) {
                    // Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)

                        Text(timeText)
                            .font(.caption)
                    }
                    .foregroundStyle(timeColor)

                    // Room
                    HStack(spacing: 4) {
                        Image(systemName: "door.left.hand.open")
                            .font(.caption2)

                        Text(lesson.room)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Progress indicator for live lessons
            if case .live = status {
                ProgressBadge(lesson: lesson)
            }
        }
        .padding(.horizontal, 16)
    }

    private var timeText: String {
        switch status {
        case .live:
            return "Ends at \(lesson.formattedEndTime)"
        case .upcoming:
            return "Start at \(lesson.formattedStartTime)"
        default:
            return lesson.formattedTimeRange
        }
    }

    private var timeColor: Color {
        switch status {
        case .live: return .green
        case .upcoming: return .blue
        default: return .secondary
        }
    }
}

// MARK: - Progress Badge
struct ProgressBadge: View {
    let lesson: Lesson

    var progress: Double {
        let now = Date()
        let calendar = Calendar.current

        let startComponents = calendar.dateComponents([.hour, .minute], from: lesson.startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: lesson.endTime)

        var todayStart = calendar.dateComponents([.year, .month, .day], from: now)
        todayStart.hour = startComponents.hour
        todayStart.minute = startComponents.minute

        var todayEnd = calendar.dateComponents([.year, .month, .day], from: now)
        todayEnd.hour = endComponents.hour
        todayEnd.minute = endComponents.minute

        guard let start = calendar.date(from: todayStart),
              let end = calendar.date(from: todayEnd) else {
            return 0
        }

        let total = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        return min(max(elapsed / total, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.2), lineWidth: 3)
                .frame(width: 36, height: 36)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 5))")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.green)
        }
    }
}

// MARK: - Day Summary Row
struct DaySummaryRow: View {
    let lessonsCount: Int
    let endsAt: Date?

    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.caption2)

                Text("\(lessonsCount) Sessions Today")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            if let endsAt = endsAt {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.caption2)

                    Text("Ends at \(formatTime(endsAt))")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        StatusChip(status: .noLessons)

        StatusChip(status: .upcoming(startsIn: 900)) // 15 minutes

        StatusChip(status: .live(endsIn: 840)) // 14 minutes

        Divider()

        LessonDetailsRow(
            lesson: Lesson.samples[0],
            lessonNumber: 1,
            status: .upcoming(startsIn: 900)
        )

        LessonDetailsRow(
            lesson: Lesson.samples[1],
            lessonNumber: 2,
            status: .live(endsIn: 840)
        )

        Divider()

        DaySummaryRow(lessonsCount: 6, endsAt: Date().addingTimeInterval(3600 * 8))
    }
    .padding()
    .background(Color(.systemBackground))
}
