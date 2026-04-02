import Foundation
import CoreLocation
import CloudKit

struct SavedLocation: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var type: LocationType
    var iconName: String
    var address: String?

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        type: LocationType,
        iconName: String? = nil,
        address: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.type = type
        self.iconName = iconName ?? type.defaultIcon
        self.address = address
    }

    init(
        id: UUID = UUID(),
        name: String,
        coordinate: CLLocationCoordinate2D,
        type: LocationType,
        iconName: String? = nil,
        address: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.type = type
        self.iconName = iconName ?? type.defaultIcon
        self.address = address
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // MARK: - CloudKit Record

    static let recordType = "SavedLocation"

    init?(from record: CKRecord) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let latitude = record["latitude"] as? Double,
              let longitude = record["longitude"] as? Double,
              let typeRaw = record["type"] as? String,
              let type = LocationType(rawValue: typeRaw) else {
            return nil
        }

        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.type = type
        self.iconName = record["iconName"] as? String ?? type.defaultIcon
        self.address = record["address"] as? String
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType)
        record["id"] = id.uuidString
        record["name"] = name
        record["latitude"] = latitude
        record["longitude"] = longitude
        record["type"] = type.rawValue
        record["iconName"] = iconName
        record["address"] = address
        return record
    }

    // MARK: - Distance Calculation

    func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let to = CLLocation(latitude: latitude, longitude: longitude)
        return from.distance(from: to)
    }

    func formattedDistance(from coordinate: CLLocationCoordinate2D) -> String {
        let meters = distance(from: coordinate)
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }

    func isNearby(_ coordinate: CLLocationCoordinate2D, threshold: CLLocationDistance = 100) -> Bool {
        distance(from: coordinate) <= threshold
    }
}

// MARK: - Location Type
enum LocationType: String, Codable, CaseIterable, Identifiable {
    case home
    case school
    case library
    case office
    case other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .home: return "Home"
        case .school: return "School"
        case .library: return "Library"
        case .office: return "Office"
        case .other: return "Other"
        }
    }

    var defaultIcon: String {
        switch self {
        case .home: return "house.fill"
        case .school: return "graduationcap.fill"
        case .library: return "text.book.closed.fill"
        case .office: return "building.2.fill"
        case .other: return "mappin.and.ellipse.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .home: return "orange"
        case .school: return "green"
        case .library: return "blue"
        case .office: return "purple"
        case .other: return "gray"
        }
    }
}

// MARK: - Sample Data
extension SavedLocation {
    static let samples: [SavedLocation] = [
        SavedLocation(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "Home",
            latitude: 37.7749,
            longitude: -122.4194,
            type: .home,
            address: "123 Main Street"
        ),
        SavedLocation(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            name: "School #15",
            latitude: 37.7849,
            longitude: -122.4094,
            type: .school,
            address: "456 Education Ave"
        ),
        SavedLocation(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            name: "Central Library",
            latitude: 37.7799,
            longitude: -122.4144,
            type: .library,
            address: "789 Book Lane"
        )
    ]
}
