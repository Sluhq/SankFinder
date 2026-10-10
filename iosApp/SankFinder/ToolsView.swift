import SwiftUI
import CoreLocation

struct ToolsView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject private var bridge = NavigationBridge.shared
    @ObservedObject private var squad = SquadManager.shared
    
    // MARK: - 1. Ruleta šankov (Naključni lokal)
    @State private var randomBar: Lokal?
    @State private var isRollingRandom: Bool = false
    
    // MARK: - 2. Kolo "Kdo plača rundo?"
    @State private var friendsList: [String] = ["Ti", "Luka", "Maja", "Žiga"]
    @State private var newFriendInput: String = ""
    @State private var selectedPayer: String? = nil
    @State private var wheelAngle: Double = 0.0
    @State private var isSpinningWheel: Bool = false
    
    // MARK: - 3. Burek Pavza
    @State private var onlyOpenBurek: Bool = false
    @State private var showAllBureks: Bool = false
    
    // Legendarni burek kotički (identični kot na Androidu)
    let burekSpots = [
        Lokal(name: "Pekarna Legiša (Rimska)", address: "Rimska cesta 16, Ljubljana", lat: 46.0468, lon: 14.5015, cuisine: "Pekarna, Burek, Pečivo", phone: "+386 41 742 686", website: nil, openingHours: "Pon-Pet 06:00 - 19:00, Sob 07:00 - 13:00"),
        Lokal(name: "Pekarna Dvojka", address: "Nazorjeva ulica 6, Ljubljana", lat: 46.0526, lon: 14.5042, cuisine: "Pekarna, Sendviči, Burek", phone: "+386 1 425 70 80", website: nil, openingHours: "Pon-Ned 06:00 - 03:00 (Nočni obrat)"),
        Lokal(name: "Burek Olimpija", address: "Slovenska cesta 58, Ljubljana", lat: 46.0565, lon: 14.5057, cuisine: "Burek, Pekarna, Fast food", phone: "+386 1 433 82 22", website: nil, openingHours: "24/7 Non-stop"),
        Lokal(name: "Nobel Burek", address: "Miklošičeva cesta 30, Ljubljana", lat: 46.0556, lon: 14.5098, cuisine: "Burek, Pizza, Fast food", phone: "+386 1 430 40 40", website: nil, openingHours: "24/7 Non-stop"),
        Lokal(name: "Pekarna Ajdovščina", address: "Trg Ajdovščina 1, Ljubljana", lat: 46.0538, lon: 14.5042, cuisine: "Pekarna, Sendviči", phone: "+386 1 234 56 78", website: nil, openingHours: "Pon-Sob 06:00 - 04:00 (Nočni obrat)"),
        Lokal(name: "Burek Trubarjeva", address: "Trubarjeva cesta 22, Ljubljana", lat: 46.0518, lon: 14.5095, cuisine: "Burek, Balkanski žar", phone: "+386 41 987 654", website: nil, openingHours: "Pon-Ned 09:00 - 03:00 (Nočni obrat)"),
        Lokal(name: "Pekarna Noč in Dan", address: "Resljeva cesta 16, Ljubljana", lat: 46.0535, lon: 14.5109, cuisine: "Pekarna, Burek, Prigrizki", phone: "+386 40 123 456", website: nil, openingHours: "24/7 Non-stop"),
        Lokal(name: "Pekarna Legiša (Dunajska)", address: "Dunajska cesta 49, Ljubljana", lat: 46.0645, lon: 14.5088, cuisine: "Pekarna, Burek, Dnevno pecivo", phone: "+386 41 742 686", website: nil, openingHours: "Pon-Pet 06:00 - 19:00, Sob 07:00 - 13:00"),
        Lokal(name: "Dunajska Pekarna", address: "Dunajska cesta 87, Ljubljana", lat: 46.0712, lon: 14.5120, cuisine: "Pekarna, Burek, Prigrizki", phone: "+386 1 234 56 70", website: nil, openingHours: "Pon-Ned 06:00 - 22:00 (Vsak dan)"),
        Lokal(name: "Burek Šiška", address: "Celovška cesta 111, Ljubljana", lat: 46.0689, lon: 14.4892, cuisine: "Burek, Pekarna, Pite", phone: "+386 1 515 22 11", website: nil, openingHours: "24/7 Non-stop")
    ]
    
    // MARK: - 4. Razdeli račun
    @State private var totalBillAmount: String = "48.50"
    @State private var peopleCount: Int = 4
    @State private var selectedTipIndex: Int = 0 // 0: 0%, 1: 5%, 2: 10%, 3: 15%
    let tipOptions = [0.0, 0.05, 0.10, 0.15]
    
    // MARK: - 5. Taksi pregovarjanje
    @State private var isTaxiConvincing: Bool = false
    @State private var currentTaxiConvinceIndex: Int = 0
    @State private var maxTaxiSteps: Int = 4
    @State private var showFinalTaxiModal: Bool = false
    
    let taxiSteps = [
        ("Si res prepričan, da odnehaš? 🍻", "Noč v mestu je še mlada, pipe pa še točijo! Res greš že domov?", "Imaš prav, še eno rundo!", "Res želim domov..."),
        ("Čakaj malo... A res že zdaj? 👀", "Tvoji prijatelji bodo rekli, da si copata! Šele pred kratkim smo začeli!", "Bom še ostal!", "Vseeno klic taksija"),
        ("Tvoja jetra pravijo: Zdrži! 💪", "Zdrži vsaj še en deci cvička ali eno malo točeno pivo. Ne bodi takšen!", "Ok, še eno pivo!", "Ne, res grem domov"),
        ("Kaj pa Burek pavza?! 🥐", "Zlato pravilo šankanja: Brez vročega bureka se ne gre spat! Pojdi najprej na burek pavzo!", "Grem na burek pavzo!", "Ne, taksi prosim"),
        ("Legende nikoli ne obupajo! ⭐", "Ali je kdo kdaj postal legenda tako, da je šel spat pred polnočjo? Nikakor!", "Ostajam do konca!", "Jaz nisem legenda, grem spat"),
        ("Kdo bo pa plačal zadnjo rundo? 💶", "Ravno zdaj bi bila tvoja runda, pa že bežiš? Družba bo zamerila!", "Častim še eno rundo!", "Jaz ne častim, domov grem")
    ]
    
    @State private var showSquadSheet: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.bgDark.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // 1. KARTICA PIVSKA KLAPA (Na vrhu orodij)
                        squadCardBanner
                        
                        // 2. RULETA ŠANKOV (Naključni lokal)
                        randomBarSection
                        
                        // 3. BUREK PAVZA (Legendarni nočni kotički)
                        burekSection
                        
                        // 4. KOLO "KDO PLAČA RUNDO?"
                        wheelSection
                        
                        // 5. RAZDELI RAČUN (Bill Splitter)
                        billSplitSection
                        
                        // 6. GUMB ZA TAKSI Z NAKLJUČNIM PREPRIČEVANJEM
                        taxiSection
                    }
                    .padding(16)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Orodja")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                GlobalSyncManager.shared.reportScreen("Pivska orodja")
            }
            .sheet(isPresented: $showSquadSheet) {
                SquadView()
            }
            .sheet(isPresented: $showFinalTaxiModal) {
                taxiDialerModal
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - 1. Pivska Klapa Kartica
    private var squadCardBanner: some View {
        Button(action: { showSquadSheet = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.beerGold.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Text("👥")
                        .font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(squad.activeRoom != nil ? "Pivska Klapa: \(squad.activeRoom!.code)" : "Pivska Klapa (Skupina)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if squad.activeRoom != nil {
                            Circle()
                                .fill(Theme.drajvGreen)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(squad.activeRoom != nil ? "\(squad.members.count) prijateljev v živo • Klikni za klepet" : "Vstopi v sobo, klepetaj v živo in štej runde!")
                        .font(.caption)
                        .foregroundColor(.appMuted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.beerGold)
            }
            .padding(14)
            .background(Theme.cardDark)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(squad.activeRoom != nil ? Theme.beerGold : Color.clear, lineWidth: 1.5)
            )
        }
    }
    
    // MARK: - 2. Ruleta šankov (Naključni lokal)
    private var randomBarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🎲 Ruleta Šankov")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            if let bar = randomBar {
                VStack(alignment: .leading, spacing: 6) {
                    Text(bar.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.beerGold)
                    Text(bar.address)
                        .font(.caption)
                        .foregroundColor(.appMuted)
                    
                    HStack {
                        Text(bar.statusBadge.text)
                            .font(.caption2)
                            .foregroundColor(bar.statusBadge.isGreen ? Theme.drajvGreen : Theme.drajvRed)
                        Text("•  \(bar.formattedDistance(from: locationManager.location))")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { bridge.navigateTo(lokal: bar) }) {
                        HStack {
                            Image(systemName: "figure.walk")
                            Text("Navigiraj peš")
                                .fontWeight(.bold)
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(red: 46/255, green: 125/255, blue: 50/255))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.top, 4)
                }
                .padding(12)
                .background(Theme.surfaceDark)
                .cornerRadius(12)
            }
            
            Button(action: spinRandomBar) {
                HStack {
                    Image(systemName: "dice.fill")
                    Text("Izžrebaj naključni šank!")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.beerGold)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
    }
    
    private func spinRandomBar() {
        isRollingRandom = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.randomBar = self.burekSpots.randomElement()
            self.isRollingRandom = false
        }
    }
    
    // MARK: - 3. Burek Pavza
    private var burekSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Text("🥐")
                        .font(.title2)
                    Text("Burek Pavza (Nočne pekarne)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                Spacer()
                
                Button(action: { onlyOpenBurek.toggle() }) {
                    Text(onlyOpenBurek ? "🟢 Samo odprto" : "Vsi kotički")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(onlyOpenBurek ? Theme.drajvGreen : Theme.surfaceDark)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            let filtered = onlyOpenBurek ? burekSpots.filter { $0.isOpenNow } : burekSpots
            let displayed = showAllBureks ? filtered : Array(filtered.prefix(4))
            
            VStack(spacing: 8) {
                ForEach(displayed) { spot in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(spot.name)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text(spot.address)
                                .font(.system(size: 11))
                                .foregroundColor(.appMuted)
                                .lineLimit(1)
                            
                            HStack(spacing: 6) {
                                Text(spot.statusBadge.text)
                                    .font(.system(size: 10))
                                    .fontWeight(.bold)
                                    .foregroundColor(spot.statusBadge.isGreen ? Theme.drajvGreen : Theme.drajvRed)
                                
                                Text("• \(spot.formattedDistance(from: locationManager.location)) (~ \(spot.walkingMinutes(from: locationManager.location)) min)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.beerGold)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { bridge.navigateTo(lokal: spot) }) {
                            Image(systemName: "figure.walk")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color(red: 46/255, green: 125/255, blue: 50/255))
                                .clipShape(Circle())
                        }
                    }
                    .padding(10)
                    .background(Theme.surfaceDark)
                    .cornerRadius(12)
                }
            }
            
            if filtered.count > 4 {
                Button(action: { showAllBureks.toggle() }) {
                    Text(showAllBureks ? "Prikaži manj" : "Prikaži vseh \(filtered.count) lokacij bureka")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.beerGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
    }
    
    // MARK: - 4. Kolo "Kdo plača rundo?"
    private var wheelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎡 Kdo plača rundo?")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            // Seznam imen
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(friendsList, id: \.self) { friend in
                        HStack(spacing: 4) {
                            Text(friend)
                                .font(.caption)
                                .foregroundColor(.white)
                            Button(action: { friendsList.removeAll { $0 == friend } }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.surfaceDark)
                        .cornerRadius(10)
                    }
                }
            }
            
            HStack {
                TextField("Dodaj prijatelja...", text: $newFriendInput)
                    .font(.caption)
                    .padding(8)
                    .background(Theme.surfaceDark)
                    .cornerRadius(8)
                    .foregroundColor(.white)
                
                Button(action: {
                    let t = newFriendInput.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty && !friendsList.contains(t) {
                        friendsList.append(t)
                        newFriendInput = ""
                    }
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Theme.beerGold)
                        .cornerRadius(8)
                }
            }
            
            if let payer = selectedPayer {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Rundo časti:")
                            .font(.caption)
                            .foregroundColor(.appMuted)
                        Text("🍺 \(payer)!")
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(.beerGold)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Theme.surfaceDark)
                .cornerRadius(12)
            }
            
            Button(action: spinWheel) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Zavrti kolo za rundo!")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.beerGold)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
    }
    
    private func spinWheel() {
        guard !friendsList.isEmpty, !isSpinningWheel else { return }
        isSpinningWheel = true
        selectedPayer = "Vrtim..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.selectedPayer = self.friendsList.randomElement()
            self.isSpinningWheel = false
        }
    }
    
    // MARK: - 5. Razdeli Račun (Bill Splitter)
    private var billSplitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("💶 Razdeli Račun")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack {
                Text("Skupni znesek:")
                    .font(.subheadline)
                    .foregroundColor(.appMuted)
                Spacer()
                TextField("€", text: $totalBillAmount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 100)
                    .padding(6)
                    .background(Theme.surfaceDark)
                    .cornerRadius(8)
            }
            
            HStack {
                Text("Število oseb: \(peopleCount)")
                    .font(.subheadline)
                    .foregroundColor(.appMuted)
                Spacer()
                Stepper("", value: $peopleCount, in: 1...20)
                    .labelsHidden()
            }
            
            // Napitnina
            HStack {
                Text("Napitnina:")
                    .font(.caption)
                    .foregroundColor(.appMuted)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<tipOptions.count, id: \.self) { idx in
                        Button(action: { selectedTipIndex = idx }) {
                            Text("\(Int(tipOptions[idx] * 100))%")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedTipIndex == idx ? Theme.beerGold : Theme.surfaceDark)
                                .foregroundColor(selectedTipIndex == idx ? .black : .white)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            // Izračun na osebo
            let total = (Double(totalBillAmount.replacingOccurrences(of: ",", with: ".")) ?? 0.0) * (1.0 + tipOptions[selectedTipIndex])
            let perPerson = total / Double(max(1, peopleCount))
            
            HStack {
                Text("Vsak plača:")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.2f €", perPerson))
                    .font(.title2)
                    .fontWeight(.black)
                    .foregroundColor(.beerGold)
            }
            .padding(10)
            .background(Theme.surfaceDark)
            .cornerRadius(10)
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
    }
    
    // MARK: - 6. Taksi z naključnim prepričevanjem
    private var taxiSection: some View {
        VStack(spacing: 10) {
            Button(action: startTaxiFlow) {
                HStack {
                    Image(systemName: "car.fill")
                    Text("Končal sem / Pokliči taksi 🚕")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.drajvRed)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            
            if isTaxiConvincing {
                let step = taxiSteps[min(currentTaxiConvinceIndex, taxiSteps.count - 1)]
                VStack(spacing: 12) {
                    Text(step.0)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(step.1)
                        .font(.subheadline)
                        .foregroundColor(.appMuted)
                        .multilineTextAlignment(.center)
                    
                    Button(action: { isTaxiConvincing = false }) {
                        Text(step.2)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.beerGold)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                    }
                    
                    Button(action: nextTaxiStep) {
                        Text(step.3)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(14)
                .background(Theme.surfaceDark)
                .cornerRadius(14)
            }
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
    }
    
    private func startTaxiFlow() {
        maxTaxiSteps = Int.random(in: 3...5)
        currentTaxiConvinceIndex = 0
        isTaxiConvincing = true
    }
    
    private func nextTaxiStep() {
        if currentTaxiConvinceIndex + 1 >= maxTaxiSteps {
            isTaxiConvincing = false
            showFinalTaxiModal = true
        } else {
            currentTaxiConvinceIndex += 1
        }
    }
    
    private var taxiDialerModal: some View {
        VStack(spacing: 18) {
            Text("Čas je za domov... 🚕")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 24)
            
            Text("Varno se vrni domov. Izberi ponudnika taksija za neposreden klic:")
                .font(.subheadline)
                .foregroundColor(.appMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            VStack(spacing: 12) {
                taxiCallButton(name: "Taxi Metro (080 11 90)", number: "0801190")
                taxiCallButton(name: "Taxi Laguna (080 11 17)", number: "0801117")
                taxiCallButton(name: "Taxi Cammeo (01 777 12 12)", number: "017771212")
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button("Prekliči, še malo ostanem...") {
                showFinalTaxiModal = false
            }
            .foregroundColor(.beerGold)
            .padding(.bottom, 24)
        }
        .background(Theme.bgDark.edgesIgnoringSafeArea(.all))
    }
    
    private func taxiCallButton(name: String, number: String) -> some View {
        Link(destination: URL(string: "tel:\(number)")!) {
            HStack {
                Image(systemName: "phone.fill")
                Text(name)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.surfaceDark)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}
