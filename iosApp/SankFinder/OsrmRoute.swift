import Foundation
import CoreLocation

struct OsrmRouteResponse: Codable {
    let code: String
    let routes: [OsrmRoute]?
}

struct OsrmRoute: Codable {
    let distance: Double
    let duration: Double
    let geometry: OsrmGeometry?
    let legs: [OsrmLeg]?
    
    var coordinates: [CLLocationCoordinate2D] {
        guard let coords = geometry?.coordinates else { return [] }
        // GeoJSON coordinates are [longitude, latitude]
        return coords.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
    }
    
    var formattedDuration: String {
        let minutes = Int(duration / 60.0)
        if minutes < 60 {
            return "\(minutes) min peš"
        } else {
            let hours = minutes / 60
            let remMin = minutes % 60
            return "\(hours) h \(remMin) min peš"
        }
    }
    
    var formattedDistance: String {
        if distance < 1000 {
            return "\(Int(distance)) m"
        } else {
            return String(format: "%.1f km", distance / 1000.0)
        }
    }
}

struct OsrmGeometry: Codable {
    let coordinates: [[Double]]
    let type: String
}

struct OsrmLeg: Codable {
    let distance: Double
    let duration: Double
    let summary: String?
    let steps: [OsrmStep]?
}

struct OsrmStep: Codable, Identifiable {
    var id: String { "\(name ?? "")_\(distance)_\(duration)" }
    let distance: Double
    let duration: Double
    let name: String?
    let mode: String?
    let maneuver: OsrmManeuver?
}

struct OsrmManeuver: Codable {
    let location: [Double]?
    let type: String?
    let modifier: String?
    let bearing_after: Int?
    let bearing_before: Int?
    
    var bearingBefore: Double { Double(bearing_before ?? 0) }
    var bearingAfter: Double { Double(bearing_after ?? 0) }
    
    var instructionText: String {
        let mod = modifier ?? ""
        let t = type ?? "turn"
        switch (t, mod) {
        case ("depart", _):
            return "Začnite pot"
        case ("arrive", _):
            return "Prispeli ste na cilj!"
        case ("turn", "left"):
            return "Zavijte levo"
        case ("turn", "right"):
            return "Zavijte desno"
        case ("turn", "slight left"):
            return "Rahlo levo"
        case ("turn", "slight right"):
            return "Rahlo desno"
        case ("turn", "sharp left"):
            return "Ostro levo"
        case ("turn", "sharp right"):
            return "Ostro desno"
        case ("continue", _):
            return "Nadaljujte naravnost"
        default:
            return mod.isEmpty ? "Nadaljujte" : "Zavijte \(mod)"
        }
    }
}
