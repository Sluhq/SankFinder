import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    // Privzeta koordinata le kot varnostna rezerva, če GPS ni odobren
    static let defaultCoordinate = CLLocationCoordinate2D(latitude: 46.056946, longitude: 14.505751)
    
    @Published var location: CLLocationCoordinate2D? = nil
    @Published var hasRealLocation: Bool = false
    @Published var heading: Double = 0.0
    @Published var isAuthorized: Bool = false
    @Published var errorDescription: String?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 3.0
        manager.headingFilter = 3.0
        
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
        DispatchQueue.main.async {
            self.location = latest.coordinate
            self.hasRealLocation = true
            self.isAuthorized = true
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy >= 0 {
            DispatchQueue.main.async {
                self.heading = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("GPS opozorilo: \(error.localizedDescription)")
    }
}
