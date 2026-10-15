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
    @State private var hasAccurateCenter: Bool = false
    @State private var selectedBar: Lokal?
    @State private var activeRoute: OsrmRoute?
    @State private var currentStepIndex: Int = 0
    @State private var distanceToNextStep: Double = 0.0
    @State private var isFollowingUser: Bool = true
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showAddedToHistoryAlert: Bool = false
    @State private var showSquadSheet: Bool = false
    
    var body: some View {
        ZStack {
            // 1. ZEMLJEVID ČEZ CEL ZASLON
            CustomMapView(
                centerCoordinate: $centerCoord,
                centerTrigger: centerTrigger,
                userHeading: (locationManager.speed >= 0.5 && locationManager.course >= 0) ? locationManager.course : locationManager.heading,
                mapHeading: $mapHeading,
                resetHeadingTrigger: resetHeadingTrigger,
                bars: network.bars,
                squadMembers: squad.members,
                selectedLokal: selectedBar,
                routeCoordinates: activeRoute?.coordinates ?? [],
                routeSteps: activeRoute?.legs?.first?.steps ?? [],
                currentStepIndex: currentStepIndex,
                isNavigating: activeRoute != nil,
                isFollowingUser: $isFollowingUser,
                userLocation: locationManager.location,
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
                
                // Gumb za ponovno osredotočenje in usmeritev kamere v smeri hoje (Google Maps slog)
                if activeRoute != nil && !isFollowingUser {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isFollowingUser = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Centriraj")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.beerGold)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 4)
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
            
            if network.isLoadingBars && network.bars.isEmpty {
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
            
            if let loc = locationManager.location, locationManager.hasRealLocation {
                centerCoord = loc
                centerTrigger = UUID()
                if locationManager.accuracy > 0 && locationManager.accuracy <= 65.0 {
                    hasAccurateCenter = true
                }
                network.loadBars(lat: loc.latitude, lon: loc.longitude, radius: selectedRadiusKm * 1000, limit: selectedLokalLimit)
            } else {
                locationManager.startUpdating()
                if network.bars.isEmpty {
                    let fallback = LocationManager.defaultCoordinate
                    network.loadBars(lat: fallback.latitude, lon: fallback.longitude, radius: selectedRadiusKm * 1000, limit: selectedLokalLimit)
                }
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
        .onReceive(locationManager.$location) { newLoc in
            guard let loc = newLoc else { return }
            SquadManager.shared.updateLocation(lat: loc.latitude, lon: loc.longitude)
            
            let isAccurate = (locationManager.accuracy > 0 && locationManager.accuracy <= 65.0)
            if !hasInitialCenteredOnUser || (!hasAccurateCenter && isAccurate) {
                hasInitialCenteredOnUser = true
                if isAccurate {
                    hasAccurateCenter = true
                }
                centerCoord = loc
                centerTrigger = UUID()
                network.loadBars(lat: loc.latitude, lon: loc.longitude, radius: selectedRadiusKm * 1000, limit: selectedLokalLimit)
            } else {
                if let last = network.lastFetchedCoord {
                    let dist = distanceBetweenCoords(loc, last)
                    if dist > 250.0 {
                        network.loadBars(lat: loc.latitude, lon: loc.longitude, radius: selectedRadiusKm * 1000, limit: selectedLokalLimit)
                    }
                } else {
                    network.loadBars(lat: loc.latitude, lon: loc.longitude, radius: selectedRadiusKm * 1000, limit: selectedLokalLimit)
                }
            }
            
            // Posodobi Live Lock Screen obvestilo in Apple Watch prikaz ter navigacijski korak
            if let route = activeRoute, let target = selectedBar ?? bridge.targetLokalForNavigation {
                updateLiveNavigation(userLocation: loc, route: route, target: target)
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
        let currentStep = getUpcomingStep(steps: steps)
        let displayManeuverText = currentStep?.maneuver?.instructionText ?? "Nadaljujte naravnost"
        let displayDist = max(0, Int(distanceToNextStep > 0 ? distanceToNextStep : (currentStep?.distance ?? route.distance)))
        
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
                Text("\(displayDist) m")
                    .font(.title2)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                
                Text(displayManeuverText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: {
                activeRoute = nil
                selectedBar = nil
                isFollowingUser = true
                locationManager.setBackgroundMode(active: false)
                LiveNavigationManager.shared.stopNavigation()
            }) {
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
                isFollowingUser = true
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
            network.loadBars(lat: loc.latitude, lon: loc.longitude, radius: selectedRadiusKm * 1000, limit: selectedLokalLimit, force: true)
        } else {
            locationManager.requestPermission()
            let def = LocationManager.defaultCoordinate
            centerCoord = def
            centerTrigger = UUID()
            network.loadBars(lat: def.latitude, lon: def.longitude, radius: selectedRadiusKm * 1000, limit: selectedLokalLimit, force: true)
        }
    }
    
    private func refreshBars() {
        let userPos = locationManager.location ?? LocationManager.defaultCoordinate
        network.loadBars(lat: userPos.latitude, lon: userPos.longitude, radius: selectedRadiusKm * 1000, limit: selectedLokalLimit, force: true)
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
                    self.isFollowingUser = true
                    self.isLoading = false
                    self.locationManager.setBackgroundMode(active: true)
                    
                    let steps = route.legs?.first?.steps ?? []
                    let upcoming = self.getUpcomingStep(steps: steps)
                    if let loc = upcoming?.maneuver?.location, loc.count >= 2 {
                        let maneuverCoord = CLLocationCoordinate2D(latitude: loc[1], longitude: loc[0])
                        self.distanceToNextStep = self.distanceBetweenCoords(userPos, maneuverCoord)
                    } else {
                        self.distanceToNextStep = upcoming?.distance ?? route.distance
                    }
                    
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
    
    private func getUpcomingStep(steps: [OsrmStep]) -> OsrmStep? {
        guard !steps.isEmpty else { return nil }
        let upcomingIdx = currentStepIndex + 1
        return upcomingIdx < steps.count ? steps[upcomingIdx] : steps.last
    }
    
    private func updateLiveNavigation(userLocation: CLLocationCoordinate2D, route: OsrmRoute, target: Lokal) {
        let steps = route.legs?.first?.steps ?? []
        guard !steps.isEmpty else { return }
        
        // 1. Preveri razdaljo do končnega cilja
        let destCoord = target.coordinate
        let distToGoal = distanceBetweenCoords(userLocation, destCoord)
        if distToGoal <= 15.0 {
            // Cilj dosežen
            self.distanceToNextStep = 0.0
            LiveNavigationManager.shared.stopNavigation()
            return
        }
        
        // 2. Dinamično napredovanje naslednjega koraka ob približanju ovinku (< 20m) ali rezanju ovinka
        let upcomingIdx = currentStepIndex + 1
        if upcomingIdx < steps.count {
            let upcomingStep = steps[upcomingIdx]
            if let loc = upcomingStep.maneuver?.location, loc.count >= 2 {
                let maneuverCoord = CLLocationCoordinate2D(latitude: loc[1], longitude: loc[0])
                let distToUpcoming = distanceBetweenCoords(userLocation, maneuverCoord)
                self.distanceToNextStep = distToUpcoming
                
                var shouldAdvance = distToUpcoming <= 20.0
                if !shouldAdvance && upcomingIdx + 1 < steps.count {
                    if let nextNextLoc = steps[upcomingIdx + 1].maneuver?.location, nextNextLoc.count >= 2 {
                        let nextNextCoord = CLLocationCoordinate2D(latitude: nextNextLoc[1], longitude: nextNextLoc[0])
                        let distToNextNext = distanceBetweenCoords(userLocation, nextNextCoord)
                        let stepDistance = upcomingStep.distance
                        if distToNextNext < stepDistance * 0.85 && distToUpcoming < 40.0 {
                            shouldAdvance = true
                        }
                    }
                }
                
                if shouldAdvance {
                    self.currentStepIndex = upcomingIdx
                    // Nemudoma posodobi razdaljo do novega naslednjega manevra
                    let newUpcoming = getUpcomingStep(steps: steps)
                    if let newLoc = newUpcoming?.maneuver?.location, newLoc.count >= 2 {
                        let newCoord = CLLocationCoordinate2D(latitude: newLoc[1], longitude: newLoc[0])
                        self.distanceToNextStep = distanceBetweenCoords(userLocation, newCoord)
                    }
                }
            }
        } else {
            self.distanceToNextStep = distToGoal
        }
        
        let currentUpcoming = getUpcomingStep(steps: steps)
        let instruction = currentUpcoming?.maneuver?.instructionText ?? "Nadaljujte naravnost"
        
        // 3. Točen izračun preostale razdalje po dejanski OSRM trasi
        let remaining = calculateRemainingRouteDistance(userLoc: userLocation, routeCoords: route.coordinates)
        let eta = calculateEta(durationSeconds: max(30, remaining / 1.25))
        
        LiveNavigationManager.shared.updateNavigation(
            targetName: target.name,
            maneuverInstruction: instruction,
            distanceToManeuver: self.distanceToNextStep,
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
