import Foundation
import UIKit
import UserNotifications
import CoreLocation

/// Upravlja z dinamičnimi navigacijskimi obvestili na zaklenjenem zaslonu (Lock Screen Live Notification)
/// oblikovanimi natanko po vzoru Google Maps / Apple Maps prikaza (zavoj, metri, ulica, čas in cilj).
class LiveNavigationManager: NSObject {
    static let shared = LiveNavigationManager()
    
    let notificationId = "sankfinder_live_navigation"
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
        let tripText = "Peš \(walkingMin) min (\(distText))"
        
        postOrUpdateNotification(
            title: "↑ \(distText) • Začni pot",
            subtitle: "\(tripText) • Prihod \(etaFormatted)",
            body: "Cilj: \(targetName)",
            arrowSymbol: "↑",
            stepDistText: distText,
            maneuverInstruction: "Začni peš pot do \(targetName)",
            tripText: tripText,
            etaText: etaFormatted,
            targetName: targetName,
            progressFraction: 0.02,
            sound: false
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
        let tripText = "Peš \(walkingMin) min (\(totalDistText))"
        let progress = max(0.02, min(1.0, 1.0 - (remainingDistance / initialTotalDistance)))
        
        let title = "\(arrow) \(stepDistText) • \(maneuverInstruction)"
        let subtitle = "\(tripText) • Prihod \(etaFormatted)"
        let body = "Cilj: \(targetName)"
        
        // Zvočno opozorilo le ob dejanski spremembi zavoja ali v bližini križišča (< 35 m)
        let currentBucket = Int(distanceToManeuver / 50.0)
        let shouldSound = (maneuverInstruction != lastManeuverText) || (distanceToManeuver < 35 && lastDistanceBucket != 0)
        
        self.lastManeuverText = maneuverInstruction
        self.lastDistanceBucket = distanceToManeuver < 35 ? 0 : currentBucket
        
        postOrUpdateNotification(
            title: title,
            subtitle: subtitle,
            body: body,
            arrowSymbol: arrow,
            stepDistText: stepDistText,
            maneuverInstruction: maneuverInstruction,
            tripText: tripText,
            etaText: etaFormatted,
            targetName: targetName,
            progressFraction: progress,
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
        
        let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sank_nav_live_card.png")
        try? FileManager.default.removeItem(at: tempUrl)
        
        WatchConnectivityManager.shared.sendNavigationUpdate(
            targetName: "",
            instruction: "Navigacija končana",
            distanceText: "",
            etaText: "",
            isNavigating: false
        )
    }
    
    // MARK: - Pošiljanje in posodabljanje obvestila z bogato grafično kartico
    
    private func postOrUpdateNotification(
        title: String,
        subtitle: String,
        body: String,
        arrowSymbol: String,
        stepDistText: String,
        maneuverInstruction: String,
        tripText: String,
        etaText: String,
        targetName: String,
        progressFraction: Double,
        sound: Bool
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        if sound {
            content.sound = UNNotificationSound.default
        }
        
        content.categoryIdentifier = "SANKFINDER_NAVIGATION_CATEGORY"
        
        // Ustvari in pripni pravo grafično kartico (Google Maps Lock Screen stil)
        if let cardUrl = renderNavigationCard(
            arrowSymbol: arrowSymbol,
            stepDistText: stepDistText,
            maneuverInstruction: maneuverInstruction,
            tripText: tripText,
            etaText: etaText,
            targetName: targetName,
            progressFraction: progressFraction
        ) {
            if let attachment = try? UNNotificationAttachment(identifier: "nav_card_\(Int(Date().timeIntervalSince1970))", url: cardUrl, options: nil) {
                content.attachments = [attachment]
            }
        }
        
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
    
    /// Riše visokoločljivo vektorsko kartico poteka poti in zavoja po vzoru Google Maps (slika 1 in slika 2)
    private func renderNavigationCard(
        arrowSymbol: String,
        stepDistText: String,
        maneuverInstruction: String,
        tripText: String,
        etaText: String,
        targetName: String,
        progressFraction: Double
    ) -> URL? {
        let width: CGFloat = 360
        let height: CGFloat = 135
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3.0 // Retina ostrina za OLED zaslone iPhone
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            
            // 1. Zunanje temno zaobljeno ozadje kartice
            let cardRect = CGRect(x: 0, y: 0, width: width, height: height)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 18)
            UIColor(red: 24/255, green: 24/255, blue: 28/255, alpha: 1.0).setFill()
            cardPath.fill()
            
            UIColor(white: 1.0, alpha: 0.10).setStroke()
            cardPath.lineWidth = 1.0
            cardPath.stroke()
            
            // 2. Krog za smerno puščico na levi (42x42 pt)
            let circleRect = CGRect(x: 16, y: 14, width: 42, height: 42)
            let circlePath = UIBezierPath(ovalIn: circleRect)
            UIColor(red: 38/255, green: 38/255, blue: 44/255, alpha: 1.0).setFill()
            circlePath.fill()
            
            // Bela smerna puščica znotraj kroga
            let arrowFont = UIFont.systemFont(ofSize: 22, weight: .bold)
            let arrowAttrs: [NSAttributedString.Key: Any] = [
                .font: arrowFont,
                .foregroundColor: UIColor.white
            ]
            let arrowStr = NSAttributedString(string: arrowSymbol, attributes: arrowAttrs)
            let arrowSize = arrowStr.size()
            let arrowPt = CGPoint(
                x: circleRect.midX - arrowSize.width / 2.0,
                y: circleRect.midY - arrowSize.height / 2.0
            )
            arrowStr.draw(at: arrowPt)
            
            // 3. Razdalja do naslednjega zavoja (velika bela pisava)
            let distFont = UIFont.systemFont(ofSize: 22, weight: .heavy)
            let distAttrs: [NSAttributedString.Key: Any] = [
                .font: distFont,
                .foregroundColor: UIColor.white
            ]
            let distStr = NSAttributedString(string: stepDistText, attributes: distAttrs)
            distStr.draw(at: CGPoint(x: 68, y: 13))
            
            // 4. Navodilo naslednjega zavoja (npr. 'Zavijte levo na Goriško ulico')
            let instrFont = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
            let instrAttrs: [NSAttributedString.Key: Any] = [
                .font: instrFont,
                .foregroundColor: UIColor(white: 0.90, alpha: 1.0)
            ]
            let instrRect = CGRect(x: 68, y: 38, width: width - 82, height: 18)
            maneuverInstruction.draw(with: instrRect, options: [.truncatesLastVisibleLine], attributes: instrAttrs, context: nil)
            
            // 5. Ločilna črta
            cg.setStrokeColor(UIColor(white: 1.0, alpha: 0.08).cgColor)
            cg.setLineWidth(1.0)
            cg.move(to: CGPoint(x: 16, y: 66))
            cg.addLine(to: CGPoint(x: width - 16, y: 66))
            cg.strokePath()
            
            // 6. Povzetek poti: čas hoje levo, cilj in prihod desno
            let tripFont = UIFont.systemFont(ofSize: 12.5, weight: .bold)
            let tripAttrs: [NSAttributedString.Key: Any] = [
                .font: tripFont,
                .foregroundColor: UIColor(red: 66/255, green: 133/255, blue: 244/255, alpha: 1.0) // Google Blue
            ]
            tripText.draw(at: CGPoint(x: 16, y: 74), withAttributes: tripAttrs)
            
            let etaFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
            let etaAttrs: [NSAttributedString.Key: Any] = [
                .font: etaFont,
                .foregroundColor: UIColor(white: 0.75, alpha: 1.0)
            ]
            let rightInfo = "\(targetName) • Prihod \(etaText)"
            let rightSize = (rightInfo as NSString).size(withAttributes: etaAttrs)
            let rightX = max(width - 16 - rightSize.width, 160)
            rightInfo.draw(at: CGPoint(x: rightX, y: 74), withAttributes: etaAttrs)
            
            // 7. Zvezna grafična črta napredka (Google Maps Live Progress Bar)
            let barX: CGFloat = 16
            let barY: CGFloat = 104
            let barWidth: CGFloat = width - 32
            let barHeight: CGFloat = 6
            
            // Sivo ozadje proge
            let bgBarPath = UIBezierPath(roundedRect: CGRect(x: barX, y: barY, width: barWidth, height: barHeight), cornerRadius: 3)
            UIColor(red: 42/255, green: 42/255, blue: 48/255, alpha: 1.0).setFill()
            bgBarPath.fill()
            
            // Modri aktivni napredek poti
            let safeProg = max(0.02, min(1.0, progressFraction))
            let fillWidth = barWidth * CGFloat(safeProg)
            let fillBarPath = UIBezierPath(roundedRect: CGRect(x: barX, y: barY, width: fillWidth, height: barHeight), cornerRadius: 3)
            UIColor(red: 26/255, green: 115/255, blue: 232/255, alpha: 1.0).setFill()
            fillBarPath.fill()
            
            // Trenutna točka uporabnika (moder krog z belo obrobo)
            let curX = barX + fillWidth
            let userDotRect = CGRect(x: curX - 6, y: barY - 3, width: 12, height: 12)
            let userDotPath = UIBezierPath(ovalIn: userDotRect)
            UIColor(red: 26/255, green: 115/255, blue: 232/255, alpha: 1.0).setFill()
            userDotPath.fill()
            UIColor.white.setStroke()
            userDotPath.lineWidth = 2.0
            userDotPath.stroke()
            
            // Ciljna točka na desnem robu (zlata pika s šankom)
            let endDotRect = CGRect(x: barX + barWidth - 6, y: barY - 3, width: 12, height: 12)
            let endDotPath = UIBezierPath(ovalIn: endDotRect)
            UIColor(red: 255/255, green: 193/255, blue: 7/255, alpha: 1.0).setFill() // Beer Gold
            endDotPath.fill()
            UIColor.white.setStroke()
            endDotPath.lineWidth = 1.5
            endDotPath.stroke()
        }
        
        let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sank_nav_live_card.png")
        if let data = image.pngData() {
            try? FileManager.default.removeItem(at: tempUrl)
            try? data.write(to: tempUrl)
            return tempUrl
        }
        return nil
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
            return "●"
        } else {
            return "↑"
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
