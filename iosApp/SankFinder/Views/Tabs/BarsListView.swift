import SwiftUI
import CoreLocation

struct BarsListView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var network = NetworkManager.shared
    
    @State private var bars: [Lokal] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var selectedBarForRoute: Lokal?
    
    var filteredBars: [Lokal] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return bars
        }
        return bars.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.address.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.bgDark.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 12) {
                    // Iskalna vrstica
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
                    .cornerRadius(12)
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
                            Text("Poskusi povečati radij ali osvežiti lokacijo.")
                                .font(.caption)
                                .foregroundColor(.appMuted)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredBars) { bar in
                                barRow(bar: bar)
                                    .listRowBackground(Theme.cardDark)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("Seznam Šankov")
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
                if bars.isEmpty {
                    loadBars()
                }
            }
        }
    }
    
    private func barRow(bar: Lokal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
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
                
                // Razdalja
                Text(bar.formattedDistance(from: locationManager.location))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.beerGold)
            }
            
            HStack(spacing: 12) {
                if let cuisine = bar.cuisine {
                    Text(cuisine)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.surfaceDark)
                        .foregroundColor(.beerAmber)
                        .cornerRadius(6)
                }
                
                Spacer()
                
                if let phone = bar.phone {
                    Link(destination: URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                            Text("Klic")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.surfaceDark)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.cardDark)
        .cornerRadius(12)
    }
    
    private func loadBars() {
        isLoading = true
        let userPos = locationManager.location ?? LocationManager.defaultCoordinate
        Task {
            do {
                let fetched = try await network.fetchNearbyBars(
                    lat: userPos.latitude,
                    lon: userPos.longitude,
                    radius: 1500,
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
