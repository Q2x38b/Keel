import SwiftUI

struct ScheduleSheetView: View {
    @Binding var selectedDay: DayOfWeek
    @Binding var currentDetent: PresentationDetent
    let lessonsForDay: [ScheduledLesson]
    let allLessons: [Lesson]
    let locations: [SavedLocation]
    let currentLesson: Lesson?

    @State private var showingClassCreator = false
    @State private var showingSettings = false

    private var isExpanded: Bool {
        currentDetent != .height(240)
    }

    // Get first lesson time for selected day
    private var firstLessonTime: String? {
        guard let first = lessonsForDay.first,
              let lesson = allLessons.first(where: { $0.id == first.lessonId }) else {
            return nil
        }
        return lesson.formattedTimeRange
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            VStack(spacing: 0) {
                // Spacer for header
                Color.clear
                    .frame(height: headerHeight)

                // Schedule content
                if isExpanded {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if lessonsForDay.isEmpty {
                                EmptyScheduleView()
                                    .padding(.top, 20)
                            } else {
                                ForEach(lessonsForDay, id: \.id) { scheduled in
                                    if let lesson = allLessons.first(where: { $0.id == scheduled.lessonId }) {
                                        SheetLessonRowCard(
                                            lesson: lesson,
                                            location: locations.first(where: { $0.id == lesson.locationId }),
                                            isActive: selectedDay == .current && currentLesson?.id == lesson.id
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 0)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    // Collapsed compact view
                    CompactDaySummaryView(
                        lessonsForDay: lessonsForDay,
                        allLessons: allLessons,
                        currentLesson: currentLesson,
                        isToday: selectedDay == .current
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer(minLength: 0)
                }
            }

            // Liquid Glass Header
            LiquidGlassHeader(
                selectedDay: $selectedDay,
                showingClassCreator: $showingClassCreator,
                showingSettings: $showingSettings
            )
        }
        .frame(maxWidth: .infinity)
        .background(Color.secondaryBackground)
        .sheet(isPresented: $showingClassCreator) {
            ClassCreatorView(selectedDay: selectedDay)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private var headerHeight: CGFloat {
        return 180
    }
}

// MARK: - Liquid Glass Header
struct LiquidGlassHeader: View {
    @Binding var selectedDay: DayOfWeek
    @Binding var showingClassCreator: Bool
    @Binding var showingSettings: Bool

    private var selectedDate: Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday - 2 + 7) % 7
        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return today
        }
        let orderedDays: [DayOfWeek] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        let dayIndex = orderedDays.firstIndex(of: selectedDay) ?? 0
        return calendar.date(byAdding: .day, value: dayIndex, to: startOfWeek) ?? today
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        let day = Calendar.current.component(.day, from: selectedDate)
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        formatter.dateFormat = "MMMM d'\(suffix)', yyyy"
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Variable blur background
            ZStack {
                // Gradient blur effect
                TintFreeGradientBlur(maxBlurRadius: 20, direction: .blurredTopClearBottom)
                    .ignoresSafeArea(edges: .top)

                // Subtle gradient overlay for depth
                LinearGradient(
                    colors: [
                        Color.secondaryBackground.opacity(0.9),
                        Color.secondaryBackground.opacity(0.7),
                        Color.secondaryBackground.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Header content
                VStack(spacing: 8) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.textTertiary.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)

                    // Top row: Today button and action buttons
                    HStack {
                        // Today button
                        Button {
                            HapticManager.shared.buttonTap()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedDay = .current
                            }
                        } label: {
                            Text("Today")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(selectedDay == .current ? Color.textPrimary : Color.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                        )
                                )
                        }
                        .buttonStyle(LiquidGlassButtonStyle())

                        Spacer()

                        // Action buttons in pill container
                        HStack(spacing: 0) {
                            Button {
                                HapticManager.shared.buttonTap()
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                    .frame(width: 40, height: 36)
                            }

                            Divider()
                                .frame(height: 20)
                                .background(Color.white.opacity(0.15))

                            Button {
                                HapticManager.shared.buttonTap()
                                showingClassCreator = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                    .frame(width: 40, height: 36)
                            }
                        }
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                )
                        )
                        .buttonStyle(LiquidGlassButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Day name (large)
                    Text(dayName)
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)

                    // Full date (subtitle)
                    Text(formattedDate)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Compact week calendar
                    LiquidGlassWeekCalendar(selectedDay: $selectedDay)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }
            }
            .frame(height: 180)
        }
    }
}

// MARK: - Liquid Glass Week Calendar (Circular Day Badges)
struct LiquidGlassWeekCalendar: View {
    @Binding var selectedDay: DayOfWeek

    private var weekDays: [(day: DayOfWeek, date: Int, isToday: Bool, fullDate: Date)] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)

        // Start from Monday (weekday 2 in Calendar)
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
            return (dayOfWeek, dayNumber, isToday, date)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left arrow
            Button {
                HapticManager.shared.selection()
                // Navigate to previous week (optional functionality)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 24, height: 44)
            }
            .opacity(0.5)

            Spacer(minLength: 0)

            // Day circles
            HStack(spacing: 8) {
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
                            // Date number in circle
                            ZStack {
                                Circle()
                                    .fill(selectedDay == item.day ? Color.textPrimary : Color.clear)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                selectedDay == item.day ? Color.clear : Color.white.opacity(0.1),
                                                lineWidth: 1
                                            )
                                    )

                                Text("\(item.date)")
                                    .font(.system(size: 16, weight: item.isToday || selectedDay == item.day ? .bold : .medium))
                                    .foregroundStyle(selectedDay == item.day ? Color.background : Color.textPrimary)
                            }
                            .frame(width: 40, height: 40)

                            // Day abbreviation
                            Text(item.day.shortName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(item.isToday ? Color.red : Color.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)

            // Right arrow
            Button {
                HapticManager.shared.selection()
                // Navigate to next week (optional functionality)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 24, height: 44)
            }
            .opacity(0.5)
        }
    }
}

// MARK: - Compact Week Calendar View (like the reference image)
struct CompactWeekCalendarView: View {
    @Binding var selectedDay: DayOfWeek

    private var weekDays: [(day: DayOfWeek, date: Int, isToday: Bool, fullDate: Date)] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)

        // Start from Monday (weekday 2 in Calendar)
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
            return (dayOfWeek, dayNumber, isToday, date)
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
                        // Date number (bigger)
                        Text("\(item.date)")
                            .font(.system(size: 22, weight: item.isToday ? .bold : .medium))
                            .foregroundStyle(Color.textPrimary)

                        // Day name (3 letters, uppercase) - red for today
                        Text(item.day.shortName.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(item.isToday ? Color.red : Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selectedDay == item.day ? Color.white.opacity(0.25) : Color.clear, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Compact Day Summary View (shown when collapsed)
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

    private var classCountText: String {
        let count = lessonsForDay.count
        if count == 0 {
            return "No classes"
        } else if count == 1 {
            return "1 class"
        } else {
            return "\(count) classes"
        }
    }

    var body: some View {
        if lessonsForDay.isEmpty {
            // Empty state
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.green)

                Text("No classes scheduled")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textSecondary)

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.tertiaryBackground.opacity(0.5))
            )
        } else {
            // Show first 2-3 classes in a compact horizontal scroll
            HStack(spacing: 10) {
                ForEach(sortedLessons.prefix(3), id: \.id) { lesson in
                    CompactLessonPill(
                        lesson: lesson,
                        isActive: isToday && currentLesson?.id == lesson.id
                    )
                }

                if sortedLessons.count > 3 {
                    Text("+\(sortedLessons.count - 3)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 8)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Compact Lesson Pill
struct CompactLessonPill: View {
    let lesson: Lesson
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Color dot
            Circle()
                .fill(lesson.color.color)
                .frame(width: 8, height: 8)

            // Lesson name
            Text(lesson.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            // Time
            Text(lesson.formattedStartTime)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? Color.statusLive : Color.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? Color.statusLive.opacity(0.1) : Color.tertiaryBackground.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isActive ? Color.statusLive.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Sheet Lesson Row Card
struct SheetLessonRowCard: View {
    let lesson: Lesson
    let location: SavedLocation?
    var isActive: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            // Color indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(lesson.color.color)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(lesson.formattedTimeRange)
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(isActive ? Color.statusOnline : Color.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: "door.left.hand.open")
                            .font(.system(size: 11))
                        Text(lesson.room)
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()

            if isActive {
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.statusLive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.statusLive.opacity(0.15))
                    )
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.background)
    }
}

// MARK: - Empty Schedule View
struct EmptyScheduleView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 36))
                .foregroundStyle(Color.textTertiary)

            Text("No classes scheduled")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textSecondary)

            Text("Enjoy your free day!")
                .font(.system(size: 14))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Collapsed Schedule Summary
struct CollapsedScheduleSummary: View {
    let lessonsCount: Int
    let currentLesson: Lesson?
    let nextLesson: Lesson?

    var body: some View {
        HStack {
            if let current = currentLesson {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.statusLive)
                        .frame(width: 8, height: 8)

                    Text(current.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }
            } else if let next = nextLesson {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)

                    Text("Next: \(next.name)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }
            } else {
                Text("No more classes")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Text("Swipe up for more")
                .font(.system(size: 12))
                .foregroundStyle(Color.textTertiary)
        }
    }
}

// MARK: - Class Creator View
struct ClassCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let selectedDay: DayOfWeek

    @State private var className = ""
    @State private var room = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var selectedColor: LessonColor = .blue
    @State private var selectedDays: Set<DayOfWeek> = []

    private let colors: [LessonColor] = [.blue, .green, .orange, .purple, .red, .yellow, .pink, .teal]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Class name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Class Name")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        TextField("e.g. Mathematics", text: $className)
                            .font(.system(size: 16))
                            .padding(14)
                            .background(Color.tertiaryBackground)
                            .cornerRadius(12)
                    }

                    // Room
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Room")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        TextField("e.g. A-204", text: $room)
                            .font(.system(size: 16))
                            .padding(14)
                            .background(Color.tertiaryBackground)
                            .cornerRadius(12)
                    }

                    // Time
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Time")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.textTertiary)
                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.tertiaryBackground)
                            .cornerRadius(12)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("End")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.textTertiary)
                                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.tertiaryBackground)
                            .cornerRadius(12)
                        }
                    }

                    // Color
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        HStack(spacing: 10) {
                            ForEach(colors, id: \.self) { color in
                                Button {
                                    if selectedColor != color {
                                        HapticManager.shared.selectionConfirm()
                                    }
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                                                .padding(2)
                                        )
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                                .opacity(selectedColor == color ? 1 : 0)
                                        )
                                }
                            }
                        }
                    }

                    // Days
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Repeat on")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        HStack(spacing: 8) {
                            ForEach([DayOfWeek.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday], id: \.self) { day in
                                Button {
                                    HapticManager.shared.toggle()
                                    if selectedDays.contains(day) {
                                        selectedDays.remove(day)
                                    } else {
                                        selectedDays.insert(day)
                                    }
                                } label: {
                                    Text(day.singleLetter)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(selectedDays.contains(day) ? .white : Color.textSecondary)
                                        .frame(width: 38, height: 38)
                                        .background(
                                            Circle()
                                                .fill(selectedDays.contains(day) ? Color.textPrimary : Color.tertiaryBackground)
                                        )
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.secondaryBackground)
            .navigationTitle("New Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        HapticManager.shared.dismiss()
                        dismiss()
                    }
                    .foregroundStyle(Color.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        HapticManager.shared.success()
                        createClass()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(className.isEmpty || room.isEmpty || selectedDays.isEmpty)
                }
            }
        }
        .onAppear {
            selectedDays.insert(selectedDay)
        }
    }

    private func createClass() {
        // Use first available location or create a placeholder ID
        let locationId = appState.locations.first?.id ?? UUID()

        let newLesson = Lesson(
            name: className,
            room: room,
            startTime: startTime,
            endTime: endTime,
            color: selectedColor,
            locationId: locationId
        )

        appState.saveLesson(newLesson)

        for day in selectedDays {
            let scheduled = ScheduledLesson(lessonId: newLesson.id, dayOfWeek: day)
            appState.saveScheduledLesson(scheduled)
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

// MARK: - Liquid Glass Button Style
struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
