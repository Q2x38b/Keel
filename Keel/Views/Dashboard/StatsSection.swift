import SwiftUI

struct StatsSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            // Top row - two cards side by side
            HStack(spacing: 12) {
                // Classes Today
                StatCard(
                    title: "Classes Today",
                    value: "\(todayClassCount)",
                    subtitle: "\(totalHoursToday) of classes",
                    accentColor: .blue
                )

                // Next Class
                StatCard(
                    title: "Next Class",
                    value: nextClassTime,
                    subtitle: nextClassName,
                    accentColor: .purple
                )
            }

            // Weekly Activity with bar chart
            WeeklyActivityCard(
                dailyCounts: weeklyClassCounts,
                totalHours: totalWeeklyHours
            )
        }
    }

    // MARK: - Computed Properties

    private var todayClassCount: Int {
        appState.lessonsForToday().count
    }

    private var totalHoursToday: String {
        let todayScheduled = appState.lessonsForToday()
        var totalMinutes: Double = 0

        for scheduled in todayScheduled {
            if let lesson = appState.lessons.first(where: { $0.id == scheduled.lessonId }) {
                totalMinutes += lesson.duration / 60
            }
        }

        let hours = Int(totalMinutes / 60)
        let minutes = Int(totalMinutes.truncatingRemainder(dividingBy: 60))

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private var nextClassTime: String {
        guard let (lesson, _) = appState.nextLesson() else {
            return "--"
        }
        return lesson.formattedStartTime
    }

    private var nextClassName: String {
        guard let (lesson, _) = appState.nextLesson() else {
            return "No more classes"
        }
        return lesson.name
    }

    private var weeklyClassCounts: [Int] {
        DayOfWeek.allCases.map { day in
            appState.lessonsForDay(day).count
        }
    }

    private var totalWeeklyHours: String {
        var totalMinutes: Double = 0

        for day in DayOfWeek.allCases {
            let dayLessons = appState.lessonsForDay(day)
            for scheduled in dayLessons {
                if let lesson = appState.lessons.first(where: { $0.id == scheduled.lessonId }) {
                    totalMinutes += lesson.duration / 60
                }
            }
        }

        let hours = Int(totalMinutes / 60)
        return "\(hours)h weekly"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)

            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(accentColor)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Weekly Activity Card

struct WeeklyActivityCard: View {
    let dailyCounts: [Int]
    let totalHours: String

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Activity")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)

                    Text(totalHours)
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()
            }

            // Bar chart
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 6) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(barColor(for: index))
                            .frame(height: barHeight(for: index))
                            .frame(maxWidth: .infinity)

                        // Day label
                        Text(dayLabels[index])
                            .font(.caption2)
                            .foregroundStyle(isToday(index) ? Color.white : Color.textTertiary)
                    }
                }
            }
            .frame(height: 80)
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
    }

    private func barHeight(for index: Int) -> CGFloat {
        let count = dailyCounts[safe: index] ?? 0
        let maxCount = max(dailyCounts.max() ?? 1, 1)
        let minHeight: CGFloat = 8
        let maxHeight: CGFloat = 56

        if count == 0 {
            return minHeight
        }

        return minHeight + (maxHeight - minHeight) * (CGFloat(count) / CGFloat(maxCount))
    }

    private func barColor(for index: Int) -> Color {
        let count = dailyCounts[safe: index] ?? 0

        if isToday(index) {
            return count > 0 ? .purple : Color.textTertiary.opacity(0.3)
        }

        if count == 0 {
            return Color.textTertiary.opacity(0.2)
        }

        return Color.textTertiary.opacity(0.4)
    }

    private func isToday(_ index: Int) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        // Calendar weekday: 1 = Sunday, so index 0 = Sunday
        return (weekday - 1) == index
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ScrollView {
        StatsSection()
            .padding()
    }
    .background(Color.background)
    .environmentObject(AppState())
    .preferredColorScheme(.dark)
}
