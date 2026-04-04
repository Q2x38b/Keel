import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDay: DayOfWeek = .current
    @State private var showingAddLesson = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Day Selector
                DaySelector(selectedDay: $selectedDay)
                    .padding(.vertical, 12)

                // Lessons List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(lessonsForSelectedDay) { scheduled in
                            if let lesson = appState.lessons.first(where: { $0.id == scheduled.lessonId }) {
                                NavigationLink(destination: LessonDetailView(lesson: lesson, scheduledLesson: scheduled)) {
                                    ScheduleLessonCard(
                                        lesson: lesson,
                                        location: appState.locations.first(where: { $0.id == lesson.locationId }),
                                        repeatPattern: scheduled.repeatPattern
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if lessonsForSelectedDay.isEmpty {
                            EmptyDayCard(day: selectedDay)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Schedule")
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
                LessonEditorView(mode: .create, initialDay: selectedDay)
            }
        }
    }

    private var lessonsForSelectedDay: [ScheduledLesson] {
        appState.scheduledLessons
            .filter { $0.dayOfWeek == selectedDay }
            .sorted { lesson1, lesson2 in
                guard let l1 = appState.lessons.first(where: { $0.id == lesson1.lessonId }),
                      let l2 = appState.lessons.first(where: { $0.id == lesson2.lessonId }) else {
                    return false
                }
                return l1.startTime < l2.startTime
            }
    }
}

// MARK: - Day Selector
struct DaySelector: View {
    @Binding var selectedDay: DayOfWeek

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DayOfWeek.orderedWeek) { day in
                    DaySelectorButton(
                        day: day,
                        isSelected: selectedDay == day,
                        isToday: day == .current
                    )
                    .onTapGesture {
                        if selectedDay != day {
                            HapticManager.shared.selection()
                        }
                        withAnimation(.spring(response: 0.3)) {
                            selectedDay = day
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Day Selector Button
struct DaySelectorButton: View {
    let day: DayOfWeek
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(day.shortName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)

            if isToday && !isSelected {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 50, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
        )
        .foregroundStyle(isSelected ? .white : .primary)
    }
}

// MARK: - Schedule Lesson Card
struct ScheduleLessonCard: View {
    let lesson: Lesson
    let location: SavedLocation?
    let repeatPattern: RepeatPattern

    var body: some View {
        HStack(spacing: 16) {
            // Time Column
            VStack(alignment: .trailing, spacing: 4) {
                Text(lesson.formattedStartTime)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(lesson.formattedEndTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60)

            // Color Bar
            RoundedRectangle(cornerRadius: 4)
                .fill(lesson.color.color)
                .frame(width: 4)

            // Lesson Details
            VStack(alignment: .leading, spacing: 6) {
                Text(lesson.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    Label(lesson.room, systemImage: "door.left.hand.open")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let location = location {
                        Label(location.name, systemImage: location.iconName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if repeatPattern != .weekly {
                    Text(repeatPattern.name)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Empty Day Card
struct EmptyDayCard: View {
    let day: DayOfWeek

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No sessions on \(day.name)")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Tap + to add a session")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Preview
#Preview {
    ScheduleView()
        .environmentObject(AppState())
}
