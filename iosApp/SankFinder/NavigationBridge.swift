import Foundation
import Combine

class NavigationBridge: ObservableObject {
    static let shared = NavigationBridge()
    
    @Published var selectedTab: Int = 2 // 0: Šanki, 1: Orodja, 2: Zemljevid, 3: Zgodovina, 4: Nastavitve
    @Published var targetLokalForNavigation: Lokal?
    
    func navigateTo(lokal: Lokal) {
        self.targetLokalForNavigation = lokal
        self.selectedTab = 2 // Preklopi na osrednji zavihek Zemljevid
    }
}
