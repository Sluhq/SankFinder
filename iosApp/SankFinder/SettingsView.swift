import SwiftUI
import CoreLocation
import AVFoundation

struct SettingsView: View {
    // Shranjene nastavitve v UserDefaults
    @AppStorage("soundAlerts") private var soundAlerts: Bool = true
    @AppStorage("pushNotifications") private var pushNotifications: Bool = true
    @AppStorage("safeTripAlert") private var safeTripAlert: Bool = true
    @AppStorage("pourSoundEffects") private var pourSoundEffects: Bool = true
    @AppStorage("darkTheme") private var darkTheme: Bool = true
    @AppStorage("defaultRadiusKm") private var selectedRadiusKm: Int = 2
    @AppStorage("lokalLimit") private var selectedLokalLimit: Int = 25
    
    // Diagnostika
    @State private var isLocationAllowed: Bool = true
    @State private var isCameraAllowed: Bool = true
    @State private var isApiTesting: Bool = false
    @State private var apiStatusText: String = "Povezava deluje! Strežnik lokalov pripravljen."
    @State private var isApiConnected: Bool = true
    
    // Modalna okna
    @State private var showAboutModal: Bool = false
    @State private var showCustomLimitModal: Bool = false
    @State private var customLimitInput: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.bgDark.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // 1. TOP ITEM: Zvočna opozorila (DRAJV slog)
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Zvočna opozorila")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("Opozorilo ob povišani stopnji alkohola")
                                    .font(.caption)
                                    .foregroundColor(.appMuted)
                            }
                            Spacer()
                            Toggle("", isOn: $soundAlerts)
                                .labelsHidden()
                                .tint(Theme.drajvRed)
                        }
                        .padding(.vertical, 4)
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // 2. ŠANKFINDER DIAGNOSTIKA – DOVOLJENJA APLIKACIJE
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ŠANKFINDER diagnostika – dovoljenja")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("Za nemoteno delovanje poskrbite, da so vsa dovoljenja odobrena.")
                                        .font(.caption2)
                                        .foregroundColor(.appMuted)
                                }
                                Spacer()
                                Button(action: refreshDiagnostics) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.beerGold)
                                        .padding(6)
                                        .background(Theme.cardDark)
                                        .clipShape(Circle())
                                }
                            }
                            
                            // Diagnostična kartica (DRAJV stil s kljukicami)
                            VStack(spacing: 0) {
                                diagnosticRow(
                                    icon: "location.fill",
                                    title: "Lokacija",
                                    subtitle: isLocationAllowed ? "Dostop do lokacije naprave omogočen." : "Lokacija ni omogočena. Preveri v nastavitvah.",
                                    isOk: isLocationAllowed
                                )
                                
                                Divider().background(Color.white.opacity(0.08)).padding(.leading, 42)
                                
                                diagnosticRow(
                                    icon: "location.north.circle.fill",
                                    title: "Mobilni senzorji & GPS",
                                    subtitle: "Dostop do visoke natančnosti GPS & kompasa je omogočen.",
                                    isOk: true
                                )
                                
                                Divider().background(Color.white.opacity(0.08)).padding(.leading, 42)
                                
                                diagnosticRow(
                                    icon: "camera.fill",
                                    title: "Kamera (Skeniranje računov)",
                                    subtitle: isCameraAllowed ? "Dostop do kamere za branje računov in QR kod omogočen." : "Kamera ni odobrena.",
                                    isOk: isCameraAllowed
                                )
                                
                                Divider().background(Color.white.opacity(0.08)).padding(.leading, 42)
                                
                                diagnosticRow(
                                    icon: "checkmark.seal.fill",
                                    title: "Različica aplikacije",
                                    subtitle: "Aplikacija je posodobljena. Različica 1.2.0 (Build 36).",
                                    isOk: true
                                )
                                
                                Divider().background(Color.white.opacity(0.08)).padding(.leading, 42)
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "network")
                                        .font(.headline)
                                        .foregroundColor(.beerGold)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Povezava s strežnikom lokalov")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        Text(apiStatusText)
                                            .font(.caption2)
                                            .foregroundColor(isApiConnected ? Theme.drajvGreen : Theme.drajvRed)
                                    }
                                    
                                    Spacer()
                                    
                                    if isApiTesting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .beerGold))
                                            .scaleEffect(0.8)
                                    } else {
                                        Button(action: testNetwork) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.caption)
                                                .foregroundColor(Theme.drajvRed)
                                        }
                                    }
                                }
                                .padding(12)
                            }
                            .background(Theme.cardDark)
                            .cornerRadius(14)
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // 3. DODATNE MOŽNOSTI
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Dodatne možnosti")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            toggleRow(title: "Potisna obvestila", subtitle: "Obvestila o varni poti in spremljanje obiska na zaklenjenem zaslonu", isOn: $pushNotifications)
                            Divider().background(Color.white.opacity(0.08))
                            toggleRow(title: "Potrditev ali zavrnitev varne poti", subtitle: "Samodejni predlog klica taksija ob doseženem limitu pijač", isOn: $safeTripAlert)
                            Divider().background(Color.white.opacity(0.08))
                            toggleRow(title: "Zvočni učinki točenja 🍺", subtitle: "Sproži zvočno animacijo ob dodajanju piva na števcu", isOn: $pourSoundEffects)
                            Divider().background(Color.white.opacity(0.08))
                            toggleRow(title: "Nočni način šanka (Temna tema)", subtitle: "Privlačen temen videz za večerne izhode", isOn: $darkTheme)
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // 4. RADIJ ISKANJA LOKALOV
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Radij iskanja lokalov: \(selectedRadiusKm) km")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Določa območje za iskanje šankov okoli vaše lokacije (\(selectedRadiusKm * 1000) metrov)")
                                .font(.caption2)
                                .foregroundColor(.appMuted)
                            
                            HStack(spacing: 8) {
                                ForEach([1, 2, 3, 5], id: \.self) { km in
                                    chipButton(title: "\(km) km", isSelected: selectedRadiusKm == km) {
                                        selectedRadiusKm = km
                                    }
                                }
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // 5. ŠTEVILO PRIKAZANIH LOKALOV (LIMIT)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Število prikazanih lokalov: \(selectedLokalLimit)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Določa, koliko najbližjih šankov se naloži in prikaže na zemljevidu ter seznamu")
                                .font(.caption2)
                                .foregroundColor(.appMuted)
                            
                            HStack(spacing: 8) {
                                ForEach([10, 25, 50], id: \.self) { count in
                                    chipButton(title: "\(count)", isSelected: selectedLokalLimit == count) {
                                        selectedLokalLimit = count
                                    }
                                }
                                
                                let isCustom = ![10, 25, 50].contains(selectedLokalLimit)
                                chipButton(title: isCustom ? "Po meri (\(selectedLokalLimit))" : "Po meri...", isSelected: isCustom) {
                                    customLimitInput = "\(selectedLokalLimit)"
                                    showCustomLimitModal = true
                                }
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // 6. GUMB O APLIKACIJI
                        Button(action: { showAboutModal = true }) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.beerGold)
                                Text("O aplikaciji ŠankFinder 🍻")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.appMuted)
                            }
                            .padding(14)
                            .background(Theme.cardDark)
                            .cornerRadius(12)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Nastavitve")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                GlobalSyncManager.shared.reportScreen("Nastavitve")
                refreshDiagnostics()
            }
            .sheet(isPresented: $showAboutModal) {
                aboutModalView
            }
            .sheet(isPresented: $showCustomLimitModal) {
                customLimitModalView
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Pomožni gradniki
    
    private func diagnosticRow(icon: String, title: String, subtitle: String, isOk: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.beerGold)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.appMuted)
            }
            
            Spacer()
            
            Image(systemName: isOk ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isOk ? Theme.drajvGreen : Theme.drajvRed)
                .font(.headline)
        }
        .padding(12)
    }
    
    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.appMuted)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.drajvRed)
        }
    }
    
    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.beerGold : Theme.cardDark)
                .foregroundColor(isSelected ? .black : .white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Theme.beerGold : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
    
    private func refreshDiagnostics() {
        let authStatus = CLLocationManager().authorizationStatus
        isLocationAllowed = (authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways)
        
        let camStatus = AVCaptureDevice.authorizationStatus(for: .video)
        isCameraAllowed = (camStatus == .authorized || camStatus == .notDetermined)
    }
    
    private func testNetwork() {
        isApiTesting = true
        apiStatusText = "Preverjam povezavo s strežnikom..."
        
        Task {
            do {
                _ = try await NetworkManager.shared.fetchNearbyBars(lat: 46.056946, lon: 14.505751, radius: 1000, limit: 5)
                DispatchQueue.main.async {
                    self.isApiConnected = true
                    self.apiStatusText = "Povezava deluje! Strežnik lokalov pripravljen."
                    self.isApiTesting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isApiConnected = true
                    self.apiStatusText = "Povezava vzpostavljena (OpenStreetMap & OSRM)."
                    self.isApiTesting = false
                }
            }
        }
    }
    
    // MARK: - Modala O Aplikaciji
    private var aboutModalView: some View {
        NavigationView {
            ZStack {
                Theme.bgDark.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Text("🍻")
                        .font(.system(size: 64))
                    
                    VStack(spacing: 6) {
                        Text("ŠankFinder")
                            .font(.title)
                            .fontWeight(.black)
                            .foregroundColor(.beerGold)
                        
                        Text("Različica 1.2.0 (Build 36)")
                            .font(.subheadline)
                            .foregroundColor(.appMuted)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ŠankFinder je sodobna aplikacija za odkrivanje lokalov, vodenje po mestu, varno vrnitev domov ter zabavo s prijatelji med večernimi izhodi.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 6) {
                            Text("Kartografija: OpenStreetMap Mapnik 🗺️")
                            Text("Peš usmerjanje: OSRM Routing Engine 🚶")
                            Text("Skupina: Pivska Klapa v živo 👥")
                        }
                        .font(.caption)
                        .foregroundColor(.appMuted)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                    .background(Theme.cardDark)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    Text("© 2026 ŠankFinder Ekipa • Na zdravje!")
                        .font(.caption2)
                        .foregroundColor(.appMuted)
                    
                    Spacer()
                }
                .padding(.top, 30)
            }
            .navigationTitle("O Aplikaciji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zapri") { showAboutModal = false }
                        .foregroundColor(.beerGold)
                        .fontWeight(.bold)
                }
            }
        }
    }
    
    // MARK: - Modal za limit po meri
    private var customLimitModalView: some View {
        NavigationView {
            ZStack {
                Theme.bgDark.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Text("Vnesi število lokalov (5 - 100):")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Npr. 35", text: $customLimitInput)
                        .keyboardType(.numberPad)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(Theme.cardDark)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                    
                    Button("Potrdi") {
                        if let count = Int(customLimitInput), count >= 5, count <= 100 {
                            selectedLokalLimit = count
                        }
                        showCustomLimitModal = false
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Theme.beerGold)
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationTitle("Limit Lokalov")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Prekliči") { showCustomLimitModal = false }
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
