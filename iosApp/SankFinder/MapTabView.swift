import SwiftUI
import CoreLocation

struct MapTabView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject private var bridge = NavigationBridge.shared
    @StateObject private var network = NetworkManager.shared
    @ObservedObject private var history = HistoryManager.shared
    @ObservedObject private var squad = SquadManager.shared
    
    @AppStorage("defaultRadiusKm") private var selectedRadiusKm: Int = 2
    @AppStorage("lokalLimit") private var selectedLokalLimit: Int = 25
    @State private var mapHeading: Double = 0.0
    @State private var resetHeadingTrigger: UUID = UUID()
    @State private var centerCoord: CLLocationCoordinate2D?
    @State private var centerTrigger: UUID = UUID()
    @State private var hasInitialCenteredOnUser: Bool = false
    @State private var bars: [Lokal] = []
    @State private var selectedBar: Lokal?
    @State private var activeRoute: OsrmRoute?
    @State private var currentStepIndex: Int = 0
    @AppStorage("defaultRadiusKm") private var selectedRadiusKm: Int = 2
    @State private var errorMessage: String?
    @State private var showAddedToHistoryAlert: Bool = false
    @State private var showSquadSheet: Bool = false
    
    var body: some View {
        ZStack {
            // 1. ZEMLJEVID ČEZ CEL ZASLON
            CustomMapView(
                centerCoordinate: $centerCoord,
                centerTrigger: centerTrigger,
                userHeading: locationManager.heading,
                mapHeading: $mapHeading,
                resetHeadingTrigger: resetHeadingTrigger,
                bars: bars,
                squadMembers: squad.members,
                selectedLokal: selectedBar,
                routeCoordinates: activeRoute?.coordinates ?? [],
                routeSteps: activeRoute?.legs?.first?.steps ?? [],
                currentStepIndex: currentStepIndex,
                onSelectLokal: { bar in
                    selectedBar = bar
                }
            )
            .edgesIgnoringSafeArea(.all)
            
            // 2. KONTROLE IN ZGORNJI / SPODNJI HUD
            VStack(spacing: 8) {
                if let route = activeRoute, let _ = selectedBar ?? bridge.targetLokalForNavigation {
                    // Turn-by-Turn Zgornji Zeleni HUD z možnostjo hitrega skoka v klapo
                    VStack(alignment: .leading, spacing: 6) {
                        navigationTurnHud(route: route)
                        if let room = squad.activeRoom {
                            let squadBeers = squad.members.map { $0.drinksCount }.reduce(0, +)
                            Button(action: { showSquadSheet = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.caption)
                                    Text("Klapa: \(room.code) (\(squad.members.count)) • \(squadBeers) piv")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(Color.beerGold)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.4), radius: 4)
                            }
                            .padding(.leading, 18)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    topControlsBar
                }
                
                Spacer()
                
                // Desni kontrolni stolpec (Plavajoči kompas, Moja Lokacija, Osveži)
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // Plavajoči kompas (prikaže se ko je karta zasukana, tap poravna sever)
                        if abs(mapHeading) > 5.0 && abs(mapHeading - 360.0) > 5.0 {
                            Button(action: { resetHeadingTrigger = UUID() }) {
                                Image(systemName: "location.north.line.fill")
                                    .font(.title3)
                                    .foregroundColor(Theme.drajvRed)
                                    .frame(width: 46, height: 46)
                                    .background(Theme.cardDark)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.4), radius: 4)
                                    .rotationEffect(.degrees(-mapHeading))
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        
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
                    .padding(.bottom, (selectedBar != nil || activeRoute != nil) ? 10 : 85)
                }
                
                // Spodnji Navigation Status HUD (med navigacijo)
                if let route = activeRoute, let target = selectedBar ?? bridge.targetLokalForNavigation {
                    navigationStatusBar(route: route, target: target)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 78)
                } else if let bar = selectedBar {
                    // Spodnja kartica lokala (pred začetkom navigacije)
                    barDetailSheet(bar: bar)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 78)
                }
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .beerGold))
                    .scaleEffect(1.4)
                    .padding(20)
                    .background(Theme.cardDark.opacity(0.85))
                    .cornerRadius(14)
            }
        }
        .onAppear {
            GlobalSyncManager.shared.reportScreen("Zemljevid & Šanki")
            locationManager.requestPermission()
            
            // Če je GPS lokacija že znana, takoj postavi kamero na uporabnika in poišči šanke okoli njega
            if let loc = locationManager.location, locationManager.hasRealLocation {
                hasInitialCenteredOnUser = true
                centerCoord = loc
                centerTrigger = UUID()
                refreshBars()
            } else {
                // Če GPS še pridobiva signal, počakamo na didUpdateLocations, da se kamera ne postavlja napačno v center Ljubljane
                locationManager.startUpdating()
            }
            
            if let target = bridge.targetLokalForNavigation {
                selectedBar = target
                calculateRoute(to: target)
                bridge.targetLokalForNavigation = nil
            }
        }
        .onChange(of: bridge.targetLokalForNavigation) { target in
            if let target = target {
                selectedBar = target
                calculateRoute(to: target)
                bridge.targetLokalForNavigation = nil
            }
        }
        .onChange(of: locationManager.hasRealLocation) { hasReal in
            if hasReal, let loc = locationManager.location, !hasInitialCenteredOnUser {
                hasInitialCenteredOnUser = true
                centerCoord = loc
                centerTrigger = UUID()
                refreshBars()
            }
        }
        .onChange(of: locationManager.location?.latitude) { _ in
            if let loc = locationManager.location {
                SquadManager.shared.updateLocation(lat: loc.latitude, lon: loc.longitude)
                if !hasInitialCenteredOnUser {
                    hasInitialCenteredOnUser = true
                    centerCoord = loc
                    centerTrigger = UUID()
                    refreshBars()
                }
                
                // Posodobi Live Lock Screen obvestilo in Apple Watch prikaz
                if let route = activeRoute, let target = selectedBar ?? bridge.targetLokalForNavigation {
                    updateLiveNavigation(userLocation: loc, route: route, target: target)
                }
            }
        }
        .alert(isPresented: $showAddedToHistoryAlert) {
            Alert(title: Text("Obisk zabeležen"), message: Text("Lokal je bil dodan v tvojo Zgodovino obiskov."), dismissButton: .default(Text("V redu")))
        }
        .sheet(isPresented: $showSquadSheet) {
            SquadView()
        }
        .onChange(of: selectedRadiusKm) { _ in
            refreshBars()
        }
        .onChange(of: selectedLokalLimit) { _ in
            refreshBars()
        }
    }
    
    // MARK: - Zgornja vrstica brez oznake 'ŠankFinder' in brez emojijev
    private var topControlsBar: some View {
        HStack {
            // Oblak Klape levo zgoraj za takojšnji skok v pogovor (kot na Androidu)
            if let room = squad.activeRoom {
                let squadBeers = squad.members.map { $0.drinksCount }.reduce(0, +)
                Button(action: { showSquadSheet = true }) {
                    HStack(spacing: 7) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.subheadline)
                        Text("Klapa: \(room.code) (\(squad.members.count)) • \(squadBeers) piv")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Color.beerGold)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.4), radius: 5)
                }
            } else {
                Spacer().frame(width: 1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Zgornji zeleni Turn-by-Turn HUD (#1B5E20)
    private func navigationTurnHud(route: OsrmRoute) -> some View {
        let steps = route.legs?.first?.steps ?? []
        let currentStep = steps.indices.contains(currentStepIndex) ? steps[currentStepIndex] : steps.first
        
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 48, height: 48)
                
                Image(systemName: maneuverIcon(modifier: currentStep?.maneuver?.modifier))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Int(currentStep?.distance ?? route.distance)) m")
                    .font(.title2)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                
                Text(currentStep?.maneuver?.instructionText ?? "Nadaljujte naravnost")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: { activeRoute = nil; selectedBar = nil }) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(Color(red: 27/255, green: 94/255, blue: 32/255))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.5), radius: 8)
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }
    
    // MARK: - Spodnji statusni navigacijski trak (ETA, metri, cilj)
    private func navigationStatusBar(route: OsrmRoute, target: Lokal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(route.formattedDuration)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 46/255, green: 125/255, blue: 50/255))
                    
                    Text("•  \(route.formattedDistance)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Text("•  \(calculateEta(durationSeconds: route.duration))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.beerGold)
                }
                
                Text("Cilj: \(target.name)")
                    .font(.caption)
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                activeRoute = nil
                selectedBar = nil
                locationManager.setBackgroundMode(active: false)
                LiveNavigationManager.shared.stopNavigation()
            }) {
                Text("Končaj")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.drajvRed)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.6), radius: 8)
    }
    
    // MARK: - Spodnja kartica lokala (pred začetkom navigacije)
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
            
            HStack(spacing: 12) {
                Text(bar.statusBadge.text)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(bar.statusBadge.isGreen ? Theme.drajvGreen : Theme.drajvRed)
                
                Text("•  \(bar.formattedDistance(from: locationManager.location))")
                    .font(.caption)
                    .foregroundColor(.beerGold)
                
                Spacer()
                
                Button(action: {
                    history.addVisit(barName: bar.name, address: bar.address)
                    showAddedToHistoryAlert = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark.fill")
                        Text("Shrani obisk")
                    }
                    .font(.caption2)
                    .foregroundColor(.beerGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.surfaceDark)
                    .cornerRadius(6)
                }
            }
            
            HStack(spacing: 10) {
                Button(action: { calculateRoute(to: bar) }) {
                    HStack {
                        Image(systemName: "figure.walk")
                        Text("Vodi me peš (Navigiraj)")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 46/255, green: 125/255, blue: 50/255))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                if let phone = bar.phone {
                    Link(destination: URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))")!) {
                        Image(systemName: "phone.fill")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Theme.beerGold)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.cardDark)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.6), radius: 10)
    }
    
    // MARK: - Pomožne funkcije
    private func centerOnUser() {
        if let loc = locationManager.location {
            centerCoord = loc
            centerTrigger = UUID()
            if bars.isEmpty {
                refreshBars()
            }
        } else {
            locationManager.requestPermission()
            centerCoord = LocationManager.defaultCoordinate
            centerTrigger = UUID()
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
                    radius: selectedRadiusKm * 1000,
                    limit: selectedLokalLimit
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
                    self.isLoading = false
                    self.locationManager.setBackgroundMode(active: true)
                    let eta = self.calculateEta(durationSeconds: route.duration)
                    LiveNavigationManager.shared.startNavigation(
                        targetName: bar.name,
                        totalDistance: route.distance,
                        etaFormatted: eta
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Napaka pri izračunu poti: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func updateLiveNavigation(userLocation: CLLocationCoordinate2D, route: OsrmRoute, target: Lokal) {
        let steps = route.legs?.first?.steps ?? []
        guard !steps.isEmpty else { return }
        
        // 1. Dinamično napredovanje naslednjega koraka ob približanju ovinku (< 18m)
        let nextIdx = currentStepIndex + 1
        if nextIdx < steps.count {
            let nextStep = steps[nextIdx]
            if let loc = nextStep.maneuver?.location, loc.count >= 2 {
                let maneuverCoord = CLLocationCoordinate2D(latitude: loc[1], longitude: loc[0])
                let distToManeuver = distanceBetweenCoords(userLocation, maneuverCoord)
                
                var shouldAdvance = distToManeuver <= 18.0
                if !shouldAdvance && nextIdx + 1 < steps.count {
                    if let nextNextLoc = steps[nextIdx + 1].maneuver?.location, nextNextLoc.count >= 2 {
                        let nextNextCoord = CLLocationCoordinate2D(latitude: nextNextLoc[1], longitude: nextNextLoc[0])
                        let distToNextNext = distanceBetweenCoords(userLocation, nextNextCoord)
                        if distToNextNext < nextStep.distance * 0.85 && distToManeuver < 35.0 {
                            shouldAdvance = true
                        }
                    }
                }
                if shouldAdvance {
                    self.currentStepIndex = nextIdx
                }
            }
        }
        
        let currentStep = (steps.indices.contains(currentStepIndex)) ? steps[currentStepIndex] : steps.first
        let instruction = currentStep?.maneuver?.instructionText ?? "Nadaljujte naravnost"
        
        // 2. Izračun točne razdalje do naslednjega manevra
        let stepDist: Double
        if let loc = currentStep?.maneuver?.location, loc.count >= 2 {
            let targetManeuver = CLLocationCoordinate2D(latitude: loc[1], longitude: loc[0])
            stepDist = distanceBetweenCoords(userLocation, targetManeuver)
        } else {
            stepDist = currentStep?.distance ?? 50.0
        }
        
        // 3. Točen izračun preostale razdalje po dejanski OSRM trasi
        let remaining = calculateRemainingRouteDistance(userLoc: userLocation, routeCoords: route.coordinates)
        let eta = calculateEta(durationSeconds: max(30, remaining / 1.25))
        
        LiveNavigationManager.shared.updateNavigation(
            targetName: target.name,
            maneuverInstruction: instruction,
            distanceToManeuver: stepDist,
            remainingDistance: remaining,
            etaFormatted: eta
        )
    }

    private func calculateRemainingRouteDistance(userLoc: CLLocationCoordinate2D, routeCoords: [CLLocationCoordinate2D]) -> Double {
        guard routeCoords.count >= 2 else { return 0.0 }
        var closestIdx = 0
        var minD = Double.greatestFiniteMagnitude
        for (i, pt) in routeCoords.enumerated() {
            let d = distanceBetweenCoords(userLoc, pt)
            if d < minD {
                minD = d
                closestIdx = i
            }
        }
        var remaining: Double = minD
        for i in closestIdx..<(routeCoords.count - 1) {
            remaining += distanceBetweenCoords(routeCoords[i], routeCoords[i + 1])
        }
        return remaining
    }

    private func distanceBetweenCoords(_ c1: CLLocationCoordinate2D, _ c2: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: c1.latitude, longitude: c1.longitude)
        let loc2 = CLLocation(latitude: c2.latitude, longitude: c2.longitude)
        return loc1.distance(from: loc2)
    }
    
    private func maneuverIcon(modifier: String?) -> String {
        let mod = modifier?.lowercased() ?? ""
        if mod.contains("left") {
            if mod.contains("sharp") {
                return "arrow.uturn.backward"
            } else if mod.contains("slight") {
                return "arrow.up.left"
            } else {
                return "arrow.turn.up.left"
            }
        } else if mod.contains("right") {
            if mod.contains("sharp") {
                return "arrow.uturn.forward"
            } else if mod.contains("slight") {
                return "arrow.up.right"
            } else {
                return "arrow.turn.up.right"
            }
        } else if mod.contains("u-turn") || mod.contains("uturn") {
            return "arrow.uturn.down"
        } else {
            return "arrow.up"
        }
    }
    
    private func calculateEta(durationSeconds: Double) -> String {
        let etaDate = Date().addingTimeInterval(durationSeconds)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "ETA " + formatter.string(from: etaDate)
    }
}
