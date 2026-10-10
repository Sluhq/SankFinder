import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var location: CLLocationCoordinate2D?
    @Published var heading: Double = 0.0
    @Published var isAuthorized: Bool = false
    @Published var errorDescription: String?
    
    // Default location fallback (Ljubljana Center)
    static let defaultCoordinate = CLLocationCoordinate2D(latitude: 46.056946, longitude: 14.505751)
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5.0 // Update every 5 meters
        manager.headingFilter = 5.0  // Update every 5 degrees
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }
    
    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            startUpdating()
        case .denied, .restricted:
            isAuthorized = false
            errorDescription = "Dostop do lokacije je onemogočen."
        case .notDetermined:
            requestPermission()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        DispatchQueue.main.async {
            self.location = latest.coordinate
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
        DispatchQueue.main.async {
            self.errorDescription = error.localizedDescription
        }
    }
}
