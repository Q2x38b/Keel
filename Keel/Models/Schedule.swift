import Foundation
import CloudKit

struct ScheduledLesson: Identifiable, Codable, Hashable {
    let id: UUID
    var lessonId: UUID
    var dayOfWeek: DayOfWeek
    var repeatPattern: RepeatPattern

    init(
        id: UUID = UUID(),
        lessonId: UUID,
        dayOfWeek: DayOfWeek,
        repeatPattern: RepeatPattern = .weekly
    ) {
        self.id = id
        self.lessonId = lessonId
        self.dayOfWeek = dayOfWeek
        self.repeatPattern = repeatPattern
    }

    // MARK: - CloudKit Record

    static let recordType = "ScheduledLesson"

    init?(from record: CKRecord) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let lessonIdString = record["lessonId"] as? String,
              let lessonId = UUID(uuidString: lessonIdString),
              let dayOfWeekRaw = record["dayOfWeek"] as? Int,
              let dayOfWeek = DayOfWeek(rawValue: dayOfWeekRaw),
              let repeatPatternRaw = record["repeatPattern"] as? String,
              let repeatPattern = RepeatPattern(rawValue: repeatPatternRaw) else {
            return nil
        }

        self.id = id
        self.lessonId = lessonId
        self.dayOfWeek = dayOfWeek
        self.repeatPattern = repeatPattern
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType)
        record["id"] = id.uuidString
        record["lessonId"] = lessonId.uuidString
        record["dayOfWeek"] = dayOfWeek.rawValue
        record["repeatPattern"] = repeatPattern.rawValue
        return record
    }
}

// MARK: - Day of Week
enum DayOfWeek: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    var shortName: String {
        String(name.prefix(3))
    }

    var initial: String {
        String(name.prefix(1))
    }

    static var current: DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return DayOfWeek(rawValue: weekday) ?? .monday
    }

    static var weekdays: [DayOfWeek] {
        [.monday, .tuesday, .wednesday, .thursday, .friday]
    }

    static var weekend: [DayOfWeek] {
        [.saturday, .sunday]
    }

    static var orderedWeek: [DayOfWeek] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }
}

// MARK: - Repeat Pattern
enum RepeatPattern: String, Codable, CaseIterable, Identifiable {
    case weekly
    case biweekly
    case monthly
    case once

    var id: String { rawValue }

    var name: String {
        switch self {
        case .weekly: return "Every Week"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Every Month"
        case .once: return "One Time"
        }
    }

    var description: String {
        switch self {
        case .weekly: return "Repeats every week"
        case .biweekly: return "Repeats every other week"
        case .monthly: return "Repeats once a month"
        case .once: return "Does not repeat"
        }
    }
}

// MARK: - Sample Data
extension ScheduledLesson {
    // Use the fixed lesson IDs
    private static let physicsId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let biologyId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let mathId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    static var samples: [ScheduledLesson] {
        let today = DayOfWeek.current
        return [
            // Schedule lessons for today so they always show
            ScheduledLesson(lessonId: physicsId, dayOfWeek: today),
            ScheduledLesson(lessonId: biologyId, dayOfWeek: today),
            ScheduledLesson(lessonId: mathId, dayOfWeek: today),
            // Also schedule for other days
            ScheduledLesson(lessonId: physicsId, dayOfWeek: .monday),
            ScheduledLesson(lessonId: physicsId, dayOfWeek: .wednesday),
            ScheduledLesson(lessonId: biologyId, dayOfWeek: .tuesday),
            ScheduledLesson(lessonId: biologyId, dayOfWeek: .thursday),
            ScheduledLesson(lessonId: mathId, dayOfWeek: .friday)
        ]
    }
}
