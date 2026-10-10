import SwiftUI
import CoreLocation

struct MapTabView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var network = NetworkManager.shared
    
    @State private var centerCoord: CLLocationCoordinate2D?
    @State private var bars: [Lokal] = []
    @State private var selectedBar: Lokal?
    @State private var activeRoute: OsrmRoute?
    @State private var currentStepIndex: Int = 0
    @State private var isLoading: Bool = false
    @State private var searchRadius: Int = 1000 // 1 km
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // 1. ZEMLJEVID (OpenStreetMap / Carto Voyager)
            CustomMapView(
                centerCoordinate: $centerCoord,
                bars: bars,
                selectedLokal: selectedBar,
                routeCoordinates: activeRoute?.coordinates ?? [],
                onSelectLokal: { bar in
                    selectedBar = bar
                }
            )
            .edgesIgnoringSafeArea(.all)
            
            // 2. ZGORNJI ELEMENTI (Iskalnik, Radius, Orodna vrstica)
            VStack(spacing: 8) {
                topBar
                
                if let route = activeRoute {
                    navigationBanner(route: route)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // 3. SPODNJI ELEMENTI (Gumbi & Detajli lokala)
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Button(action: centerOnUser) {
                            Image(systemName: "location.fill")
                                .font(.title3)
                                .foregroundColor(.beerGold)
                                .frame(width: 46, height: 46)
                                .background(Theme.cardDark)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.4), radius: 4)
                        }
                        
                        Button(action: refreshBars) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                                .foregroundColor(.beerGold)
                                .frame(width: 46, height: 46)
                                .background(Theme.cardDark)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.4), radius: 4)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, selectedBar != nil ? 10 : 80)
                }
                
                if let bar = selectedBar {
                    barDetailSheet(bar: bar)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 12)
                        .padding(.bottom, 60)
                }
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .beerGold))
                    .scaleEffect(1.5)
                    .padding(20)
                    .background(Theme.cardDark.opacity(0.85))
                    .cornerRadius(12)
            }
        }
        .onAppear {
            GlobalSyncManager.shared.reportScreen("Zemljevid & Šanki")
            locationManager.requestPermission()
            refreshBars()
        }
        .onChange(of: locationManager.location?.latitude) { _ in
            if let loc = locationManager.location {
                SquadManager.shared.updateLocation(lat: loc.latitude, lon: loc.longitude)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                Text("🍺")
                    .font(.title2)
                Text("ŠankFinder")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.cardDark.opacity(0.92))
            .cornerRadius(20)
            .shadow(radius: 4)
            
            Spacer()
            
            // Izbira radija
            Menu {
                Button("500 m") { searchRadius = 500; refreshBars() }
                Button("1 km (Privzeto)") { searchRadius = 1000; refreshBars() }
                Button("2 km") { searchRadius = 2000; refreshBars() }
                Button("5 km") { searchRadius = 5000; refreshBars() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                    Text("\(searchRadius < 1000 ? "\(searchRadius)m" : "\(searchRadius/1000)km")")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.beerGold)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.cardDark.opacity(0.92))
                .cornerRadius(20)
                .shadow(radius: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private func navigationBanner(route: OsrmRoute) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "figure.walk")
                    .font(.title2)
                    .foregroundColor(.beerGold)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(route.formattedDuration)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Preostanek poti: \(route.formattedDistance)")
                        .font(.subheadline)
                        .foregroundColor(.appMuted)
                }
                
                Spacer()
                
                Button(action: { activeRoute = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.drajvRed)
                }
            }
            
            if let legs = route.legs, let steps = legs.first?.steps, !steps.isEmpty {
                let currentStep = steps[min(currentStepIndex, steps.count - 1)]
                HStack {
                    Image(systemName: "arrow.turn.up.right")
                        .foregroundColor(.beerGold)
                    Text(currentStep.maneuver?.instructionText ?? "Nadaljujte")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    if let name = currentStep.name, !name.isEmpty {
                        Text("(\(name))")
                            .font(.caption)
                            .foregroundColor(.appMuted)
                    }
                    Spacer()
                    Text("\(Int(currentStep.distance)) m")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.beerGold)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.beerGold.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .shadow(radius: 6)
    }
    
    private func barDetailSheet(bar: Lokal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(bar.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(bar.address)
                        .font(.subheadline)
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: { selectedBar = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            
            HStack {
                Label(bar.formattedDistance(from: locationManager.location), systemImage: "figure.walk")
                    .font(.caption)
                    .foregroundColor(.beerGold)
                
                if let cuisine = bar.cuisine {
                    Text("•  \(cuisine)")
                        .font(.caption)
                        .foregroundColor(.appMuted)
                }
                
                Spacer()
                
                if let phone = bar.phone {
                    Link(destination: URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))")!) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.beerGold)
                            .padding(8)
                            .background(Theme.surfaceDark)
                            .clipShape(Circle())
                    }
                }
            }
            
            // Gumb za zagon OSRM peš navigacije
            Button(action: { calculateRoute(to: bar) }) {
                HStack {
                    Image(systemName: "location.north.line.fill")
                    Text("Vodi me peš (OSRM)")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.beerGold)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Theme.cardDark)
        .cornerRadius(20)
        .shadow(radius: 10)
    }
    
    // MARK: - Actions
    
    private func centerOnUser() {
        if let loc = locationManager.location {
            centerCoord = loc
        } else {
            centerCoord = LocationManager.defaultCoordinate
        }
    }
    
    private func refreshBars() {
        isLoading = true
        let userPos = locationManager.location ?? LocationManager.defaultCoordinate
        
        Task {
            do {
                let fetched = try await network.fetchNearbyBars(
                    lat: userPos.latitude,
                    lon: userPos.longitude,
                    radius: searchRadius,
                    limit: 35
                )
                DispatchQueue.main.async {
                    self.bars = fetched
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func calculateRoute(to bar: Lokal) {
        isLoading = true
        let userPos = locationManager.location ?? LocationManager.defaultCoordinate
        let dest = bar.coordinate
        
        Task {
            do {
                let route = try await network.getFootRoute(start: userPos, end: dest)
                DispatchQueue.main.async {
                    self.activeRoute = route
                    self.currentStepIndex = 0
                    self.selectedBar = nil // zapri sheet in odpri navigation banner
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Napaka pri izračunu poti: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}
