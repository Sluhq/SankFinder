import SwiftUI
import CoreLocation

struct BarsListView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var network = NetworkManager.shared
    @ObservedObject private var bridge = NavigationBridge.shared
    @ObservedObject private var history = HistoryManager.shared
    
    @State private var bars: [Lokal] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var selectedFilter: Int = 0 // 0: Vsi, 1: Samo odprto zdaj
    @State private var alertMessage: String?
    
    var filteredBars: [Lokal] {
        var list = bars
        if selectedFilter == 1 {
            list = list.filter { $0.isOpenNow }
        }
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.address.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.bgDark.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 10) {
                    // Iskalnik
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.appMuted)
                        TextField("Išči lokal ali ulico...", text: $searchText)
                            .foregroundColor(.white)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.appMuted)
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.cardDark)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                    
                    // Filter: Vsi vs. Samo odprto zdaj
                    HStack(spacing: 10) {
                        filterButton(title: "Vsi šanki (\(bars.count))", index: 0)
                        filterButton(title: "🟢 Samo odprto zdaj", index: 1)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .beerGold))
                            .scaleEffect(1.3)
                        Spacer()
                    } else if filteredBars.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Text("🍻")
                                .font(.system(size: 48))
                            Text("Ni najdenih lokalov v bližini")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Poskusi spremeniti iskanje ali osvežiti seznam.")
                                .font(.caption)
                                .foregroundColor(.appMuted)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredBars) { bar in
                                barCardRow(bar: bar)
                                    .listRowBackground(Theme.bgDark)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("Šanki v Bližini")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadBars) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.beerGold)
                    }
                }
            }
            .onAppear {
                GlobalSyncManager.shared.reportScreen("Seznam lokalov")
                if bars.isEmpty {
                    loadBars()
                }
            }
        }
        .navigationViewStyle(.stack)
        .alert(item: Binding<AlertItem?>(
            get: { alertMessage.map { AlertItem(message: $0) } },
            set: { _ in alertMessage = nil }
        )) { item in
            Alert(title: Text("ŠankFinder 🍻"), message: Text(item.message), dismissButton: .default(Text("V redu")))
        }
    }
    
    private func filterButton(title: String, index: Int) -> some View {
        Button(action: { selectedFilter = index }) {
            Text(title)
                .font(.caption)
                .fontWeight(selectedFilter == index ? .bold : .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedFilter == index ? Theme.beerGold : Theme.cardDark)
                .foregroundColor(selectedFilter == index ? .black : .white)
                .cornerRadius(12)
        }
    }
    
    private func barCardRow(bar: Lokal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Ime in razdalja
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(bar.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(bar.address)
                        .font(.caption)
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(bar.formattedDistance(from: locationManager.location))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.beerGold)
                    
                    Text("~ \(bar.walkingMinutes(from: locationManager.location)) min peš")
                        .font(.system(size: 10))
                        .foregroundColor(.appMuted)
                }
            }
            
            // Status odprtosti & delovni čas
            HStack(spacing: 8) {
                Text(bar.statusBadge.text)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(bar.statusBadge.isGreen ? Theme.drajvGreen : Theme.drajvRed)
                
                if let hours = bar.openingHours {
                    Text("•  \(hours)")
                        .font(.system(size: 11))
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                }
            }
            
            // Glavni gumbi za ukrepanje (Navigiraj, Klic, Shrani)
            HStack(spacing: 10) {
                // Zeleni navigacijski gumb
                Button(action: {
                    bridge.navigateTo(lokal: bar)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                        Text("Navigiraj peš")
                            .fontWeight(.bold)
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(red: 46/255, green: 125/255, blue: 50/255)) // Zelena #2E7D32
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Klic
                if let phone = bar.phone {
                    Link(destination: URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                            Text("Klic")
                        }
                        .font(.caption)
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.beerGold)
                        .cornerRadius(10)
                    }
                }
                
                // Shrani obisk
                Button(action: {
                    history.addVisit(barName: bar.name, address: bar.address)
                    alertMessage = "Obisk v '\(bar.name)' je zabeležen v Zgodovini!"
                }) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundColor(.beerGold)
                        .padding(10)
                        .background(Theme.surfaceDark)
                        .cornerRadius(10)
                }
            }
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.beerGold.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func loadBars() {
        isLoading = true
        let userPos = locationManager.location ?? LocationManager.defaultCoordinate
        Task {
            do {
                let fetched = try await network.fetchNearbyBars(
                    lat: userPos.latitude,
                    lon: userPos.longitude,
                    radius: 2000,
                    limit: 40
                )
                DispatchQueue.main.async {
                    self.bars = fetched
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

struct AlertItem: Identifiable {
    var id: String { message }
    let message: String
}
