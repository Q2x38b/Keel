import SwiftUI

struct LessonRow: View {
    let lesson: Lesson
    let location: SavedLocation?
    let isActive: Bool

    init(lesson: Lesson, location: SavedLocation? = nil, isActive: Bool = false) {
        self.lesson = lesson
        self.location = location
        self.isActive = isActive
    }

    var body: some View {
        HStack(spacing: 16) {
            // Color indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(lesson.color.color)
                .frame(width: 4, height: 50)

            VStack(alignment: .leading, spacing: 6) {
                Text(lesson.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    // Time
                    Label(lesson.formattedTimeRange, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Room
                    Label(lesson.room, systemImage: "door.left.hand.open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Location (if provided)
                if let location = location {
                    Label(location.name, systemImage: location.iconName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Active indicator
            if isActive {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            isActive ?
                RoundedRectangle(cornerRadius: 12)
                    .fill(lesson.color.color.opacity(0.1))
                : nil
        )
    }
}

// MARK: - Compact Lesson Row (for schedule grid)
struct CompactLessonRow: View {
    let lesson: Lesson
    let showTime: Bool

    init(lesson: Lesson, showTime: Bool = true) {
        self.lesson = lesson
        self.showTime = showTime
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(lesson.color.color)
                .frame(width: 8, height: 8)

            Text(lesson.name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            if showTime {
                Text(lesson.formattedStartTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Lesson Card (for detailed view)
struct LessonCard: View {
    let lesson: Lesson
    let location: SavedLocation?
    let scheduledDays: [DayOfWeek]
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Circle()
                    .fill(lesson.color.color)
                    .frame(width: 12, height: 12)

                Text(lesson.name)
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Menu {
                    Button(action: {
                        HapticManager.shared.buttonTap()
                        onEdit()
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive, action: {
                        HapticManager.shared.warning()
                        onDelete()
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            // Details Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                DetailItem(icon: "clock", title: "Time", value: lesson.formattedTimeRange)
                DetailItem(icon: "door.left.hand.open", title: "Room", value: lesson.room)

                if let location = location {
                    DetailItem(icon: location.iconName, title: "Location", value: location.name)
                }

                if lesson.notifyMinutesBefore > 0 {
                    DetailItem(icon: "bell", title: "Reminder", value: "\(lesson.notifyMinutesBefore) min before")
                }
            }

            // Scheduled Days
            if !scheduledDays.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schedule")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(DayOfWeek.orderedWeek) { day in
                            DayBadge(
                                day: day,
                                isSelected: scheduledDays.contains(day)
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Detail Item
struct DetailItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Spacer()
        }
    }
}

// MARK: - Day Badge
struct DayBadge: View {
    let day: DayOfWeek
    let isSelected: Bool

    var body: some View {
        Text(day.initial)
            .font(.caption2)
            .fontWeight(.semibold)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
            )
            .foregroundStyle(isSelected ? .white : .secondary)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            LessonRow(
                lesson: Lesson.samples[0],
                location: SavedLocation.samples[1],
                isActive: true
            )

            LessonRow(
                lesson: Lesson.samples[1],
                location: SavedLocation.samples[1]
            )

            Divider()

            LessonCard(
                lesson: Lesson.samples[0],
                location: SavedLocation.samples[1],
                scheduledDays: [.monday, .wednesday, .friday],
                onEdit: {},
                onDelete: {}
            )
            .padding(.horizontal)
        }
    }
    .background(Color(.systemGroupedBackground))
}
