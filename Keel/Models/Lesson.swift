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
    var icon: LessonIcon
    var locationId: UUID?
    var notifyMinutesBefore: Int
    var classStartDate: Date?
    var classEndDate: Date?

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
        icon: LessonIcon = .book,
        locationId: UUID? = nil,
        notifyMinutesBefore: Int = 15,
        classStartDate: Date? = nil,
        classEndDate: Date? = nil
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
        self.icon = icon
        self.locationId = locationId
        self.notifyMinutesBefore = notifyMinutesBefore
        self.classStartDate = classStartDate
        self.classEndDate = classEndDate
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
              let color = LessonColor(rawValue: colorString) else {
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
        if let iconString = record["icon"] as? String,
           let icon = LessonIcon(rawValue: iconString) {
            self.icon = icon
        } else {
            self.icon = .book
        }
        if let locationIdString = record["locationId"] as? String {
            self.locationId = UUID(uuidString: locationIdString)
        } else {
            self.locationId = nil
        }
        self.notifyMinutesBefore = record["notifyMinutesBefore"] as? Int ?? 15
        self.classStartDate = record["classStartDate"] as? Date
        self.classEndDate = record["classEndDate"] as? Date
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
        record["icon"] = icon.rawValue
        record["locationId"] = locationId?.uuidString
        record["notifyMinutesBefore"] = notifyMinutesBefore
        record["classStartDate"] = classStartDate
        record["classEndDate"] = classEndDate
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

// MARK: - Lesson Icon
enum LessonIcon: String, Codable, CaseIterable, Identifiable {
    // Core Education
    case book
    case graduationcap
    case pencil
    case ruler
    case backpack
    case textformat = "textformat.abc"

    // STEM
    case function
    case atom
    case flask
    case microscope
    case testtube = "testtube.2"
    case dna = "allergens"
    case waveform
    case cpu

    // Arts & Humanities
    case theatermasks
    case paintpalette
    case music = "music.note"
    case pianokeys = "pianokeys"
    case paintbrush
    case film = "film"

    // Languages & Literature
    case globe
    case textbook = "text.book.closed"
    case quote = "quote.bubble"
    case character = "character.book.closed"

    // Physical Education & Health
    case sportscourt
    case figure = "figure.run"
    case heart
    case dumbbell = "dumbbell"
    case basketball = "basketball"
    case swimming = "figure.pool.swim"

    // Technology & Engineering
    case laptopcomputer
    case wrench = "wrench.and.screwdriver"
    case gear
    case hammer
    case circuit = "memorychip"

    // Social Studies & Business
    case building = "building.columns"
    case chart = "chart.bar"
    case scale = "scale.3d"
    case banknote
    case person = "person.3"

    // Nature & Environment
    case leaf
    case tree = "tree"
    case sun = "sun.max"
    case cloud

    // Creative & Media
    case camera
    case photo
    case video = "video"
    case microphone = "mic"

    // Misc
    case brain
    case lightbulb
    case star
    case clock

    var id: String { rawValue }

    var systemName: String {
        switch self {
        // Core Education
        case .book: return "book.fill"
        case .graduationcap: return "graduationcap.fill"
        case .pencil: return "pencil"
        case .ruler: return "ruler"
        case .backpack: return "backpack.fill"
        case .textformat: return "textformat.abc"

        // STEM
        case .function: return "function"
        case .atom: return "atom"
        case .flask: return "flask.fill"
        case .microscope: return "microscope.fill"
        case .testtube: return "testtube.2"
        case .dna: return "allergens.fill"
        case .waveform: return "waveform"
        case .cpu: return "cpu.fill"

        // Arts & Humanities
        case .theatermasks: return "theatermasks.fill"
        case .paintpalette: return "paintpalette.fill"
        case .music: return "music.note"
        case .pianokeys: return "pianokeys"
        case .paintbrush: return "paintbrush.fill"
        case .film: return "film.fill"

        // Languages & Literature
        case .globe: return "globe"
        case .textbook: return "text.book.closed.fill"
        case .quote: return "quote.bubble.fill"
        case .character: return "character.book.closed.fill"

        // Physical Education & Health
        case .sportscourt: return "sportscourt.fill"
        case .figure: return "figure.run"
        case .heart: return "heart.fill"
        case .dumbbell: return "dumbbell.fill"
        case .basketball: return "basketball.fill"
        case .swimming: return "figure.pool.swim"

        // Technology & Engineering
        case .laptopcomputer: return "laptopcomputer"
        case .wrench: return "wrench.and.screwdriver.fill"
        case .gear: return "gearshape.fill"
        case .hammer: return "hammer.fill"
        case .circuit: return "memorychip.fill"

        // Social Studies & Business
        case .building: return "building.columns.fill"
        case .chart: return "chart.bar.fill"
        case .scale: return "scale.3d"
        case .banknote: return "banknote.fill"
        case .person: return "person.3.fill"

        // Nature & Environment
        case .leaf: return "leaf.fill"
        case .tree: return "tree.fill"
        case .sun: return "sun.max.fill"
        case .cloud: return "cloud.fill"

        // Creative & Media
        case .camera: return "camera.fill"
        case .photo: return "photo.fill"
        case .video: return "video.fill"
        case .microphone: return "mic.fill"

        // Misc
        case .brain: return "brain.head.profile"
        case .lightbulb: return "lightbulb.fill"
        case .star: return "star.fill"
        case .clock: return "clock.fill"
        }
    }

    var displayName: String {
        switch self {
        // Core Education
        case .book: return "Book"
        case .graduationcap: return "Graduation"
        case .pencil: return "Pencil"
        case .ruler: return "Ruler"
        case .backpack: return "Backpack"
        case .textformat: return "Language"

        // STEM
        case .function: return "Math"
        case .atom: return "Physics"
        case .flask: return "Chemistry"
        case .microscope: return "Biology"
        case .testtube: return "Lab"
        case .dna: return "Genetics"
        case .waveform: return "Signals"
        case .cpu: return "Computing"

        // Arts & Humanities
        case .theatermasks: return "Drama"
        case .paintpalette: return "Art"
        case .music: return "Music"
        case .pianokeys: return "Piano"
        case .paintbrush: return "Design"
        case .film: return "Film"

        // Languages & Literature
        case .globe: return "Geography"
        case .textbook: return "Literature"
        case .quote: return "Speech"
        case .character: return "Languages"

        // Physical Education & Health
        case .sportscourt: return "Sports"
        case .figure: return "PE"
        case .heart: return "Health"
        case .dumbbell: return "Fitness"
        case .basketball: return "Basketball"
        case .swimming: return "Swimming"

        // Technology & Engineering
        case .laptopcomputer: return "Computer"
        case .wrench: return "Workshop"
        case .gear: return "Engineering"
        case .hammer: return "Woodwork"
        case .circuit: return "Electronics"

        // Social Studies & Business
        case .building: return "History"
        case .chart: return "Economics"
        case .scale: return "3D Design"
        case .banknote: return "Finance"
        case .person: return "Sociology"

        // Nature & Environment
        case .leaf: return "Nature"
        case .tree: return "Environment"
        case .sun: return "Astronomy"
        case .cloud: return "Weather"

        // Creative & Media
        case .camera: return "Photo"
        case .photo: return "Gallery"
        case .video: return "Video"
        case .microphone: return "Podcast"

        // Misc
        case .brain: return "Psychology"
        case .lightbulb: return "Ideas"
        case .star: return "Favorite"
        case .clock: return "Study"
        }
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
            icon: .atom,
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
            icon: .microscope,
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
            icon: .function,
            locationId: sampleSchoolId
        )
    ]
}
