import SwiftUI

struct MainTabView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var selectedTab = 0
    
    init() {
        // Oblikovanje spodnje vrstice
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
        TabView(selection: $selectedTab) {
            MapTabView(locationManager: locationManager)
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Zemljevid")
                }
                .tag(0)
            
            BarsListView(locationManager: locationManager)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Lokali")
                }
                .tag(1)
            
            GamesView()
                .tabItem {
                    Image(systemName: "die.face.5.fill")
                    Text("Igre")
                }
                .tag(2)
            
            SquadView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Klapa")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Nastavitve")
                }
                .tag(4)
        }
        .accentColor(Theme.beerGold)
    }
}
