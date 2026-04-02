import SwiftUI
import CloudKit
import CoreLocation

struct Lesson: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var room: String
    var building: String?
    var buildingLatitude: Double?
    var buildingLongitude: Double?
    var startTime: Date
    var endTime: Date
    var color: LessonColor
    var locationId: UUID
    var notifyMinutesBefore: Int

    init(
        id: UUID = UUID(),
        name: String,
        room: String,
        building: String? = nil,
        buildingLatitude: Double? = nil,
        buildingLongitude: Double? = nil,
        startTime: Date,
        endTime: Date,
        color: LessonColor = .blue,
        locationId: UUID,
        notifyMinutesBefore: Int = 15
    ) {
        self.id = id
        self.name = name
        self.room = room
        self.building = building
        self.buildingLatitude = buildingLatitude
        self.buildingLongitude = buildingLongitude
        self.startTime = startTime
        self.endTime = endTime
        self.color = color
        self.locationId = locationId
        self.notifyMinutesBefore = notifyMinutesBefore
    }

    var hasBuildingLocation: Bool {
        buildingLatitude != nil && buildingLongitude != nil
    }

    var buildingCoordinate: CLLocationCoordinate2D? {
        guard let lat = buildingLatitude, let lon = buildingLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - CloudKit Record

    static let recordType = "Lesson"

    init?(from record: CKRecord) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let room = record["room"] as? String,
              let startTime = record["startTime"] as? Date,
              let endTime = record["endTime"] as? Date,
              let colorString = record["color"] as? String,
              let color = LessonColor(rawValue: colorString),
              let locationIdString = record["locationId"] as? String,
              let locationId = UUID(uuidString: locationIdString) else {
            return nil
        }

        self.id = id
        self.name = name
        self.room = room
        self.building = record["building"] as? String
        self.buildingLatitude = record["buildingLatitude"] as? Double
        self.buildingLongitude = record["buildingLongitude"] as? Double
        self.startTime = startTime
        self.endTime = endTime
        self.color = color
        self.locationId = locationId
        self.notifyMinutesBefore = record["notifyMinutesBefore"] as? Int ?? 15
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType)
        record["id"] = id.uuidString
        record["name"] = name
        record["room"] = room
        record["building"] = building
        record["buildingLatitude"] = buildingLatitude
        record["buildingLongitude"] = buildingLongitude
        record["startTime"] = startTime
        record["endTime"] = endTime
        record["color"] = color.rawValue
        record["locationId"] = locationId.uuidString
        record["notifyMinutesBefore"] = notifyMinutesBefore
        return record
    }

    // MARK: - Computed Properties

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }

    var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: endTime)
    }

    var formattedTimeRange: String {
        "\(formattedStartTime) - \(formattedEndTime)"
    }
}

// MARK: - Lesson Color
enum LessonColor: String, Codable, CaseIterable, Identifiable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case pink
    case teal

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .teal: return .teal
        }
    }

    var name: String {
        rawValue.capitalized
    }
}

// MARK: - Sample Data
extension Lesson {
    // Use fixed UUIDs so ScheduledLesson can reference them
    private static let sampleSchoolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    static let samples: [Lesson] = [
        Lesson(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Physics",
            room: "Room A-32",
            building: "Science Building",
            buildingLatitude: 37.7850,
            buildingLongitude: -122.4090,
            startTime: Calendar.current.date(bySettingHour: 9, minute: 45, second: 0, of: Date())!,
            endTime: Calendar.current.date(bySettingHour: 10, minute: 45, second: 0, of: Date())!,
            color: .blue,
            locationId: sampleSchoolId
        ),
        Lesson(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Biology",
            room: "Room A-45",
            building: "Life Sciences Hall",
            buildingLatitude: 37.7852,
            buildingLongitude: -122.4095,
            startTime: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date())!,
            endTime: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!,
            color: .green,
            locationId: sampleSchoolId
        ),
        Lesson(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Mathematics",
            room: "Room B-12",
            building: "Math & Engineering",
            buildingLatitude: 37.7848,
            buildingLongitude: -122.4100,
            startTime: Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date())!,
            endTime: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
            color: .orange,
            locationId: sampleSchoolId
        )
    ]
}
