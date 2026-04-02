import Foundation
import CloudKit

actor CloudKitService {
    private let container: CKContainer
    private let database: CKDatabase

    init() {
        // Use the default container - configure in Xcode with your bundle ID
        container = CKContainer.default()
        database = container.privateCloudDatabase
    }

    // MARK: - Account Status

    func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    // MARK: - Lessons

    func fetchLessons() async throws -> [Lesson] {
        let query = CKQuery(recordType: Lesson.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]

        let (results, _) = try await database.records(matching: query)

        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return Lesson(from: record)
        }
    }

    func saveLesson(_ lesson: Lesson) async throws {
        // Check if record exists
        if let existingRecord = try await fetchRecord(type: Lesson.recordType, id: lesson.id) {
            // Update existing record
            existingRecord["name"] = lesson.name
            existingRecord["room"] = lesson.room
            existingRecord["startTime"] = lesson.startTime
            existingRecord["endTime"] = lesson.endTime
            existingRecord["color"] = lesson.color.rawValue
            existingRecord["locationId"] = lesson.locationId.uuidString
            existingRecord["notifyMinutesBefore"] = lesson.notifyMinutesBefore
            try await database.save(existingRecord)
        } else {
            // Create new record
            let record = lesson.toRecord()
            try await database.save(record)
        }
    }

    func deleteLesson(_ lesson: Lesson) async throws {
        if let record = try await fetchRecord(type: Lesson.recordType, id: lesson.id) {
            try await database.deleteRecord(withID: record.recordID)
        }

        // Also delete associated scheduled lessons
        let scheduledQuery = CKQuery(
            recordType: ScheduledLesson.recordType,
            predicate: NSPredicate(format: "lessonId == %@", lesson.id.uuidString)
        )
        let (results, _) = try await database.records(matching: scheduledQuery)

        for (recordID, _) in results {
            try await database.deleteRecord(withID: recordID)
        }
    }

    // MARK: - Scheduled Lessons

    func fetchScheduledLessons() async throws -> [ScheduledLesson] {
        let query = CKQuery(recordType: ScheduledLesson.recordType, predicate: NSPredicate(value: true))

        let (results, _) = try await database.records(matching: query)

        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return ScheduledLesson(from: record)
        }
    }

    func saveScheduledLesson(_ scheduledLesson: ScheduledLesson) async throws {
        if let existingRecord = try await fetchRecord(type: ScheduledLesson.recordType, id: scheduledLesson.id) {
            existingRecord["lessonId"] = scheduledLesson.lessonId.uuidString
            existingRecord["dayOfWeek"] = scheduledLesson.dayOfWeek.rawValue
            existingRecord["repeatPattern"] = scheduledLesson.repeatPattern.rawValue
            try await database.save(existingRecord)
        } else {
            let record = scheduledLesson.toRecord()
            try await database.save(record)
        }
    }

    func deleteScheduledLesson(_ scheduledLesson: ScheduledLesson) async throws {
        if let record = try await fetchRecord(type: ScheduledLesson.recordType, id: scheduledLesson.id) {
            try await database.deleteRecord(withID: record.recordID)
        }
    }

    // MARK: - Locations

    func fetchLocations() async throws -> [SavedLocation] {
        let query = CKQuery(recordType: SavedLocation.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        let (results, _) = try await database.records(matching: query)

        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return SavedLocation(from: record)
        }
    }

    func saveLocation(_ location: SavedLocation) async throws {
        if let existingRecord = try await fetchRecord(type: SavedLocation.recordType, id: location.id) {
            existingRecord["name"] = location.name
            existingRecord["latitude"] = location.latitude
            existingRecord["longitude"] = location.longitude
            existingRecord["type"] = location.type.rawValue
            existingRecord["iconName"] = location.iconName
            existingRecord["address"] = location.address
            try await database.save(existingRecord)
        } else {
            let record = location.toRecord()
            try await database.save(record)
        }
    }

    func deleteLocation(_ location: SavedLocation) async throws {
        if let record = try await fetchRecord(type: SavedLocation.recordType, id: location.id) {
            try await database.deleteRecord(withID: record.recordID)
        }
    }

    // MARK: - Helpers

    private func fetchRecord(type: String, id: UUID) async throws -> CKRecord? {
        let predicate = NSPredicate(format: "id == %@", id.uuidString)
        let query = CKQuery(recordType: type, predicate: predicate)

        let (results, _) = try await database.records(matching: query, resultsLimit: 1)

        guard let (_, result) = results.first,
              case .success(let record) = result else {
            return nil
        }

        return record
    }
}

// MARK: - CloudKit Subscription Manager
extension CloudKitService {
    func setupSubscriptions() async throws {
        // Subscribe to changes in lessons
        let lessonSubscription = CKQuerySubscription(
            recordType: Lesson.recordType,
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        lessonSubscription.notificationInfo = notification

        try await database.save(lessonSubscription)

        // Subscribe to changes in scheduled lessons
        let scheduledSubscription = CKQuerySubscription(
            recordType: ScheduledLesson.recordType,
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        scheduledSubscription.notificationInfo = notification

        try await database.save(scheduledSubscription)

        // Subscribe to changes in locations
        let locationSubscription = CKQuerySubscription(
            recordType: SavedLocation.recordType,
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        locationSubscription.notificationInfo = notification

        try await database.save(locationSubscription)
    }
}
