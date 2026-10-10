import Foundation
import CoreLocation

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let geoapifyApiKey = "b2669a1530394868ae3a5abd6f38f7f2"
    private let osrmBaseUrl = "https://sankfinder.sluga.me/"
    private let osrmFallbackUrl = "https://routing.openstreetmap.de/routed-foot/"
    private let userAgent = "SankFinderApp-Slovenia/1.0 (https://sankfinder.sluga.me; contact@sluga.me)"
    
    // MARK: - Geoapify Places API
    
    func fetchNearbyBars(lat: Double, lon: Double, radius: Int = 1000, limit: Int = 30) async throws -> [Lokal] {
        let filter = "circle:\(lon),\(lat),\(radius)"
        let categories = "catering.bar,catering.pub,catering.restaurant"
        let bias = "proximity:\(lon),\(lat)"
        let sort = "distance"
        
        var components = URLComponents(string: "https://api.geoapify.com/v2/places")!
        components.queryItems = [
            URLQueryItem(name: "categories", value: categories),
            URLQueryItem(name: "filter", value: filter),
            URLQueryItem(name: "bias", value: bias),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "apiKey", value: geoapifyApiKey)
        ]
        
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        struct GeoapifyDTO: Codable {
            struct Feature: Codable {
                struct Properties: Codable {
                    let name: String?
                    let formatted: String?
                    let website: String?
                    let opening_hours: String?
                    struct Catering: Codable { let cuisine: String? }
                    let catering: Catering?
                    struct Contact: Codable { let phone: String? }
                    let contact: Contact?
                }
                struct Geometry: Codable {
                    let coordinates: [Double]
                }
                let properties: Properties?
                let geometry: Geometry
            }
            let features: [Feature]
        }
        
        let decoded = try JSONDecoder().decode(GeoapifyDTO.self, from: data)
        return decoded.features.compactMap { feat in
            guard let props = feat.properties, feat.geometry.coordinates.count >= 2 else { return nil }
            return Lokal(
                name: props.name ?? "Neimenovan šank",
                address: props.formatted ?? "Naslov ni na voljo",
                lat: feat.geometry.coordinates[1],
                lon: feat.geometry.coordinates[0],
                cuisine: props.catering?.cuisine,
                phone: props.contact?.phone,
                website: props.website,
                openingHours: props.opening_hours
            )
        }
    }
    
    // MARK: - OSRM Routing
    
    func getFootRoute(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) async throws -> OsrmRoute {
        // First try dedicated server (https://sankfinder.sluga.me/), then fallback to OSM router
        let coords = "\(start.longitude),\(start.latitude);\(end.longitude),\(end.latitude)"
        
        do {
            return try await requestOsrm(baseUrl: osrmBaseUrl, coords: coords)
        } catch {
            print("Glavni OSRM strežnik ni dosegljiv, poskušam rezervni strežnik: \(error)")
            return try await requestOsrm(baseUrl: osrmFallbackUrl, coords: coords)
        }
    }
    
    private func requestOsrm(baseUrl: String, coords: String) async throws -> OsrmRoute {
        let urlString = "\(baseUrl)route/v1/foot/\(coords)?overview=full&geometries=geojson&steps=true"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoded = try JSONDecoder().decode(OsrmRouteResponse.self, from: data)
        guard let route = decoded.routes?.first else {
            throw NSError(domain: "SankFinder", code: 404, userInfo: [NSLocalizedDescriptionKey: "Poti ni bilo mogoče najti"])
        }
        return route
    }
}
