import Foundation
import WatchConnectivity
import Combine

/// Upravlja povezavo med iPhone aplikacijo ŠankFinder in uro Apple Watch preko WatchConnectivity
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    @Published var isSupported: Bool = false
    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var lastMessageFromWatch: String?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            self.isSupported = true
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    /// Pošlje stanje navigacije na uro Apple Watch
    func sendNavigationUpdate(
        targetName: String,
        instruction: String,
        distanceText: String,
        etaText: String,
        isNavigating: Bool
    ) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        
        let context: [String: Any] = [
            "targetName": targetName,
            "instruction": instruction,
            "distance": distanceText,
            "eta": etaText,
            "isNavigating": isNavigating,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("Napaka pri posodabljanju Apple Watch konteksta: \(error.localizedDescription)")
        }
        
        // Če je ura dosegljiva v živo (reachable), pošlji neposredno sporočilo za takojšen odziv
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil) { err in
                print("Napaka pri neposrednem prenosu na uro: \(err.localizedDescription)")
            }
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Ob preklopu ure
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Ponovno aktiviraj sejo za novo uro
        WCSession.default.activate()
    }
    
    // Prejem ukazov z ure Apple Watch (npr. 'stop_nav' ali 'quick_beer')
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            if let action = message["action"] as? String {
                self.lastMessageFromWatch = action
                if action == "stop_navigation" {
                    LiveNavigationManager.shared.stopNavigation()
                    replyHandler(["status": "ok"])
                    return
                }
            }
            replyHandler(["status": "received"])
        }
    }
}
