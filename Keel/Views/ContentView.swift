import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @State private var showQuickAdd = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            Group {
                switch selectedTab {
                case 0:
                    DashboardView()
                case 1:
                    LocationsView()
                default:
                    DashboardView()
                }
            }

            // Bottom bar with plus button and nav
            HStack {
                // Plus button - bottom left
                FloatingActionButton(icon: "plus") {
                    showQuickAdd = true
                }
                .padding(.leading, 16)

                Spacer()

                // Navigation tab bar - bottom right
                TabBarControl(selectedTab: $selectedTab)
                    .padding(.trailing, 16)
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

// MARK: - Tab Bar Control (Sleek Segmented Style)
struct TabBarControl: View {
    @Binding var selectedTab: Int
    @Namespace private var tabNamespace

    private let tabs: [(icon: String, selectedIcon: String, label: String)] = [
        ("square.grid.2x2", "square.grid.2x2.fill", "Dashboard"),
        ("mappin.and.ellipse", "mappin.and.ellipse.circle.fill", "Locations")
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button {
                    if selectedTab != index {
                        HapticManager.shared.selection()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                } label: {
                    ZStack {
                        if selectedTab == index {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.tertiaryBackground)
                                .matchedGeometryEffect(id: "tabIndicator", in: tabNamespace)
                        }

                        Image(systemName: selectedTab == index ? tabs[index].selectedIcon : tabs[index].icon)
                            .font(.system(size: 17, weight: selectedTab == index ? .semibold : .regular))
                            .foregroundStyle(selectedTab == index ? .white : Color.textSecondary)
                    }
                    .frame(width: 48, height: 40)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.cardBorder, lineWidth: 0.5)
                )
        )
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
