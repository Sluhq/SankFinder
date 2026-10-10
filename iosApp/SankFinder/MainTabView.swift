import SwiftUI

struct MainTabView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var globalSync = GlobalSyncManager.shared
    @ObservedObject private var bridge = NavigationBridge.shared
    
    init() {
        // Oblikovanje spodnje vrstice (Dark tema z BeerGold poudarki)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.bgDark)
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(Theme.textMuted)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Theme.textMuted)]
        
        itemAppearance.selected.iconColor = UIColor(Theme.beerGold)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Theme.beerGold)]
        
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $bridge.selectedTab) {
            // 1. Zavihek: ŠANKI (Seznam lokalov z odpiralnimi časi & navigacijo)
            BarsListView(locationManager: locationManager)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Šanki")
                }
                .tag(0)
            
            // 2. Zavihek: ORODJA (Pivska klapa, Burek pavza, Kolo, Ruleta, Bill Splitter, Taksi)
            ToolsView(locationManager: locationManager)
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver.fill")
                    Text("Orodja")
                }
                .tag(1)
            
            // 3. Zavihek: ZEMLJEVID (Osrednji gumb z vodenjem, HUD-om in kompas puščico)
            MapTabView(locationManager: locationManager)
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Zemljevid")
                }
                .tag(2)
            
            // 4. Zavihek: ZGODOVINA (Obiski, računi, statistika porabe)
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Zgodovina")
                }
                .tag(3)
            
            // 5. Zavihek: NASTAVITVE (Čista diagnostika, radij, limit lokalov)
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Nastavitve")
                }
                .tag(4)
        }
        .accentColor(Theme.beerGold)
        .onAppear {
            globalSync.start()
            reportCurrentTab(bridge.selectedTab)
        }
        .onChange(of: bridge.selectedTab) { newTab in
            reportCurrentTab(newTab)
        }
    }
    
    private func reportCurrentTab(_ tab: Int) {
        let name: String
        switch tab {
        case 0: name = "Šanki (Seznam lokalov)"
        case 1: name = "Šank Orodja Hub"
        case 2: name = "Zemljevid & Šanki"
        case 3: name = "Zgodovina obiskov"
        case 4: name = "Nastavitve"
        default: name = "Glavni zaslon"
        }
        globalSync.reportScreen(name)
    }
}
