import SwiftUI

enum LessonEditorMode {
    case create
    case edit(Lesson, ScheduledLesson)
}

struct LessonEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: LessonEditorMode
    let initialDay: DayOfWeek

    @State private var name: String = ""
    @State private var room: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    @State private var color: LessonColor = .blue
    @State private var selectedLocationId: UUID?
    @State private var selectedDays: Set<DayOfWeek> = []
    @State private var repeatPattern: RepeatPattern = .weekly
    @State private var notifyMinutesBefore: Int = 15
    @State private var showingDeleteConfirmation = false

    init(mode: LessonEditorMode, initialDay: DayOfWeek = .current) {
        self.mode = mode
        self.initialDay = initialDay

        switch mode {
        case .create:
            _selectedDays = State(initialValue: [initialDay])
        case .edit(let lesson, let scheduled):
            _name = State(initialValue: lesson.name)
            _room = State(initialValue: lesson.room)
            _startTime = State(initialValue: lesson.startTime)
            _endTime = State(initialValue: lesson.endTime)
            _color = State(initialValue: lesson.color)
            _selectedLocationId = State(initialValue: lesson.locationId)
            _selectedDays = State(initialValue: [scheduled.dayOfWeek])
            _repeatPattern = State(initialValue: scheduled.repeatPattern)
            _notifyMinutesBefore = State(initialValue: lesson.notifyMinutesBefore)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section("Class Details") {
                    TextField("Class Name", text: $name)

                    TextField("Room", text: $room)

                    LessonColorPicker(selectedColor: $color)
                }

                // Time
                Section("Time") {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)

                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                // Location
                Section("Location") {
                    if appState.locations.isEmpty {
                        HStack {
                            Text("No locations added")
                                .foregroundStyle(.secondary)

                            Spacer()

                            NavigationLink("Add") {
                                LocationsView()
                            }
                            .font(.subheadline)
                        }
                    } else {
                        Picker("School/Building", selection: $selectedLocationId) {
                            Text("Select Location")
                                .tag(nil as UUID?)

                            ForEach(appState.locations) { location in
                                Label(location.name, systemImage: location.iconName)
                                    .tag(location.id as UUID?)
                            }
                        }
                    }
                }

                // Schedule
                Section("Schedule") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Days")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(DayOfWeek.orderedWeek) { day in
                                DayToggle(
                                    day: day,
                                    isSelected: selectedDays.contains(day)
                                )
                                .onTapGesture {
                                    HapticManager.shared.toggle()
                                    if selectedDays.contains(day) {
                                        selectedDays.remove(day)
                                    } else {
                                        selectedDays.insert(day)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Picker("Repeat", selection: $repeatPattern) {
                        ForEach(RepeatPattern.allCases) { pattern in
                            Text(pattern.name).tag(pattern)
                        }
                    }
                }

                // Notifications
                Section("Notifications") {
                    Picker("Reminder", selection: $notifyMinutesBefore) {
                        Text("None").tag(0)
                        Text("5 minutes before").tag(5)
                        Text("10 minutes before").tag(10)
                        Text("15 minutes before").tag(15)
                        Text("30 minutes before").tag(30)
                        Text("1 hour before").tag(60)
                    }
                }

                // Delete Button (Edit mode only)
                if case .edit = mode {
                    Section {
                        Button(role: .destructive) {
                            HapticManager.shared.warning()
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Class")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Class" : "New Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        HapticManager.shared.dismiss()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        HapticManager.shared.success()
                        saveLesson()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .confirmationDialog(
                "Delete Class",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    HapticManager.shared.delete()
                    deleteLesson()
                }
                Button("Cancel", role: .cancel) {
                    HapticManager.shared.dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this class? This action cannot be undone.")
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        !name.isEmpty &&
        !room.isEmpty &&
        selectedLocationId != nil &&
        !selectedDays.isEmpty &&
        endTime > startTime
    }

    private func saveLesson() {
        guard let locationId = selectedLocationId else { return }

        let lesson = Lesson(
            id: existingLessonId ?? UUID(),
            name: name,
            room: room,
            startTime: startTime,
            endTime: endTime,
            color: color,
            locationId: locationId,
            notifyMinutesBefore: notifyMinutesBefore
        )

        appState.saveLesson(lesson)

        // Create scheduled lessons for each selected day
        for day in selectedDays {
            let scheduled = ScheduledLesson(
                id: existingScheduledId(for: day) ?? UUID(),
                lessonId: lesson.id,
                dayOfWeek: day,
                repeatPattern: repeatPattern
            )
            appState.saveScheduledLesson(scheduled)
        }

        dismiss()
    }

    private func deleteLesson() {
        if case .edit(let lesson, _) = mode {
            appState.deleteLesson(lesson)
        }
        dismiss()
    }

    private var existingLessonId: UUID? {
        if case .edit(let lesson, _) = mode {
            return lesson.id
        }
        return nil
    }

    private func existingScheduledId(for day: DayOfWeek) -> UUID? {
        if case .edit(_, let scheduled) = mode, scheduled.dayOfWeek == day {
            return scheduled.id
        }
        return nil
    }
}

// MARK: - Day Toggle
struct DayToggle: View {
    let day: DayOfWeek
    let isSelected: Bool

    var body: some View {
        Text(day.initial)
            .font(.caption)
            .fontWeight(.semibold)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
            )
            .foregroundStyle(isSelected ? .white : .primary)
    }
}

// MARK: - Lesson Detail View
struct LessonDetailView: View {
    @EnvironmentObject var appState: AppState
    let lesson: Lesson
    let scheduledLesson: ScheduledLesson

    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Lesson Card
                LessonCard(
                    lesson: lesson,
                    location: appState.locations.first(where: { $0.id == lesson.locationId }),
                    scheduledDays: scheduledDays,
                    onEdit: { showingEditor = true },
                    onDelete: { appState.deleteLesson(lesson) }
                )
                .padding(.horizontal)

                // Location Map
                if let location = appState.locations.first(where: { $0.id == lesson.locationId }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location")
                            .font(.headline)
                            .padding(.horizontal)

                        MapWidget(
                            coordinate: location.coordinate,
                            userLocation: appState.currentLocation,
                            showsRoute: true,
                            height: 150
                        )
                        .padding(.horizontal)

                        HStack {
                            Label(location.name, systemImage: location.iconName)
                                .font(.subheadline)

                            Spacer()

                            if let userLocation = appState.currentLocation {
                                Text(location.formattedDistance(from: userLocation))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(lesson.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    HapticManager.shared.buttonTap()
                    showingEditor = true
                }) {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            LessonEditorView(mode: .edit(lesson, scheduledLesson))
        }
    }

    private var scheduledDays: [DayOfWeek] {
        appState.scheduledLessons
            .filter { $0.lessonId == lesson.id }
            .map { $0.dayOfWeek }
    }
}

// MARK: - Preview
#Preview {
    LessonEditorView(mode: .create, initialDay: .monday)
        .environmentObject(AppState())
}
