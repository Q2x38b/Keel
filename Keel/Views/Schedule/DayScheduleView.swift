import SwiftUI

struct DayScheduleView: View {
    @EnvironmentObject var appState: AppState
    let day: DayOfWeek

    @State private var showingAddLesson = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Timeline Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(day.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("\(lessonsForDay.count) sessions scheduled")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if day == .current {
                        Text("Today")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.accentColor))
                    }
                }
                .padding(.horizontal)

                // Timeline
                if lessonsForDay.isEmpty {
                    EmptyDayScheduleView(day: day)
                } else {
                    TimelineView(lessons: lessonsWithDetails)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(day.name)'s Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    HapticManager.shared.buttonTap()
                    showingAddLesson = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddLesson) {
            LessonEditorView(mode: .create, initialDay: day)
        }
    }

    private var lessonsForDay: [ScheduledLesson] {
        appState.scheduledLessons
            .filter { $0.dayOfWeek == day }
            .sorted { lesson1, lesson2 in
                guard let l1 = appState.lessons.first(where: { $0.id == lesson1.lessonId }),
                      let l2 = appState.lessons.first(where: { $0.id == lesson2.lessonId }) else {
                    return false
                }
                return l1.startTime < l2.startTime
            }
    }

    private var lessonsWithDetails: [(scheduled: ScheduledLesson, lesson: Lesson, location: SavedLocation?)] {
        lessonsForDay.compactMap { scheduled in
            guard let lesson = appState.lessons.first(where: { $0.id == scheduled.lessonId }) else {
                return nil
            }
            let location = appState.locations.first(where: { $0.id == lesson.locationId })
            return (scheduled, lesson, location)
        }
    }
}

// MARK: - Timeline View
struct TimelineView: View {
    let lessons: [(scheduled: ScheduledLesson, lesson: Lesson, location: SavedLocation?)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(lessons.enumerated()), id: \.element.scheduled.id) { index, item in
                TimelineItem(
                    lesson: item.lesson,
                    location: item.location,
                    isFirst: index == 0,
                    isLast: index == lessons.count - 1,
                    isCurrentLesson: isCurrentLesson(item.lesson)
                )
            }
        }
        .padding(.horizontal)
    }

    private func isCurrentLesson(_ lesson: Lesson) -> Bool {
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
            return false
        }

        return now >= start && now <= end
    }
}

// MARK: - Timeline Item
struct TimelineItem: View {
    let lesson: Lesson
    let location: SavedLocation?
    let isFirst: Bool
    let isLast: Bool
    let isCurrentLesson: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Time & Timeline
            VStack(spacing: 0) {
                // Time
                Text(lesson.formattedStartTime)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isCurrentLesson ? Color.accentColor : Color.secondary)
                    .frame(width: 50, alignment: .trailing)

                // Timeline dot and line
                ZStack {
                    if !isFirst {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 2)
                            .offset(y: -20)
                    }

                    Circle()
                        .fill(isCurrentLesson ? Color.accentColor : lesson.color.color)
                        .frame(width: 12, height: 12)

                    if !isLast {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 2)
                            .offset(y: 40)
                    }
                }
                .frame(width: 20, height: 60)

                // End time
                Text(lesson.formattedEndTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 50, alignment: .trailing)
            }

            // Lesson Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(lesson.name)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    if isCurrentLesson {
                        Text("Now")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor))
                    }
                }

                HStack(spacing: 16) {
                    Label(lesson.room, systemImage: "door.left.hand.open")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let location = location {
                        Label(location.name, systemImage: location.iconName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Duration bar
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(lesson.color.color.opacity(0.3))
                        .frame(height: 4)
                        .overlay(alignment: .leading) {
                            if isCurrentLesson {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(lesson.color.color)
                                    .frame(width: geometry.size.width * progress, height: 4)
                            }
                        }
                }
                .frame(height: 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isCurrentLesson ? lesson.color.color.opacity(0.1) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isCurrentLesson ? lesson.color.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .padding(.vertical, 8)
    }

    private var progress: Double {
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
}

// MARK: - Empty Day View
struct EmptyDayScheduleView: View {
    let day: DayOfWeek

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.stars")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No sessions on \(day.name)")
                .font(.title3)
                .fontWeight(.medium)

            Text("Enjoy your free day!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        DayScheduleView(day: .monday)
            .environmentObject(AppState())
    }
}
