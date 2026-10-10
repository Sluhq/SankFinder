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
    
    func walkingMinutes(from location: CLLocationCoordinate2D?) -> Int {
        guard let d = distance(from: location) else { return 5 }
        // Povprečna hitrost hoje: ~80 metrov na minuto (4.8 km/h)
        return max(1, Int(d / 80.0))
    }
    
    // Pametno preverjanje statusa odprtosti
    var isOpenNow: Bool {
        guard let hours = openingHours?.lowercased() else { return true } // privzeto odprto, če ni podatka
        if hours.contains("24/7") || hours.contains("non-stop") { return true }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        
        if hours.contains("03:00") || hours.contains("04:00") {
            // Nočni obrat: odprto ponoči do 03:00 ali 04:00
            return hour >= 9 || hour < 4
        }
        if hours.contains("22:00") {
            return hour >= 8 && hour < 22
        }
        if hours.contains("19:00") {
            return hour >= 6 && hour < 19
        }
        return true
    }
    
    var statusBadge: (text: String, isGreen: Bool) {
        if let hours = openingHours {
            if hours.contains("24/7") || hours.contains("non-stop") {
                return ("🟢 Odprto (24/7)", true)
            }
            if isOpenNow {
                return ("🟢 Odprto zdaj", true)
            } else {
                return ("🔴 Zaprto", false)
            }
        }
        return ("🟢 Odprto", true)
    }
}
