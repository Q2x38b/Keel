import SwiftUI

struct StudyTimerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var timer = StudyTimer.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLesson: Lesson?
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Mode indicator
                    HStack(spacing: 8) {
                        ForEach(0..<timer.pomodorosUntilLongBreak, id: \.self) { index in
                            Circle()
                                .fill(index < timer.completedPomodoros ? Color.green : Color.textTertiary.opacity(0.3))
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.top, 20)

                    // Current mode
                    Text(timer.mode.title.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(modeColor)
                        .tracking(2)

                    // Timer display
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.textTertiary.opacity(0.2), lineWidth: 12)
                            .frame(width: 260, height: 260)

                        // Progress circle
                        Circle()
                            .trim(from: 0, to: timer.progress)
                            .stroke(
                                modeColor,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 260, height: 260)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: timer.progress)

                        // Time display
                        VStack(spacing: 8) {
                            Text(timer.formattedTime)
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.textPrimary)
                                .contentTransition(.numericText())

                            if let lessonName = timer.linkedLessonName {
                                Text(lessonName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }

                    // Linked lesson selector
                    if timer.state == .idle {
                        Menu {
                            Button("No Subject") {
                                selectedLesson = nil
                            }
                            Divider()
                            ForEach(appState.lessons) { lesson in
                                Button {
                                    selectedLesson = lesson
                                } label: {
                                    Label(lesson.name, systemImage: lesson.icon.systemName)
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedLesson?.icon.systemName ?? "book.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(selectedLesson?.name ?? "Select Subject")
                                    .font(.system(size: 15, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.tertiaryBackground)
                            .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    // Control buttons
                    HStack(spacing: 24) {
                        // Stop button
                        if timer.state != .idle {
                            Button {
                                timer.stop()
                            } label: {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.red.opacity(0.8))
                                    .clipShape(Circle())
                            }
                        }

                        // Main button (start/pause/resume)
                        Button {
                            switch timer.state {
                            case .idle:
                                timer.start(linkedTo: selectedLesson)
                            case .running, .breakTime:
                                timer.pause()
                            case .paused:
                                timer.resume()
                            }
                        } label: {
                            Image(systemName: mainButtonIcon)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                                .background(modeColor)
                                .clipShape(Circle())
                                .shadow(color: modeColor.opacity(0.4), radius: 12, x: 0, y: 6)
                        }

                        // Skip button
                        if timer.state != .idle {
                            Button {
                                timer.skip()
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.textTertiary.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Study Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        HapticManager.shared.dismiss()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                StudyTimerSettingsView(timer: timer)
            }
        }
    }

    private var mainButtonIcon: String {
        switch timer.state {
        case .idle:
            return "play.fill"
        case .running, .breakTime:
            return "pause.fill"
        case .paused:
            return "play.fill"
        }
    }

    private var modeColor: Color {
        switch timer.mode {
        case .work:
            return .blue
        case .shortBreak:
            return .green
        case .longBreak:
            return .purple
        }
    }
}

// MARK: - Study Timer Settings View
struct StudyTimerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var timer: StudyTimer

    var body: some View {
        NavigationStack {
            List {
                Section("Session Durations") {
                    HStack {
                        Text("Focus Time")
                        Spacer()
                        Picker("", selection: $timer.workDuration) {
                            ForEach([15, 20, 25, 30, 45, 60], id: \.self) { mins in
                                Text("\(mins) min").tag(mins)
                            }
                        }
                        .labelsHidden()
                    }

                    HStack {
                        Text("Short Break")
                        Spacer()
                        Picker("", selection: $timer.shortBreakDuration) {
                            ForEach([3, 5, 10], id: \.self) { mins in
                                Text("\(mins) min").tag(mins)
                            }
                        }
                        .labelsHidden()
                    }

                    HStack {
                        Text("Long Break")
                        Spacer()
                        Picker("", selection: $timer.longBreakDuration) {
                            ForEach([10, 15, 20, 30], id: \.self) { mins in
                                Text("\(mins) min").tag(mins)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Section("Cycle") {
                    HStack {
                        Text("Long Break After")
                        Spacer()
                        Picker("", selection: $timer.pomodorosUntilLongBreak) {
                            ForEach([2, 3, 4, 5, 6], id: \.self) { count in
                                Text("\(count) sessions").tag(count)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Section {
                    Button("Reset Completed Sessions") {
                        timer.resetCompletedPomodoros()
                        HapticManager.shared.buttonTap()
                    }
                    .foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.secondaryBackground)
            .navigationTitle("Timer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    StudyTimerView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
