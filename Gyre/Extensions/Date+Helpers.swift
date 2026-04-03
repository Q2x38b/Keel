import Foundation

extension Date {
    // MARK: - Time Formatting

    var shortTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    var mediumTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: self)
    }

    // MARK: - Date Formatting

    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: self)
    }

    var mediumDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }

    var dayOfWeekString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }

    var shortDayOfWeekString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }

    // MARK: - Relative Time

    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    // MARK: - Time Components

    var hour: Int {
        Calendar.current.component(.hour, from: self)
    }

    var minute: Int {
        Calendar.current.component(.minute, from: self)
    }

    var dayOfWeek: DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: self)
        return DayOfWeek(rawValue: weekday) ?? .monday
    }

    // MARK: - Time Comparisons

    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    var isWeekend: Bool {
        Calendar.current.isDateInWeekend(self)
    }

    // MARK: - Time Manipulation

    func setting(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: self) ?? self
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    func adding(hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hours, to: self) ?? self
    }

    func adding(minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }

    // MARK: - Time Interval Helpers

    func timeUntil(_ date: Date) -> TimeInterval {
        date.timeIntervalSince(self)
    }

    func timeSince(_ date: Date) -> TimeInterval {
        timeIntervalSince(date)
    }
}

// MARK: - TimeInterval Extensions
extension TimeInterval {
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }

    var formattedCountdown: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var minutesRemaining: Int {
        Int(self / 60)
    }

    var hoursRemaining: Double {
        self / 3600
    }
}

// MARK: - Calendar Helpers
extension Calendar {
    func nextDate(matching dayOfWeek: DayOfWeek, after date: Date = Date()) -> Date? {
        var components = DateComponents()
        components.weekday = dayOfWeek.rawValue

        return self.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }
}
