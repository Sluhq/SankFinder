import SwiftUI

@main
struct SankFinderApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark) // Vedno moderna temna tema
        }
    }
}
