import Foundation
import CoreLocation

struct Lokal: Identifiable, Codable, Equatable {
    var id: String { "\(name)_\(lat)_\(lon)" }
    let name: String
    let address: String
    let lat: Double
    let lon: Double
    let cuisine: String?
    let phone: String?
    let website: String?
    let openingHours: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    func distance(from location: CLLocationCoordinate2D?) -> Double? {
        guard let location = location else { return nil }
        let current = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let bar = CLLocation(latitude: lat, longitude: lon)
        return current.distance(from: bar) // meters
    }
    
    func formattedDistance(from location: CLLocationCoordinate2D?) -> String {
        guard let d = distance(from: location) else { return "-- m" }
        if d < 1000 {
            return "\(Int(d)) m"
        } else {
            return String(format: "%.1f km", d / 1000.0)
        }
    }
}
