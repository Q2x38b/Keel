import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showQuickAdd = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content - Dashboard only
            DashboardView()

            // Plus button - bottom left
            HStack {
                FloatingActionButton(icon: "plus") {
                    showQuickAdd = true
                }
                .padding(.leading, 16)

                Spacer()
            }
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddClassSheet()
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
        }
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    var size: CGFloat = 52
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.tertiaryBackground)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
        .contentShape(Circle())
        .buttonStyle(HapticFloatingButtonStyle())
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Quick Add Class Sheet
struct QuickAddClassSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @FocusState private var isNameFocused: Bool
    @FocusState private var isRoomFocused: Bool

    @State private var className = ""
    @State private var selectedDay: DayOfWeek = .current
    @State private var startTime = Date()
    @State private var room = ""
    @State private var selectedColor: LessonColor = .blue

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Class")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Button {
                    HapticManager.shared.dismiss()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(Color.tertiaryBackground)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)

            // Form fields
            VStack(spacing: 12) {
                // Class name
                TextField("Class name", text: $className)
                    .font(.system(size: 16))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .focused($isNameFocused)

                // Day and Time row
                HStack(spacing: 10) {
                    // Day picker
                    Menu {
                        ForEach(DayOfWeek.orderedWeek) { day in
                            Button(day.name) {
                                HapticManager.shared.selection()
                                selectedDay = day
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 13))
                            Text(selectedDay.shortName)
                                .font(.system(size: 14, weight: .medium))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    // Time picker
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)

                    Spacer()

                    // Color picker
                    Menu {
                        ForEach(LessonColor.allCases) { color in
                            Button {
                                HapticManager.shared.selectionConfirm()
                                selectedColor = color
                            } label: {
                                Label(color.name, systemImage: "circle.fill")
                            }
                            .tint(color.color)
                        }
                    } label: {
                        Circle()
                            .fill(selectedColor.color)
                            .frame(width: 32, height: 32)
                    }
                }

                // Room
                HStack(spacing: 8) {
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                    TextField("Room (optional)", text: $room)
                        .font(.system(size: 15))
                        .focused($isRoomFocused)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.horizontal, 20)

            Spacer()

            // Save button
            Button {
                HapticManager.shared.success()
                saveClass()
            } label: {
                Text("Add Class")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(className.isEmpty ? Color.textTertiary : Color.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(className.isEmpty ? Color.tertiaryBackground : Color.white)
                    )
            }
            .buttonStyle(HapticButtonStyle(hapticStyle: .primary, scaleEffect: 0.98))
            .disabled(className.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.secondaryBackground)
        .onAppear {
            isNameFocused = true
        }
    }

    private func saveClass() {
        guard !className.isEmpty else { return }

        let endTime = Calendar.current.date(byAdding: .hour, value: 1, to: startTime) ?? startTime

        let locationId = appState.locations.first?.id ?? UUID()
        let lesson = Lesson(
            name: className,
            room: room.isEmpty ? "TBD" : room,
            startTime: startTime,
            endTime: endTime,
            color: selectedColor,
            locationId: locationId
        )

        appState.saveLesson(lesson)

        let scheduledLesson = ScheduledLesson(
            lessonId: lesson.id,
            dayOfWeek: selectedDay
        )
        appState.saveScheduledLesson(scheduledLesson)

        dismiss()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
