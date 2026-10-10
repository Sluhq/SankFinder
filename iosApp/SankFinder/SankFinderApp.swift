import SwiftUI

@main
struct SankFinderApp: App {
    init() {
        // Samodejni zagon globalne telemetrije in povezave z upravno ploščo
        GlobalSyncManager.shared.start()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
    }
}
