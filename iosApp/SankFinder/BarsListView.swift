import SwiftUI
import CoreLocation

struct BarsListView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var network = NetworkManager.shared
    @ObservedObject private var bridge = NavigationBridge.shared
    @ObservedObject private var history = HistoryManager.shared
    
    @AppStorage("defaultRadiusKm") private var selectedRadiusKm: Int = 2
    @AppStorage("lokalLimit") private var selectedLokalLimit: Int = 25
    
    @State private var searchQuery: String = ""
    @State private var selectedFilter: Int = 0 // 0: Vsi, 1: Samo odprto zdaj
    @State private var lastRefreshTime: String = "Pravkar"
    @State private var toastMessage: String? = nil
    
    var filteredBars: [Lokal] {
        var list = network.bars
        if selectedFilter == 1 {
            list = list.filter { $0.isOpenNow }
        }
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchQuery) ||
                $0.address.localizedCaseInsensitiveContains(searchQuery) ||
                ($0.cuisine?.localizedCaseInsensitiveContains(searchQuery) == true)
            }
        }
        return list
    }
    
    var body: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // 1. MATERIAL 3 TOP APP BAR (Identičen Androidu)
                MaterialTopAppBar(title: "Lokali v bližini", actions: {
                    Button(action: { bridge.selectedTab = 2 }) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.beerGold)
                    }
                    
                    Button(action: loadBars) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.beerGold)
                    }
                })
                
                // 2. ISKALNO POLJE IN SUBHEADER
                VStack(spacing: 6) {
                    MaterialOutlinedTextField(text: $searchQuery, placeholder: "Išči lokal ali ulico...")
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    
                    // Subheader vrstica (Radij, Osveženo, Število lokalov)
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Theme.drajvGreen)
                                .frame(width: 8, height: 8)
                            Text("Radij: \(selectedRadiusKm) km")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textMuted)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("Osveženo: \(lastRefreshTime) •")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textMuted)
                            Text("\(filteredBars.count) lokalov")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.beerGold)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 2)
                    
                    // Filter: Vsi vs Samo odprto zdaj
                    HStack(spacing: 8) {
                        MaterialFilterChip(title: "Vsi šanki (\(network.bars.count))", isSelected: selectedFilter == 0) {
                            selectedFilter = 0
                        }
                        
                        MaterialFilterChip(title: "Samo odprto zdaj", isSelected: selectedFilter == 1) {
                            selectedFilter = 1
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    
                    if let warning = network.warningMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "wifi.slash")
                                .font(.caption2)
                            Text(warning)
                                .font(.caption2)
                        }
                        .foregroundColor(Theme.beerGold)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    }
                }
                .padding(.bottom, 6)
                
                // 3. SEZNAM LOKALOV (Material 3 Kartice)
                if network.isLoadingBars && network.bars.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.beerGold))
                            .scaleEffect(1.4)
                        Text("Nalagam šanke v bližini...")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                } else if filteredBars.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "mug.fill")
                            .font(.system(size: 56))
                            .foregroundColor(Theme.beerGold.opacity(0.5))
                        
                        Text("Ni najdenih lokalov")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Poskusi spremeniti iskalni niz ali klikni Osveži.")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button(action: { searchQuery = ""; selectedFilter = 0; loadBars() }) {
                            Text("Pokaži vse")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Theme.beerGold)
                                .cornerRadius(10)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredBars) { bar in
                                materialLokalCard(bar: bar)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 80) // Prostor za BottomNavBar
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            
            // Toast obvestilo
            if let toast = toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.surfaceVariantDark.opacity(0.95))
                        .cornerRadius(20)
                        .shadow(radius: 8)
                        .padding(.bottom, 75)
                }
                .transition(.opacity)
            }
        }
        .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })
        .doneButtonKeyboardToolbar()
        .onAppear {
            GlobalSyncManager.shared.reportScreen("Seznam lokalov")
            locationManager.requestPermission()
            if network.bars.isEmpty {
                loadBars()
            }
        }
        .onReceive(locationManager.$location) { newLoc in
            if let loc = newLoc {
                if network.bars.isEmpty || (network.lastFetchedCoord == nil) {
                    loadBars()
                }
            }
        }
        .onChange(of: selectedRadiusKm) { _ in
            loadBars()
        }
        .onChange(of: selectedLokalLimit) { _ in
            loadBars()
        }
    }
    
    // MARK: - Material 3 LokalCard (Identičen Androidu)
    private func materialLokalCard(bar: Lokal) -> some View {
        let isVisited = history.visits.contains { $0.barName.lowercased() == bar.name.lowercased() }
        
        return VStack(alignment: .leading, spacing: 10) {
            // CARD HEADER: Ikona avatara (42dp) + Ime + Naslov + Status "Obiskano"
            HStack(alignment: .top) {
                // Pub Icon avatar
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.primaryContainerDark)
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: iconForCuisine(name: bar.name, cuisine: bar.cuisine))
                        .font(.system(size: 20))
                        .foregroundColor(Theme.beerGold)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(bar.name)
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.drajvRed)
                        
                        Text(bar.address)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textMuted)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isVisited {
                    Text("Obiskano")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.drajvGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.drajvGreen.opacity(0.15))
                        .cornerRadius(8)
                }
            }
            
            // CUISINE TAGS
            if let cuisine = bar.cuisine {
                HStack(spacing: 6) {
                    ForEach(cuisine.components(separatedBy: ";").prefix(3), id: \.self) { tag in
                        Text(tag.trimmingCharacters(in: .whitespaces).capitalized)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.beerGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.surfaceDark)
                            .cornerRadius(6)
                    }
                    Spacer()
                }
            }
            
            // DETAILS: DELOVNI ČAS & TELEFON
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                    
                    Text(bar.statusBadge.text)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(bar.statusBadge.isGreen ? Theme.drajvGreen : Theme.drajvRed)
                    
                    if let hours = bar.openingHours {
                        Text("• \(hours)")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textMuted)
                            .lineLimit(1)
                    }
                }
                
                if let phone = bar.phone {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textMuted)
                        Text(phone)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
            
            // ACTION BUTTONS ROW (3 gumbi: Navigiraj, Označi, Klic)
            HStack(spacing: 8) {
                // 1. Primarni "Navigiraj" gumb
                Button(action: {
                    bridge.navigateTo(lokal: bar)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 14, weight: .bold))
                        Text("Navigiraj")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Theme.beerGold)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
                
                // 2. Outlined "Označi" / "Ponovni obisk"
                Button(action: {
                    history.addVisit(barName: bar.name, address: bar.address)
                    showToast("Obisk v '\(bar.name)' zabeležen v zgodovino!")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 13))
                        Text(isVisited ? "Ponovni obisk" : "Označi")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundColor(Theme.beerGold)
                    .background(Theme.surfaceDark)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.beerGold.opacity(0.6), lineWidth: 1)
                    )
                }
                
                // 3. Klic gumb (če je številka)
                if let phone = bar.phone {
                    Link(destination: URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))")!) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.beerGold)
                            .frame(width: 44, height: 40)
                            .background(Theme.surfaceDark)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Theme.outlineDark, lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.darkBorder, lineWidth: 1)
        )
    }
    
    private func iconForCuisine(name: String, cuisine: String?) -> String {
        let combined = "\(name) \(cuisine ?? "")".lowercased()
        if combined.contains("cafe") || combined.contains("kav") || combined.contains("coffee") {
            return "cup.and.saucer.fill"
        } else if combined.contains("burger") || combined.contains("pizza") || combined.contains("food") {
            return "fork.knife"
        } else {
            return "mug.fill"
        }
    }
    
    private func showToast(_ msg: String) {
        withAnimation {
            toastMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                toastMessage = nil
            }
        }
    }
    
    private func loadBars() {
        let userPos = locationManager.location ?? LocationManager.defaultCoordinate
        network.loadBars(
            lat: userPos.latitude,
            lon: userPos.longitude,
            radius: selectedRadiusKm * 1000,
            limit: selectedLokalLimit,
            force: true
        )
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        self.lastRefreshTime = formatter.string(from: Date())
    }
}
