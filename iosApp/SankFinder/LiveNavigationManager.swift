import Foundation
import UIKit
import UserNotifications
import CoreLocation

/// Upravlja z dinamičnimi navigacijskimi obvestili na zaklenjenem zaslonu (Lock Screen Live Notification)
/// ter obveščanjem na uri Apple Watch med peš navigacijo.
class LiveNavigationManager: NSObject {
    static let shared = LiveNavigationManager()
    
    private let notificationId = "sankfinder_live_navigation"
    private var isNavigating = false
    private var lastManeuverText = ""
    private var lastDistanceBucket: Int = -1
    
    override init() {
        super.init()
    }
    
    /// Začne navigacijsko sejo in prikaže začetno obvestilo na zaklenjenem zaslonu
    func startNavigation(targetName: String, totalDistance: Double, etaFormatted: String) {
        self.isNavigating = true
        self.lastManeuverText = ""
        self.lastDistanceBucket = -1
        
        postOrUpdateNotification(
            title: "🍺 Vodenje do: \(targetName)",
            subtitle: "Pripravljen za pot • \(formatDistance(totalDistance))",
            body: "🎯 Cilj: \(targetName) • ⏱️ \(etaFormatted) peš",
            sound: true
        )
        
        // Sinhronizacija na Apple Watch
        WatchConnectivityManager.shared.sendNavigationUpdate(
            targetName: targetName,
            instruction: "Začni peš pot do šanka",
            distanceText: formatDistance(totalDistance),
            etaText: etaFormatted,
            isNavigating: true
        )
    }
    
    /// Posodobi naslednji zavoj, razdaljo do zavoja in skupno preostalo pot
    func updateNavigation(
        targetName: String,
        maneuverInstruction: String,
        distanceToManeuver: Double,
        remainingDistance: Double,
        etaFormatted: String
    ) {
        guard isNavigating else { return }
        
        let distStepText = formatDistance(distanceToManeuver)
        let totalDistText = formatDistance(remainingDistance)
        
        let subtitle = "\(maneuverInstruction) (\(distStepText))"
        let body = "📏 Še \(totalDistText) • ⏱️ \(etaFormatted) • 🎯 \(targetName)"
        
        // Zvok/haptika le ko se zamenja manever ali ko je uporabnik blizu zavoja (< 30m)
        let currentBucket = Int(distanceToManeuver / 50.0)
        let shouldSound = (maneuverInstruction != lastManeuverText) || (distanceToManeuver < 35 && lastDistanceBucket != 0)
        
        self.lastManeuverText = maneuverInstruction
        self.lastDistanceBucket = distanceToManeuver < 35 ? 0 : currentBucket
        
        postOrUpdateNotification(
            title: "🍺 Navigacija: \(targetName)",
            subtitle: subtitle,
            body: body,
            sound: shouldSound
        )
        
        // Sinhronizacija na Apple Watch
        WatchConnectivityManager.shared.sendNavigationUpdate(
            targetName: targetName,
            instruction: maneuverInstruction,
            distanceText: distStepText,
            etaText: etaFormatted,
            isNavigating: true
        )
    }
    
    /// Ko uporabnik prispe ali klikne 'Končaj navigacijo'
    func stopNavigation() {
        self.isNavigating = false
        self.lastManeuverText = ""
        self.lastDistanceBucket = -1
        
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        
        // Obvesti Apple Watch, da je navigacija končana
        WatchConnectivityManager.shared.sendNavigationUpdate(
            targetName: "",
            instruction: "Navigacija končana",
            distanceText: "",
            etaText: "",
            isNavigating: false
        )
    }
    
    // MARK: - Pošiljanje in posodabljanje obvestila
    
    private func postOrUpdateNotification(title: String, subtitle: String, body: String, sound: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        if sound {
            content.sound = UNNotificationSound.default
        }
        
        // Kategorija za hitre gumbe (če uporabnik potegne obvestilo)
        content.categoryIdentifier = "SANKFINDER_NAVIGATION_CATEGORY"
        
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: nil // Takojšnji prikaz
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Napaka pri prikazu navigacijskega obvestila: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            return String(format: "%.1f km", meters / 1000.0)
        }
    }
}
