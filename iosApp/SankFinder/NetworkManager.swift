import Foundation
import CoreLocation

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let geoapifyApiKey = "b2669a1530394868ae3a5abd6f38f7f2"
    private let osrmBaseUrl = "https://sankfinder.sluga.me/"
    private let osrmFallbackUrl = "https://routing.openstreetmap.de/routed-foot/"
    private let userAgent = "SankFinderApp-Slovenia/1.0 (https://sankfinder.sluga.me; contact@sluga.me)"
    
    // Varen URLSession s strogo prisiljenim TLS 1.3 protokolom
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        config.timeoutIntervalForRequest = 10.0
        return URLSession(configuration: config)
    }()
    
    // Deljeno stanje lokalov za celotno aplikacijo (Zemljevid in Seznam lokalov sta vedno 100% usklajena)
    @Published var bars: [Lokal] = []
    @Published var isLoadingBars: Bool = false
    @Published var lastFetchedCoord: CLLocationCoordinate2D? = nil
    @Published var warningMessage: String? = nil
    
    // Zanesljivi prednaloženi lokali v Ljubljani (tudi za Šiško in Bežigrad, 100% usklajeno z Androidom)
    let fallbackLokali: [Lokal] = [
        Lokal(name: "Krakovc", address: "Krakovski nasip 12, 1000 Ljubljana", lat: 46.0468, lon: 14.5042, cuisine: "Coffee_shop, Bar", phone: "+386 64 139 034", website: nil, openingHours: "Mo-Su 08:00-22:00"),
        Lokal(name: "Nostalgija Vintage Cafe", address: "Krakovski nasip 8, 1000 Ljubljana", lat: 46.0461, lon: 14.5045, cuisine: "Bar, Cafe", phone: "+386 1 425 01 22", website: nil, openingHours: "Mo-Su 08:00-01:00"),
        Lokal(name: "Pri Škofu", address: "Rečna ulica 8, 1000 Ljubljana", lat: 46.0452, lon: 14.5036, cuisine: "Gostilna, Bar", phone: "+386 1 426 45 08", website: nil, openingHours: "We-Sa 18:00-23:00; Su 12:00-16:00"),
        Lokal(name: "Pivnica Lajbah", address: "Grudnovo nabrežje 15, 1000 Ljubljana", lat: 46.0438, lon: 14.5074, cuisine: "Pivnica, Craft beer", phone: "+386 1 283 23 88", website: "https://lajbah.com", openingHours: "Mo-Sa 11:00-24:00"),
        Lokal(name: "Sir William's Pub", address: "Tavčarjeva ulica 8a, 1000 Ljubljana", lat: 46.0537, lon: 14.5076, cuisine: "Pub, Beer bar", phone: "+386 1 231 03 40", website: "https://sirwilliams.si", openingHours: "Mo-Sa 08:00-01:00"),
        Lokal(name: "Cutty Sark Pub", address: "Knafljev prehod 1, 1000 Ljubljana", lat: 46.0514, lon: 14.5043, cuisine: "Pub", phone: "+386 1 425 21 83", website: nil, openingHours: "Mo-Su 08:00-01:00"),
        Lokal(name: "Sax Pub", address: "Eipprova ulica 7, 1000 Ljubljana", lat: 46.0435, lon: 14.5029, cuisine: "Jazz Pub", phone: "+386 1 425 01 54", website: nil, openingHours: "Mo-Su 09:00-01:00"),
        Lokal(name: "Pritličje", address: "Mestni trg 25, 1000 Ljubljana", lat: 46.0498, lon: 14.5072, cuisine: "Bar, Club", phone: "+386 1 425 04 44", website: nil, openingHours: "Mo-Su 09:00-01:00"),
        Lokal(name: "Daktari", address: "Krekov trg 7, 1000 Ljubljana", lat: 46.0515, lon: 14.5103, cuisine: "Cafe, Bar", phone: "+386 1 433 01 80", website: nil, openingHours: "Mo-Su 08:00-01:00"),
        Lokal(name: "BiKoFe", address: "Židovska steza 2, 1000 Ljubljana", lat: 46.0496, lon: 14.5048, cuisine: "Bar", phone: "+386 1 251 12 00", website: nil, openingHours: "Mo-Su 08:00-00:00"),
        Lokal(name: "Gostilna Maratonec", address: "Kamniška ulica 28, 1000 Ljubljana", lat: 46.0690, lon: 14.5018, cuisine: "Gostilna, Bar", phone: "+386 1 436 41 80", website: nil, openingHours: "Pon-Sob 10:00-22:00"),
        Lokal(name: "Bar trikotnik", address: "Milčinskega ulica 14, 1000 Ljubljana", lat: 46.0714, lon: 14.4969, cuisine: "Bar, Pijača", phone: nil, website: nil, openingHours: "Pon-Ned 07:00-23:00"),
        Lokal(name: "Pivnica Union", address: "Celovška cesta 22, 1000 Ljubljana", lat: 46.0601, lon: 14.4975, cuisine: "Pivnica, Hrana in pivo", phone: "+386 1 475 21 00", website: "https://pivnica-union.si", openingHours: "Pon-Sob 11:00-24:00"),
        Lokal(name: "Kavarna Tiskarna", address: "Dunajska cesta 123, 1000 Ljubljana", lat: 46.0772, lon: 14.5125, cuisine: "Kavarna, Bar, Burgerji", phone: "+386 70 553 531", website: nil, openingHours: "Pon-Sob 07:00-24:00"),
        Lokal(name: "Lepotica in Zver Bar", address: "Vodnikova cesta 42, 1000 Ljubljana", lat: 46.0652, lon: 14.4851, cuisine: "Bar, Pub", phone: "+386 40 555 444", website: nil, openingHours: "Pon-Ned 08:00-24:00")
    ]
    
    func loadBars(lat: Double, lon: Double, radius: Int = 2000, limit: Int = 25, force: Bool = false) {
        if !force, let last = lastFetchedCoord {
            let loc1 = CLLocation(latitude: lat, longitude: lon)
            let loc2 = CLLocation(latitude: last.latitude, longitude: last.longitude)
            if loc1.distance(from: loc2) < 200.0 && !bars.isEmpty {
                return
            }
        }
        
        isLoadingBars = true
        Task {
            do {
                let fetched = try await fetchNearbyBars(lat: lat, lon: lon, radius: radius, limit: limit)
                DispatchQueue.main.async {
                    if !fetched.isEmpty {
                        self.bars = fetched
                        self.warningMessage = nil
                    } else if self.bars.isEmpty {
                        self.bars = self.fallbackLokali
                    }
                    self.lastFetchedCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    self.isLoadingBars = false
                }
            } catch {
                DispatchQueue.main.async {
                    if self.bars.isEmpty {
                        self.bars = self.fallbackLokali
                    }
                    self.warningMessage = "Ni internetne povezave. Prikazani so shranjeni lokali."
                    self.isLoadingBars = false
                }
            }
        }
    }
    
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
        
        let (data, response) = try await urlSession.data(for: request)
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
        
        let (data, response) = try await urlSession.data(for: request)
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
