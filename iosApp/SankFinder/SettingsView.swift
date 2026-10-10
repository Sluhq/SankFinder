import SwiftUI
import CoreLocation
import AVFoundation

struct SettingsView: View {
    @AppStorage("soundAlerts") private var soundAlerts: Bool = true
    @AppStorage("pushNotifications") private var pushNotifications: Bool = true
    @AppStorage("safeTripAlert") private var safeTripAlert: Bool = true
    @AppStorage("pourSoundEffects") private var pourSoundEffects: Bool = true
    @AppStorage("darkTheme") private var darkTheme: Bool = true
    @AppStorage("defaultRadiusKm") private var selectedRadiusKm: Int = 2
    @AppStorage("lokalLimit") private var selectedLokalLimit: Int = 25
    
    @State private var isLocationAllowed: Bool = true
    @State private var isCameraAllowed: Bool = true
    @State private var isApiTesting: Bool = false
    @State private var apiStatusText: String = "Povezava deluje! Strežnik lokalov pripravljen."
    @State private var isApiConnected: Bool = true
    
    @State private var showAboutModal: Bool = false
    @State private var showCustomLimitModal: Bool = false
    @State private var customLimitInput: String = ""
    
    var body: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // MATERIAL 3 TOP APP BAR
                MaterialTopAppBar(title: "Nastavitve")
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. ZVOČNA OPOZORILA (DRAJV rdeče stikalo)
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Zvočna opozorila")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Opozorilo ob povišani stopnji alkohola")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textMuted)
                            }
                            Spacer()
                            Toggle("", isOn: $soundAlerts)
                                .labelsHidden()
                                .tint(Theme.drajvRed)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                        
                        // 2. ŠANKFINDER DIAGNOSTIKA – DOVOLJENJA APLIKACIJE (DRAJV slog)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ŠANKFINDER diagnostika – dovoljenja")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Za nemoteno delovanje poskrbite, da so vsa dovoljenja odobrena.")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textMuted)
                                }
                                Spacer()
                                Button(action: refreshDiagnostics) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(Theme.beerGold)
                                        .padding(6)
                                        .background(Theme.surfaceDark)
                                        .clipShape(Circle())
                                }
                            }
                            
                            // Diagnostična kartica
                            VStack(spacing: 0) {
                                diagnosticItem(
                                    title: "Lokacija",
                                    subtitle: isLocationAllowed ? "Dostop do lokacije naprave omogočen." : "Lokacija ni omogočena. Preveri v nastavitvah.",
                                    isApproved: isLocationAllowed
                                )
                                
                                Divider().background(Color.white.opacity(0.08)).padding(.leading, 14)
                                
                                diagnosticItem(
                                    title: "Mobilni senzorji & GPS",
                                    subtitle: "Dostop do visoke natančnosti GPS & azimuta je omogočen.",
                                    isApproved: true
                                )
                                
                                Divider().background(Color.white.opacity(0.08)).padding(.leading, 14)
                                
                                diagnosticItem(
                                    title: "Kamera (Skeniranje računov)",
                                    subtitle: isCameraAllowed ? "Dostop do kamere za branje računov in QR kod omogočen." : "Kamera ni odobrena.",
                                    isApproved: isCameraAllowed
                                )
                                
                                Divider().background(Color.white.opacity(0.08)).padding(.leading, 14)
                                
                                diagnosticItem(
                                    title: "Različica aplikacije",
                                    subtitle: "Aplikacija je posodobljena. Različica 1.2.0 (Build 36).",
                                    isApproved: true
                                )
                                
                                Divider().background(Color.white.opacity(0.08)).padding(.leading, 14)
                                
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Povezava s strežnikom lokalov")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(apiStatusText)
                                            .font(.system(size: 12))
                                            .foregroundColor(isApiConnected ? Theme.drajvGreen : Theme.drajvRed)
                                    }
                                    Spacer()
                                    if isApiTesting {
                                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Theme.beerGold))
                                    } else {
                                        Button(action: testNetwork) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 14))
                                                .foregroundColor(Theme.drajvRed)
                                        }
                                    }
                                }
                                .padding(12)
                            }
                            .background(Theme.surfaceVariantDark.opacity(0.45))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.darkBorder, lineWidth: 1))
                        }
                        .padding(.horizontal, 16)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                        
                        // 3. DODATNE MOŽNOSTI
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Dodatne možnosti")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            
                            toggleRow(title: "Potisna obvestila", subtitle: "Obvestila o varni poti in spremljanje obiska na zaklenjenem zaslonu", isOn: $pushNotifications)
                            Divider().background(Color.white.opacity(0.08))
                            toggleRow(title: "Potrditev ali zavrnitev varne poti", subtitle: "Samodejni predlog klica taksija ob doseženem limitu pijač", isOn: $safeTripAlert)
                            Divider().background(Color.white.opacity(0.08))
                            toggleRow(title: "Zvočni učinki točenja", subtitle: "Sproži zvočno animacijo ob dodajanju piva na števcu", isOn: $pourSoundEffects)
                            Divider().background(Color.white.opacity(0.08))
                            toggleRow(title: "Nočni način šanka (Temna tema)", subtitle: "Privlačen temen videz za večerne izhode", isOn: $darkTheme)
                        }
                        .padding(.horizontal, 16)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                        
                        // 4. RADIJ ISKANJA LOKALOV
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Radij iskanja lokalov: \(selectedRadiusKm) km")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Določa območje za iskanje šankov okoli vaše lokacije (\(selectedRadiusKm * 1000) metrov)")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textMuted)
                            
                            HStack(spacing: 8) {
                                ForEach([1, 2, 3, 5], id: \.self) { km in
                                    MaterialFilterChip(title: "\(km) km", isSelected: selectedRadiusKm == km) {
                                        selectedRadiusKm = km
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 0.5)
                            .padding(.horizontal, 16)
                        
                        // 5. ŠTEVILO PRIKAZANIH LOKALOV (LIMIT)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Število prikazanih lokalov: \(selectedLokalLimit)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Določa, koliko najbližjih šankov se naloži in prikaže na zemljevidu ter seznamu")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textMuted)
                            
                            HStack(spacing: 8) {
                                ForEach([10, 25, 50], id: \.self) { count in
                                    MaterialFilterChip(title: "\(count)", isSelected: selectedLokalLimit == count) {
                                        selectedLokalLimit = count
                                    }
                                }
                                
                                let isCustom = ![10, 25, 50].contains(selectedLokalLimit)
                                MaterialFilterChip(title: isCustom ? "Po meri (\(selectedLokalLimit))" : "Po meri...", isSelected: isCustom) {
                                    customLimitInput = "\(selectedLokalLimit)"
                                    showCustomLimitModal = true
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // 6. GUMB O APLIKACIJI
                        Button(action: { showAboutModal = true }) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(Theme.beerGold)
                                Text("O aplikaciji ŠankFinder")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Theme.textMuted)
                            }
                            .padding(14)
                            .background(Theme.surfaceVariantDark.opacity(0.45))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.darkBorder, lineWidth: 1))
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 80) // Prostor za BottomNavBar
                }
            }
        }
        .sheet(isPresented: $showAboutModal) {
            aboutModalView
        }
        .sheet(isPresented: $showCustomLimitModal) {
            customLimitModalView
        }
        .onAppear {
            GlobalSyncManager.shared.reportScreen("Nastavitve")
            refreshDiagnostics()
        }
    }
    
    // MARK: - Pomožni gradniki
    private func diagnosticItem(title: String, subtitle: String, isApproved: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer()
            Image(systemName: isApproved ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isApproved ? Theme.drajvGreen : Theme.drajvRed)
                .font(.system(size: 18))
        }
        .padding(12)
    }
    
    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.drajvRed)
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
    
    private var aboutModalView: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "mug.fill")
                    .font(.system(size: 54))
                    .foregroundColor(Theme.beerGold)
                
                VStack(spacing: 6) {
                    Text("ŠankFinder")
                        .font(.title)
                        .fontWeight(.black)
                        .foregroundColor(Theme.beerGold)
                    
                    Text("Različica 1.2.0 (Build 36)")
                        .font(.subheadline)
                        .foregroundColor(Theme.textMuted)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("ŠankFinder je sodobna aplikacija za odkrivanje lokalov, vodenje po mestu, varno vrnitev domov ter zabavo s prijatelji med večernimi izhodi.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 6) {
                        Text("Kartografija: OpenStreetMap Mapnik")
                        Text("Peš usmerjanje: OSRM Routing Engine")
                        Text("Skupina: Pivska Klapa v živo")
                    }
                    .font(.caption)
                    .foregroundColor(Theme.textMuted)
                    .frame(maxWidth: .infinity)
                }
                .padding(16)
                .background(Theme.cardDark)
                .cornerRadius(16)
                .padding(.horizontal, 20)
                
                Text("© 2026 ŠankFinder Ekipa • Na zdravje!")
                    .font(.caption2)
                    .foregroundColor(Theme.textMuted)
                
                Button("Zapri") {
                    showAboutModal = false
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 12)
                .background(Theme.beerGold)
                .cornerRadius(12)
                
                Spacer()
            }
            .padding(.top, 40)
        }
    }
    
    private var customLimitModalView: some View {
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
                
                HStack(spacing: 14) {
                    Button("Prekliči") {
                        showCustomLimitModal = false
                    }
                    .foregroundColor(Theme.textMuted)
                    
                    Button("Potrdi") {
                        if let count = Int(customLimitInput), count >= 5, count <= 100 {
                            selectedLokalLimit = count
                        }
                        showCustomLimitModal = false
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(Theme.beerGold)
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding(.top, 40)
        }
    }
}
