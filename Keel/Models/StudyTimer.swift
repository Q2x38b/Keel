import Foundation
import SwiftUI
import Combine

// MARK: - Study Timer Model
@MainActor
class StudyTimer: ObservableObject {
    static let shared = StudyTimer()

    enum TimerState {
        case idle
        case running
        case paused
        case breakTime
    }

    enum TimerMode {
        case work
        case shortBreak
        case longBreak

        var duration: TimeInterval {
            switch self {
            case .work: return 25 * 60 // 25 minutes
            case .shortBreak: return 5 * 60 // 5 minutes
            case .longBreak: return 15 * 60 // 15 minutes
            }
        }

        var title: String {
            switch self {
            case .work: return "Focus"
            case .shortBreak: return "Short Break"
            case .longBreak: return "Long Break"
            }
        }
    }

    @Published var state: TimerState = .idle
    @Published var mode: TimerMode = .work
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var completedPomodoros: Int = 0
    @Published var linkedLessonId: UUID?
    @Published var linkedLessonName: String?

    // Customizable durations (in minutes)
    @Published var workDuration: Int = 25 {
        didSet {
            UserDefaults.standard.set(workDuration, forKey: "studyTimer.workDuration")
        }
    }
    @Published var shortBreakDuration: Int = 5 {
        didSet {
            UserDefaults.standard.set(shortBreakDuration, forKey: "studyTimer.shortBreakDuration")
        }
    }
    @Published var longBreakDuration: Int = 15 {
        didSet {
            UserDefaults.standard.set(longBreakDuration, forKey: "studyTimer.longBreakDuration")
        }
    }
    @Published var pomodorosUntilLongBreak: Int = 4 {
        didSet {
            UserDefaults.standard.set(pomodorosUntilLongBreak, forKey: "studyTimer.pomodorosUntilLongBreak")
        }
    }

    private var timer: Timer?
    private var startTime: Date?
    private var pausedTimeRemaining: TimeInterval?

    private init() {
        loadSettings()
    }

    private func loadSettings() {
        let savedWork = UserDefaults.standard.integer(forKey: "studyTimer.workDuration")
        if savedWork > 0 { workDuration = savedWork }

        let savedShort = UserDefaults.standard.integer(forKey: "studyTimer.shortBreakDuration")
        if savedShort > 0 { shortBreakDuration = savedShort }

        let savedLong = UserDefaults.standard.integer(forKey: "studyTimer.longBreakDuration")
        if savedLong > 0 { longBreakDuration = savedLong }

        let savedPomodoros = UserDefaults.standard.integer(forKey: "studyTimer.pomodorosUntilLongBreak")
        if savedPomodoros > 0 { pomodorosUntilLongBreak = savedPomodoros }
    }

    var currentDuration: TimeInterval {
        switch mode {
        case .work: return TimeInterval(workDuration * 60)
        case .shortBreak: return TimeInterval(shortBreakDuration * 60)
        case .longBreak: return TimeInterval(longBreakDuration * 60)
        }
    }

    var progress: Double {
        guard currentDuration > 0 else { return 0 }
        return 1.0 - (timeRemaining / currentDuration)
    }

    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Timer Controls

    func start(linkedTo lesson: Lesson? = nil) {
        linkedLessonId = lesson?.id
        linkedLessonName = lesson?.name

        if state == .paused, let remaining = pausedTimeRemaining {
            timeRemaining = remaining
        } else {
            timeRemaining = currentDuration
        }

        state = mode == .work ? .running : .breakTime
        startTime = Date()
        pausedTimeRemaining = nil

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)

        HapticManager.shared.buttonTap()
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        pausedTimeRemaining = timeRemaining
        state = .paused
        HapticManager.shared.buttonTap()
    }

    func resume() {
        start()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        state = .idle
        mode = .work
        timeRemaining = currentDuration
        pausedTimeRemaining = nil
        linkedLessonId = nil
        linkedLessonName = nil
        HapticManager.shared.buttonTap()
    }

    func skip() {
        timer?.invalidate()
        timer = nil
        transitionToNextMode()
        HapticManager.shared.buttonTap()
    }

    private func tick() {
        guard timeRemaining > 0 else {
            completeSession()
            return
        }
        timeRemaining -= 1
    }

    private func completeSession() {
        timer?.invalidate()
        timer = nil

        HapticManager.shared.success()

        if mode == .work {
            completedPomodoros += 1
        }

        transitionToNextMode()
    }

    private func transitionToNextMode() {
        switch mode {
        case .work:
            if completedPomodoros > 0 && completedPomodoros % pomodorosUntilLongBreak == 0 {
                mode = .longBreak
            } else {
                mode = .shortBreak
            }
        case .shortBreak, .longBreak:
            mode = .work
        }

        timeRemaining = currentDuration
        state = .idle
    }

    func resetCompletedPomodoros() {
        completedPomodoros = 0
    }
}

// MARK: - Study Session Record
struct StudySession: Identifiable, Codable {
    let id: UUID
    let lessonId: UUID?
    let lessonName: String?
    let startTime: Date
    let duration: TimeInterval
    let completedPomodoros: Int

    init(id: UUID = UUID(), lessonId: UUID?, lessonName: String?, startTime: Date, duration: TimeInterval, completedPomodoros: Int) {
        self.id = id
        self.lessonId = lessonId
        self.lessonName = lessonName
        self.startTime = startTime
        self.duration = duration
        self.completedPomodoros = completedPomodoros
    }
}
