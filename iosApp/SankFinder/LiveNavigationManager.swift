import Foundation
import UIKit
import UserNotifications
import CoreLocation

/// Upravlja z dinamičnimi navigacijskimi obvestili na zaklenjenem zaslonu (Lock Screen Live Notification)
/// oblikovanimi natanko po vzoru Google Maps / Apple Maps prikaza (zavoj, metri, ulica, čas in cilj).
class LiveNavigationManager: NSObject {
    static let shared = LiveNavigationManager()
    
    private let notificationId = "sankfinder_live_navigation"
    private var isNavigating = false
    private var initialTotalDistance: Double = 1.0
    private var lastManeuverText = ""
    private var lastDistanceBucket: Int = -1
    
    override init() {
        super.init()
    }
    
    /// Začne navigacijsko sejo in prikaže začetno obvestilo na zaklenjenem zaslonu
    func startNavigation(targetName: String, totalDistance: Double, etaFormatted: String) {
        self.isNavigating = true
        self.initialTotalDistance = max(totalDistance, 1.0)
        self.lastManeuverText = ""
        self.lastDistanceBucket = -1
        
        let distText = formatDistance(totalDistance)
        let walkingMin = max(1, Int(ceil(totalDistance / 80.0)))
        
        postOrUpdateNotification(
            title: "↑ \(distText)",
            subtitle: "Začni peš pot do: \(targetName)",
            body: "Peš \(walkingMin) min (\(distText)) • Prihod \(etaFormatted) • 🎯 \(targetName)",
            sound: true
        )
        
        WatchConnectivityManager.shared.sendNavigationUpdate(
            targetName: targetName,
            instruction: "Začni pot do \(targetName)",
            distanceText: distText,
            etaText: etaFormatted,
            isNavigating: true
        )
    }
    
    /// Posodobi naslednji zavoj, razdaljo do zavoja in preostalo pot (100% po vzoru Lock Screen Live Activities)
    func updateNavigation(
        targetName: String,
        maneuverInstruction: String,
        distanceToManeuver: Double,
        remainingDistance: Double,
        etaFormatted: String
    ) {
        guard isNavigating else { return }
        
        let arrow = getManeuverSymbol(instruction: maneuverInstruction)
        let stepDistText = formatDistance(distanceToManeuver)
        let totalDistText = formatDistance(remainingDistance)
        let walkingMin = max(1, Int(ceil(remainingDistance / 80.0)))
        
        // Naslov: Velika smerna puščica in razdalja do zavoja (npr. '↰ 600 m')
        let title = "\(arrow)  \(stepDistText)"
        
        // Podnaslov: Ime ulice ali navodilo zavoja (npr. 'Zavijte levo na Goriško ulico')
        let subtitle = maneuverInstruction
        
        // Telo: Čas hoje, preostala razdalja, predviden prihod in ime lokala
        let progressBar = makeProgressBar(remaining: remainingDistance, total: initialTotalDistance)
        let body = "Peš \(walkingMin) min (\(totalDistText)) • Prihod \(etaFormatted)\n\(progressBar)  🎯 \(targetName)"
        
        // Zvočno in haptično opozorilo ob spremembi zavoja ali v bližini križišča (< 35 m)
        let currentBucket = Int(distanceToManeuver / 50.0)
        let shouldSound = (maneuverInstruction != lastManeuverText) || (distanceToManeuver < 35 && lastDistanceBucket != 0)
        
        self.lastManeuverText = maneuverInstruction
        self.lastDistanceBucket = distanceToManeuver < 35 ? 0 : currentBucket
        
        postOrUpdateNotification(
            title: title,
            subtitle: subtitle,
            body: body,
            sound: shouldSound
        )
        
        WatchConnectivityManager.shared.sendNavigationUpdate(
            targetName: targetName,
            instruction: "\(arrow) \(maneuverInstruction)",
            distanceText: stepDistText,
            etaText: etaFormatted,
            isNavigating: true
        )
    }
    
    /// Ko uporabnik prispe ali klikne 'Končaj'
    func stopNavigation() {
        self.isNavigating = false
        self.lastManeuverText = ""
        self.lastDistanceBucket = -1
        
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        
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
        
        content.categoryIdentifier = "SANKFINDER_NAVIGATION_CATEGORY"
        
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: nil // Takojšen prikaz na zaklenjenem zaslonu
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Napaka pri prikazu navigacijskega obvestila: \(error.localizedDescription)")
            }
        }
    }
    
    private func getManeuverSymbol(instruction: String) -> String {
        let low = instruction.lowercased()
        if low.contains("levo") || low.contains("left") {
            if low.contains("ostro") || low.contains("sharp") {
                return "⮌"
            } else if low.contains("rahlo") || low.contains("slight") {
                return "↖"
            } else {
                return "↰"
            }
        } else if low.contains("desno") || low.contains("right") {
            if low.contains("ostro") || low.contains("sharp") {
                return "⮎"
            } else if low.contains("rahlo") || low.contains("slight") {
                return "↗"
            } else {
                return "↱"
            }
        } else if low.contains("polkrožno") || low.contains("u-turn") || low.contains("uturn") {
            return "↩"
        } else if low.contains("cilj") || low.contains("prispe") || low.contains("arrive") {
            return "🎯"
        } else {
            return "↑"
        }
    }
    
    private func makeProgressBar(remaining: Double, total: Double) -> String {
        guard total > 0 else { return "●━━━━━━○" }
        let progress = max(0.0, min(1.0, 1.0 - (remaining / total)))
        let steps = 6
        let filled = Int(round(progress * Double(steps)))
        var bar = ""
        for i in 0...steps {
            if i == filled {
                bar += "●"
            } else {
                bar += "━"
            }
        }
        return bar + "○"
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            return String(format: "%.1f km", meters / 1000.0)
        }
    }
}
