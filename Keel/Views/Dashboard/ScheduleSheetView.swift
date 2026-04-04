import SwiftUI

struct ScheduleSheetView: View {
    @Binding var selectedDay: DayOfWeek
    @Binding var currentDetent: PresentationDetent
    let lessonsForDay: [ScheduledLesson]
    let allLessons: [Lesson]
    let locations: [SavedLocation]
    let currentLesson: Lesson?

    private var sortedLessons: [Lesson] {
        lessonsForDay.compactMap { scheduled in
            allLessons.first { $0.id == scheduled.lessonId }
        }.sorted { $0.startTime < $1.startTime }
    }

    private var totalDuration: String {
        let minutes = sortedLessons.reduce(0) { $0 + Int($1.duration / 60) }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        }
        return "\(mins)m"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Minimal drag indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 20)

            // Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedDay == .current ? "Today" : selectedDay.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if !sortedLessons.isEmpty {
                        Text("\(sortedLessons.count) classes \u{2022} \(totalDuration)")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer()

                if let active = currentLesson, selectedDay == .current {
                    LiveIndicator()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            // Content
            if sortedLessons.isEmpty {
                EmptyDayView()
                    .padding(.top, 40)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedLessons) { lesson in
                            SessionCard(
                                lesson: lesson,
                                isActive: selectedDay == .current && currentLesson?.id == lesson.id
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Color.background)
    }
}

// MARK: - Live Indicator

struct LiveIndicator: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)

            Text("In Session")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.12))
        .clipShape(Capsule())
        .onAppear { isPulsing = true }
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let lesson: Lesson
    let isActive: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                Text(lesson.formattedStartTime)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(isActive ? .white : Color.textSecondary)

                Text(lesson.formattedEndTime)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(width: 70, alignment: .trailing)

            // Color accent
            RoundedRectangle(cornerRadius: 2)
                .fill(lesson.color.color)
                .frame(width: 3)
                .padding(.vertical, 4)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(lesson.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(lesson.room, systemImage: "door.left.hand.open")

                    if let building = lesson.building, !building.isEmpty {
                        Label(building, systemImage: "building.2")
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Icon
            Image(systemName: lesson.icon.systemName)
                .font(.system(size: 18))
                .foregroundStyle(lesson.color.color.opacity(0.6))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isActive ? lesson.color.color.opacity(0.15) : Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isActive ? lesson.color.color.opacity(0.3) : Color.cardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Empty Day View

struct EmptyDayView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sun.max")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.textTertiary.opacity(0.5))

            VStack(spacing: 6) {
                Text("No Classes")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)

                Text("Enjoy your day off")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }
}

// MARK: - Compact Week Calendar View

struct CompactWeekCalendarView: View {
    @Binding var selectedDay: DayOfWeek

    private var weekDays: [(day: DayOfWeek, date: Int, isToday: Bool)] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)

        let daysFromMonday = (weekday - 2 + 7) % 7
        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return []
        }

        let orderedDays: [DayOfWeek] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else {
                return nil
            }
            let dayNumber = calendar.component(.day, from: date)
            let dayOfWeek = orderedDays[offset]
            let isToday = calendar.isDateInToday(date)
            return (dayOfWeek, dayNumber, isToday)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.day) { item in
                Button {
                    if selectedDay != item.day {
                        HapticManager.shared.selection()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDay = item.day
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text("\(item.date)")
                            .font(.system(size: 20, weight: item.isToday ? .bold : .medium, design: .rounded))
                            .foregroundStyle(.white)

                        Text(item.day.shortName.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(item.isToday ? Color.red : Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedDay == item.day ? Color.white.opacity(0.08) : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Compact Day Summary View

struct CompactDaySummaryView: View {
    let lessonsForDay: [ScheduledLesson]
    let allLessons: [Lesson]
    let currentLesson: Lesson?
    let isToday: Bool

    private var sortedLessons: [Lesson] {
        lessonsForDay.compactMap { scheduled in
            allLessons.first { $0.id == scheduled.lessonId }
        }.sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        if lessonsForDay.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.green)

                Text("Free day")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textSecondary)

                Spacer()
            }
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            HStack(spacing: 8) {
                ForEach(sortedLessons.prefix(3)) { lesson in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(lesson.color.color)
                            .frame(width: 6, height: 6)

                        Text(lesson.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(isToday && currentLesson?.id == lesson.id ? lesson.color.color.opacity(0.2) : Color.cardBackground)
                    )
                }

                if sortedLessons.count > 3 {
                    Text("+\(sortedLessons.count - 3)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Class Creator View

struct ClassCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @FocusState private var focusedField: Field?

    let selectedDay: DayOfWeek

    enum Field { case name, room }

    @State private var sessionName = ""
    @State private var room = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var selectedColor: LessonColor = .blue
    @State private var selectedIcon: LessonIcon = .book
    @State private var selectedLocationId: UUID?
    @State private var showingIconPicker = false
    @State private var hasDateRange = false
    @State private var sessionStartDate = Date()
    @State private var sessionEndDate = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
    @State private var showingDatePicker = false
    @State private var selectedDays: Set<DayOfWeek> = []

    private let colors: [LessonColor] = [.blue, .green, .orange, .purple, .red, .pink]

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    var body: some View {
        VStack(spacing: 16) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            // Name and Room row
            HStack(spacing: 10) {
                // Icon button
                Button {
                    HapticManager.shared.buttonTap()
                    showingIconPicker = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(selectedColor.color.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: selectedIcon.systemName)
                            .font(.system(size: 20))
                            .foregroundStyle(selectedColor.color)
                    }
                }
                .buttonStyle(.plain)

                TextField("Class name", text: $sessionName)
                    .font(.system(size: 16, weight: .medium))
                    .focused($focusedField, equals: .name)
                    .padding(14)
                    .background(Color.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: 6) {
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                    TextField("Room", text: $room)
                        .font(.system(size: 15))
                        .focused($focusedField, equals: .room)
                }
                .padding(14)
                .frame(width: 95)
                .background(Color.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Time row
            HStack(spacing: 10) {
                TimePickerField(label: "Start", time: $startTime, formatter: timeFormatter)
                TimePickerField(label: "End", time: $endTime, formatter: timeFormatter)

                // Location
                Menu {
                    Button { selectedLocationId = nil } label: {
                        Label("None", systemImage: "minus.circle")
                    }
                    ForEach(appState.locations) { location in
                        Button {
                            selectedLocationId = location.id
                        } label: {
                            Label(location.name, systemImage: location.iconName)
                        }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: appState.locations.first { $0.id == selectedLocationId }?.iconName ?? "mappin")
                            .font(.system(size: 16))
                        Text(appState.locations.first { $0.id == selectedLocationId }?.name ?? "Location")
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selectedLocationId != nil ? .white : Color.textTertiary)
                    .frame(width: 72)
                    .padding(.vertical, 14)
                    .background(Color.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            // Colors and date toggle
            HStack(spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        HapticManager.shared.selection()
                        selectedColor = color
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: selectedColor == color ? 2 : 0)
                                    .padding(2)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    HapticManager.shared.buttonTap()
                    showingDatePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: hasDateRange ? "calendar.badge.checkmark" : "calendar")
                            .font(.system(size: 13))
                        Text(hasDateRange ? "Dates" : "Set Dates")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(hasDateRange ? .blue : Color.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(hasDateRange ? Color.blue.opacity(0.12) : Color.tertiaryBackground)
                    .clipShape(Capsule())
                }
            }

            // Day picker
            HStack(spacing: 6) {
                ForEach(DayOfWeek.orderedWeek) { day in
                    Button {
                        HapticManager.shared.toggle()
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                    } label: {
                        Text(day.initial)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                Circle()
                                    .fill(selectedDays.contains(day) ? selectedColor.color : Color.tertiaryBackground)
                            )
                            .foregroundStyle(selectedDays.contains(day) ? .white : Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Add button
            Button {
                HapticManager.shared.success()
                createClass()
                dismiss()
            } label: {
                Text("Add Class")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canSave ? Color.background : Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSave ? Color.white : Color.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!canSave)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(Color.secondaryBackground)
        .onAppear {
            focusedField = .name
            selectedLocationId = appState.locations.first?.id
            if selectedDays.isEmpty {
                selectedDays = [selectedDay]
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon, selectedColor: selectedColor)
        }
        .sheet(isPresented: $showingDatePicker) {
            ClassDateRangeSheet(
                hasDateRange: $hasDateRange,
                startDate: $sessionStartDate,
                endDate: $sessionEndDate
            )
        }
    }

    private var canSave: Bool {
        !sessionName.isEmpty && endTime > startTime && !selectedDays.isEmpty
    }

    private func createClass() {
        let newLesson = Lesson(
            name: sessionName,
            room: room.isEmpty ? "TBD" : room,
            startTime: startTime,
            endTime: endTime,
            color: selectedColor,
            icon: selectedIcon,
            locationId: selectedLocationId,
            classStartDate: hasDateRange ? sessionStartDate : nil,
            classEndDate: hasDateRange ? sessionEndDate : nil
        )

        appState.saveLesson(newLesson)

        for day in selectedDays {
            let scheduled = ScheduledLesson(lessonId: newLesson.id, dayOfWeek: day)
            appState.saveScheduledLesson(scheduled)
        }
    }
}

// MARK: - Time Picker Field

struct TimePickerField: View {
    let label: String
    @Binding var time: Date
    let formatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textTertiary)

            Text(formatter.string(from: time))
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorMultiply(.clear)
        }
    }
}

// MARK: - Class Date Range Sheet

struct ClassDateRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasDateRange: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }

    private var weeksBetween: Int {
        Calendar.current.dateComponents([.weekOfYear], from: startDate, to: endDate).weekOfYear ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Duration")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 24)

            VStack(spacing: 16) {
                // Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Set End Date")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(hasDateRange ? "\(weeksBetween) weeks" : "Repeats indefinitely")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textTertiary)
                    }

                    Spacer()

                    Toggle("", isOn: $hasDateRange)
                        .labelsHidden()
                }
                .padding(16)
                .background(Color.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if hasDateRange {
                    HStack(spacing: 12) {
                        DateField(label: "Starts", date: $startDate, formatter: dateFormatter)

                        DateField(label: "Ends", date: $endDate, formatter: dateFormatter, minimumDate: startDate)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.secondaryBackground)
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}

// MARK: - Date Field

struct DateField: View {
    let label: String
    @Binding var date: Date
    let formatter: DateFormatter
    var minimumDate: Date? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textTertiary)

            Text(formatter.string(from: date))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if let min = minimumDate {
                DatePicker("", selection: $date, in: min..., displayedComponents: .date)
                    .labelsHidden()
                    .colorMultiply(.clear)
            } else {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .colorMultiply(.clear)
            }
        }
    }
}

// MARK: - DayOfWeek Extensions

extension DayOfWeek {
    var singleLetter: String {
        switch self {
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        case .sunday: return "S"
        }
    }
}
