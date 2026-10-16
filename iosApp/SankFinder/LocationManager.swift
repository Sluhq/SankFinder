import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    // Privzeta koordinata le kot varnostna rezerva, če GPS ni odobren
    static let defaultCoordinate = CLLocationCoordinate2D(latitude: 46.056946, longitude: 14.505751)
    
    @Published var location: CLLocationCoordinate2D? = nil
    @Published var accuracy: CLLocationAccuracy = -1.0
    @Published var hasRealLocation: Bool = false
    @Published var heading: Double = 0.0
    @Published var hasHeading: Bool = false
    @Published var course: Double = -1.0
    @Published var speed: Double = 0.0
    @Published var isAuthorized: Bool = false
    @Published var errorDescription: String?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.distanceFilter = 2.0
        manager.headingFilter = kCLHeadingFilterNone
        
        // Takoj sproži zahtevo za lokacijo ob zagonu
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func startUpdating() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }
    
    /// Omogoča neprekinjeno spremljanje lokacije v ozadju med peš navigacijo
    func setBackgroundMode(active: Bool) {
        if active {
            // Pred vklopom preveri, da je na voljo dovoljenje
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.allowsBackgroundLocationUpdates = true
                manager.showsBackgroundLocationIndicator = true
                manager.pausesLocationUpdatesAutomatically = false
            }
        } else {
            manager.allowsBackgroundLocationUpdates = false
            manager.showsBackgroundLocationIndicator = false
            manager.pausesLocationUpdatesAutomatically = true
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        case .denied, .restricted:
            isAuthorized = false
            errorDescription = "Dostop do lokacije je izklopljen v nastavitvah telefona."
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        // 1. Zavrzi neveljavne koordinate (negativna natančnost)
        guard latest.horizontalAccuracy >= 0 else { return }
        // 2. Zavrzi zelo stare predpomnjene meritve (> 120s)
        guard abs(latest.timestamp.timeIntervalSinceNow) < 120 else { return }
        
        DispatchQueue.main.async {
            self.accuracy = latest.horizontalAccuracy
            self.location = latest.coordinate
            if latest.course >= 0 {
                self.course = latest.course
            }
            self.speed = max(0, latest.speed)
            self.hasRealLocation = true
            self.isAuthorized = true
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let validHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        if validHeading >= 0 {
            DispatchQueue.main.async {
                self.heading = validHeading
                self.hasHeading = true
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("GPS opozorilo: \(error.localizedDescription)")
    }
}
