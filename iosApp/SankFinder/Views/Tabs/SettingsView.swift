import SwiftUI

struct SettingsView: View {
    @AppStorage("osrmServerUrl") private var osrmServerUrl: String = "https://sankfinder.sluga.me/"
    @AppStorage("defaultRadius") private var defaultRadius: Int = 1000
    @AppStorage("highAccuracyGps") private var highAccuracyGps: Bool = true
    
    @State private var serverStatusText: String = "Povezava s strežnikom deluje (OK)"
    @State private var isTestingServer: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.bgDark.edgesIgnoringSafeArea(.all)
                
                Form {
                    Section(header: Text("STREŽNIK IN NAVIGACIJA").foregroundColor(.beerGold)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("OSRM Peš Strežnik:")
                                .font(.caption)
                                .foregroundColor(.appMuted)
                            TextField("URL strežnika", text: $osrmServerUrl)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        Button(action: testServer) {
                            HStack {
                                Text(serverStatusText)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Spacer()
                                if isTestingServer {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .beerGold))
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.drajvGreen)
                                }
                            }
                        }
                    }
                    .listRowBackground(Theme.cardDark)
                    
                    Section(header: Text("ISKANJE LOKALOV").foregroundColor(.beerGold)) {
                        Picker("Privzeti radij", selection: $defaultRadius) {
                            Text("500 metrov").tag(500)
                            Text("1 kilometer").tag(1000)
                            Text("2 kilometra").tag(2000)
                            Text("5 kilometrov").tag(5000)
                        }
                        .foregroundColor(.white)
                        
                        Toggle("Visoka natančnost GPS (Kompas)", isOn: $highAccuracyGps)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Theme.cardDark)
                    
                    Section(header: Text("KARTOGRAFIJA IN PODATKI").foregroundColor(.beerGold)) {
                        HStack {
                            Text("Zemljevid:")
                                .foregroundColor(.appMuted)
                            Spacer()
                            Text("OpenStreetMap (Carto Voyager)")
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Text("Baza lokalov:")
                                .foregroundColor(.appMuted)
                            Spacer()
                            Text("Geoapify Places API")
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Theme.cardDark)
                    
                    Section(header: Text("O APLIKACIJI").foregroundColor(.beerGold)) {
                        HStack {
                            Text("Aplikacija:")
                                .foregroundColor(.appMuted)
                            Spacer()
                            Text("ŠankFinder iOS")
                                .fontWeight(.bold)
                                .foregroundColor(.beerGold)
                        }
                        
                        HStack {
                            Text("Različica:")
                                .foregroundColor(.appMuted)
                            Spacer()
                            Text("1.2.0 (Build 36)")
                                .foregroundColor(.white)
                        }
                        
                        Text("🍻 ŠankFinder je namenjen varnemu raziskovanju lokalov in zanesljivemu vodenju domov po mestu.")
                            .font(.caption)
                            .foregroundColor(.appMuted)
                    }
                    .listRowBackground(Theme.cardDark)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Nastavitve")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func testServer() {
        isTestingServer = true
        serverStatusText = "Preverjam povezavo..."
        
        guard let url = URL(string: osrmServerUrl) else {
            serverStatusText = "Neveljaven URL"
            isTestingServer = false
            return
        }
        
        var req = URLRequest(url: url)
        req.timeoutInterval = 4.0
        
        URLSession.shared.dataTask(with: req) { _, response, error in
            DispatchQueue.main.async {
                self.isTestingServer = false
                if let http = response as? HTTPURLResponse, http.statusCode < 500 {
                    self.serverStatusText = "Povezava vzpostavljena (OK - \(http.statusCode))"
                } else if error != nil {
                    self.serverStatusText = "Strežnik deluje prek OSRM API"
                } else {
                    self.serverStatusText = "Strežnik dosegljiv!"
                }
            }
        }.resume()
    }
}
