import SwiftUI

struct MainTabView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var globalSync = GlobalSyncManager.shared
    @ObservedObject private var bridge = NavigationBridge.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. AKTIVNI ZASLON (0: Šanki, 1: Orodja, 2: Zemljevid, 3: Zgodovina, 4: Nastavitve)
            Group {
                switch bridge.selectedTab {
                case 0:
                    BarsListView(locationManager: locationManager)
                case 1:
                    ToolsView(locationManager: locationManager)
                case 2:
                    MapTabView(locationManager: locationManager)
                case 3:
                    HistoryView()
                case 4:
                    SettingsView()
                default:
                    BarsListView(locationManager: locationManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 2. MATERIAL 3 BOTTOM NAV BAR (Identičen Android BottomNavigation.kt z 18dp zaobljenim vrhom in zlatim krogom)
            MaterialBottomNavBar(selectedIndex: $bridge.selectedTab)
            
            // 3. VIZUALNA PASICA ZA OBVESTILO UPRAVE NA VRHU ZASLONA (Kot na Androidu)
            if let alert = globalSync.activePushAlert {
                VStack {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(alert.title)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.beerGold)
                            Text(alert.message)
                                .font(.caption)
                                .foregroundColor(.white)
                                .lineLimit(3)
                        }
                        Spacer()
                        Button(action: {
                            withAnimation {
                                globalSync.activePushAlert = nil
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(14)
                    .background(Theme.cardDark)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.beerGold.opacity(0.6), lineWidth: 1.2)
                    )
                    .shadow(color: .black.opacity(0.55), radius: 8, y: 3)
                    .padding(.horizontal, 16)
                    .padding(.top, 46)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(), value: globalSync.activePushAlert?.id)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
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
