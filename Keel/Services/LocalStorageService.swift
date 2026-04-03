import Foundation

/// Local storage service using UserDefaults for data persistence
/// Used as primary storage when CloudKit is not available
class LocalStorageService {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let lessons = "keel_lessons"
        static let scheduledLessons = "keel_scheduled_lessons"
        static let locations = "keel_locations"
    }

    // MARK: - Lessons

    func fetchLessons() -> [Lesson] {
        guard let data = defaults.data(forKey: Keys.lessons) else { return [] }
        return (try? JSONDecoder().decode([Lesson].self, from: data)) ?? []
    }

    func saveLessons(_ lessons: [Lesson]) {
        if let data = try? JSONEncoder().encode(lessons) {
            defaults.set(data, forKey: Keys.lessons)
        }
    }

    func saveLesson(_ lesson: Lesson) {
        var lessons = fetchLessons()
        if let index = lessons.firstIndex(where: { $0.id == lesson.id }) {
            lessons[index] = lesson
        } else {
            lessons.append(lesson)
        }
        saveLessons(lessons)
    }

    func deleteLesson(_ lesson: Lesson) {
        var lessons = fetchLessons()
        lessons.removeAll { $0.id == lesson.id }
        saveLessons(lessons)

        // Also delete associated scheduled lessons
        var scheduled = fetchScheduledLessons()
        scheduled.removeAll { $0.lessonId == lesson.id }
        saveScheduledLessons(scheduled)
    }

    // MARK: - Scheduled Lessons

    func fetchScheduledLessons() -> [ScheduledLesson] {
        guard let data = defaults.data(forKey: Keys.scheduledLessons) else { return [] }
        return (try? JSONDecoder().decode([ScheduledLesson].self, from: data)) ?? []
    }

    func saveScheduledLessons(_ scheduledLessons: [ScheduledLesson]) {
        if let data = try? JSONEncoder().encode(scheduledLessons) {
            defaults.set(data, forKey: Keys.scheduledLessons)
        }
    }

    func saveScheduledLesson(_ scheduledLesson: ScheduledLesson) {
        var scheduled = fetchScheduledLessons()
        if let index = scheduled.firstIndex(where: { $0.id == scheduledLesson.id }) {
            scheduled[index] = scheduledLesson
        } else {
            scheduled.append(scheduledLesson)
        }
        saveScheduledLessons(scheduled)
    }

    func deleteScheduledLesson(_ scheduledLesson: ScheduledLesson) {
        var scheduled = fetchScheduledLessons()
        scheduled.removeAll { $0.id == scheduledLesson.id }
        saveScheduledLessons(scheduled)
    }

    // MARK: - Locations

    func fetchLocations() -> [SavedLocation] {
        guard let data = defaults.data(forKey: Keys.locations) else { return [] }
        return (try? JSONDecoder().decode([SavedLocation].self, from: data)) ?? []
    }

    func saveLocations(_ locations: [SavedLocation]) {
        if let data = try? JSONEncoder().encode(locations) {
            defaults.set(data, forKey: Keys.locations)
        }
    }

    func saveLocation(_ location: SavedLocation) {
        var locations = fetchLocations()
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            locations[index] = location
        } else {
            locations.append(location)
        }
        saveLocations(locations)
    }

    func deleteLocation(_ location: SavedLocation) {
        var locations = fetchLocations()
        locations.removeAll { $0.id == location.id }
        saveLocations(locations)
    }
}
