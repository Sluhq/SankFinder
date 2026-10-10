import SwiftUI
import CoreLocation

struct ToolsView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject private var bridge = NavigationBridge.shared
    @ObservedObject private var squad = SquadManager.shared
    @StateObject private var network = NetworkManager.shared
    
    // 1. RULETA ŠANKOV
    @State private var randomBar: Lokal? = nil
    @State private var isRollingRandom: Bool = false
    
    // 2. KOLO "KDO PLAČA RUNDO?"
    @State private var friendsList: [String] = ["Ti", "Luka", "Maja", "Žiga"]
    @State private var newFriendInput: String = ""
    @State private var selectedPayer: String? = nil
    @State private var funPayerQuote: String? = nil
    @State private var wheelAngle: Double = 0.0
    @State private var isSpinningWheel: Bool = false
    
    // 3. BUREK PAVZA
    @State private var onlyOpenBurek: Bool = false
    @State private var showAllBureks: Bool = false
    
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
    
    // 4. RAZDELI RAČUN
    @State private var totalBillAmount: String = "48.50"
    @State private var peopleCount: Int = 4
    @State private var selectedTipIndex: Int = 0
    let tipOptions = [0.0, 0.05, 0.10, 0.15]
    
    // 5. TAKSI PREGOVARJANJE (3 do 6 stopenj)
    @State private var isTaxiConvincing: Bool = false
    @State private var currentTaxiConvinceIndex: Int = 0
    @State private var maxTaxiSteps: Int = 4
    @State private var showFinalTaxiModal: Bool = false
    
    let allTaxiSteps = [
        ("Si res prepričan, da odnehaš?", "Noč v mestu je še mlada, pipe pa še točijo! Res greš že domov?", "Imaš prav, še eno rundo!", "Res želim domov..."),
        ("Čakaj malo... A res že zdaj?", "Tvoji prijatelji bodo rekli, da si copata! Šele pred kratkim smo začeli!", "Bom še ostal!", "Vseeno klic taksija"),
        ("Tvoja jetra pravijo: Zdrži!", "Zdrži vsaj še en deci cvička ali eno malo točeno pivo. Ne bodi takšen!", "Ok, še eno pivo!", "Ne, res grem domov"),
        ("Kaj pa Burek pavza?!", "Zlato pravilo šankanja: Brez vročega bureka se ne gre spat! Pojdi najprej na burek pavzo!", "Grem na burek pavzo!", "Ne, taksi prosim"),
        ("Legende nikoli ne obupajo!", "Ali je kdo kdaj postal legenda tako, da je šel spat pred polnočjo? Nikakor!", "Ostajam do konca!", "Jaz nisem legenda, grem spat"),
        ("Pivo brez tebe bo žalostno...", "Natakar ravno odpira nov sod, ti bi pa šel domov? Daj no, še en požirek!", "Še en požirek!", "Ne, taksi zdaj")
    ]
    
    @State private var showSquadSheet: Bool = false
    
    var body: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // MATERIAL 3 TOP APP BAR
                MaterialTopAppBar(title: "Šank Orodja")
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // HEADER BANNER (Identical to GamesPage.kt)
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [Theme.beerGold, Color(hex: 0xD97706)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 46, height: 46)
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Šank Orodja")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Zabava, pravila in varna vrnitev domov")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textMuted)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        
                        // 1. KARTICA PIVSKA KLAPA
                        squadCardSection
                            .padding(.horizontal, 16)
                        
                        // 2. KARTICA RULETA ŠANKOV
                        randomBarSection
                            .padding(.horizontal, 16)
                        
                        // 3. KARTICA BUREK PAVZA
                        burekSection
                            .padding(.horizontal, 16)
                        
                        // 4. KOLO "KDO PLAČA RUNDO?"
                        wheelSection
                            .padding(.horizontal, 16)
                        
                        // 5. RAZDELI RAČUN (Bill Splitter)
                        billSplitSection
                            .padding(.horizontal, 16)
                        
                        // 6. GUMB ZA TAKSI
                        taxiSection
                            .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 80) // Prostor za BottomNavBar
                }
            }
        }
        .sheet(isPresented: $showSquadSheet) {
            SquadView()
        }
        .sheet(isPresented: $showFinalTaxiModal) {
            taxiModalView
        }
        .alert(isPresented: $isTaxiConvincing) {
            let step = allTaxiSteps[currentTaxiConvinceIndex % allTaxiSteps.count]
            return Alert(
                title: Text(step.0),
                message: Text(step.1),
                primaryButton: .default(Text(step.2)) {
                    isTaxiConvincing = false
                },
                secondaryButton: .destructive(Text(step.3)) {
                    if currentTaxiConvinceIndex + 1 < maxTaxiSteps {
                        currentTaxiConvinceIndex += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isTaxiConvincing = true
                        }
                    } else {
                        showFinalTaxiModal = true
                    }
                }
            )
        }
    }
    
    // MARK: - 1. Pivska Klapa Kartica
    private var squadCardSection: some View {
        Button(action: { showSquadSheet = true }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.primaryContainerDark)
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.beerGold)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(squad.activeRoom != nil ? "Pivska Klapa: \(squad.activeRoom!.code)" : "Pivska Klapa (Skupina)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        if squad.activeRoom != nil {
                            Circle().fill(Theme.drajvGreen).frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(squad.activeRoom != nil ? "\(squad.members.count) prijateljev v živo • Klikni za klepet" : "Vstopi v sobo, klepetaj v živo in štej runde!")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.beerGold)
            }
            .padding(14)
            .background(Theme.cardDark)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(squad.activeRoom != nil ? Theme.beerGold : Theme.darkBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - 2. Ruleta Šankov
    private var randomBarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.primaryContainerDark)
                        .frame(width: 36, height: 36)
                    Image(systemName: "dice.fill")
                        .foregroundColor(Theme.beerGold)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ruleta Šankov")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Ne veš, kam naprej? Naj odloči usoda!")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                }
            }
            
            if let bar = randomBar {
                VStack(alignment: .leading, spacing: 8) {
                    Text(bar.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.beerGold)
                    Text(bar.address)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                    
                    Button(action: { bridge.navigateTo(lokal: bar) }) {
                        HStack {
                            Image(systemName: "figure.walk")
                            Text("Vodi me do tja!")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Theme.drajvGreen)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                .background(Theme.surfaceDark)
                .cornerRadius(10)
            }
            
            Button(action: rollRandomBar) {
                HStack {
                    Image(systemName: "dice.fill")
                    Text("Zavrti ruleto")
                        .fontWeight(.bold)
                }
                .font(.system(size: 14))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(LinearGradient(colors: [Theme.beerGold, Color(hex: 0xD97706)], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.black)
                .cornerRadius(10)
            }
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.darkBorder, lineWidth: 1))
    }
    
    // MARK: - 3. Burek Pavza
    private var burekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.primaryContainerDark)
                        .frame(width: 36, height: 36)
                    Text("🥐")
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Burek Pavza")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Rešitev za nočno lakoto z delovnimi časi")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                }
                
                Spacer()
                
                Button(action: { onlyOpenBurek.toggle() }) {
                    Text(onlyOpenBurek ? "Odprto zdaj" : "Vse točke")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(onlyOpenBurek ? Theme.drajvGreen : Theme.surfaceDark)
                        .foregroundColor(onlyOpenBurek ? .black : Theme.textMuted)
                        .cornerRadius(8)
                }
            }
            
            let filteredBureks = onlyOpenBurek ? burekSpots.filter { $0.isOpenNow } : burekSpots
            let displayed = showAllBureks ? filteredBureks : Array(filteredBureks.prefix(3))
            
            VStack(spacing: 8) {
                ForEach(displayed) { spot in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(spot.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 6) {
                                Text(spot.statusBadge.text)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(spot.statusBadge.isGreen ? Theme.drajvGreen : Theme.drajvRed)
                                
                                Text("• \(spot.formattedDistance(from: locationManager.location))")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.beerGold)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { bridge.navigateTo(lokal: spot) }) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Theme.drajvGreen)
                                .clipShape(Circle())
                        }
                    }
                    .padding(10)
                    .background(Theme.surfaceDark)
                    .cornerRadius(10)
                }
            }
            
            if filteredBureks.count > 3 {
                Button(action: { showAllBureks.toggle() }) {
                    Text(showAllBureks ? "Pokaži manj" : "Prikaži vseh \(filteredBureks.count) burek točk")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.beerGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
            }
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.darkBorder, lineWidth: 1))
    }
    
    // MARK: - 4. Kolo "Kdo plača rundo?"
    private var wheelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.primaryContainerDark)
                        .frame(width: 36, height: 36)
                    Image(systemName: "circle.circle.fill")
                        .foregroundColor(Theme.beerGold)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kolo: Kdo plača rundo?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Pravičen žreb naslednjega plačnika piva")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                }
            }
            
            // Prijatelji čipi
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(friendsList, id: \.self) { name in
                        HStack(spacing: 4) {
                            Text(name)
                                .font(.system(size: 12, weight: .medium))
                            if friendsList.count > 2 {
                                Button(action: { friendsList.removeAll { $0 == name } }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9))
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceDark)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            
            // Vnos novega imena
            HStack {
                TextField("Dodaj prijatelja...", text: $newFriendInput)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Theme.surfaceDark)
                    .cornerRadius(8)
                
                Button(action: {
                    if !newFriendInput.trimmingCharacters(in: .whitespaces).isEmpty {
                        friendsList.append(newFriendInput.trimmingCharacters(in: .whitespaces))
                        newFriendInput = ""
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 34, height: 34)
                        .background(Theme.beerGold)
                        .cornerRadius(8)
                }
            }
            
            // Kolo z iglo
            ZStack {
                Circle()
                    .stroke(Theme.beerGold, lineWidth: 6)
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(wheelAngle))
                    .overlay(
                        VStack {
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Theme.drajvRed)
                                .offset(y: -75)
                        }
                    )
                
                Text("🍺")
                    .font(.system(size: 40))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            
            if let payer = selectedPayer {
                VStack(spacing: 4) {
                    Text("Rundo časti: \(payer)! 🍻")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(Theme.beerGold)
                    if let quote = funPayerQuote {
                        Text(quote)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textMuted)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(Theme.surfaceDark)
                .cornerRadius(10)
            }
            
            Button(action: spinWheel) {
                Text(isSpinningWheel ? "Vrtim kolo..." : "Zavrti kolo za rundo")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Theme.beerGold)
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
            .disabled(isSpinningWheel || friendsList.isEmpty)
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.darkBorder, lineWidth: 1))
    }
    
    // MARK: - 5. Razdeli Račun (Bill Splitter)
    private var billSplitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.primaryContainerDark)
                        .frame(width: 36, height: 36)
                    Image(systemName: "banknote.fill")
                        .foregroundColor(Theme.beerGold)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Razdeli Račun")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Kalkulator za delitev zneska z napitnino")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                }
            }
            
            HStack {
                Text("Skupni znesek (€):")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textMuted)
                Spacer()
                TextField("Znesek", text: $totalBillAmount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 100)
                    .padding(6)
                    .background(Theme.surfaceDark)
                    .cornerRadius(6)
            }
            
            HStack {
                Text("Število oseb:")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textMuted)
                Spacer()
                HStack(spacing: 12) {
                    Button(action: { if peopleCount > 1 { peopleCount -= 1 } }) {
                        Text("-").font(.title3).foregroundColor(.white).frame(width: 30, height: 30).background(Theme.surfaceDark).cornerRadius(6)
                    }
                    Text("\(peopleCount)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Button(action: { peopleCount += 1 }) {
                        Text("+").font(.title3).foregroundColor(.white).frame(width: 30, height: 30).background(Theme.surfaceDark).cornerRadius(6)
                    }
                }
            }
            
            HStack(spacing: 8) {
                Text("Napitnina:")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textMuted)
                ForEach(0..<tipOptions.count, id: \.self) { idx in
                    Button(action: { selectedTipIndex = idx }) {
                        Text("\(Int(tipOptions[idx] * 100))%")
                            .font(.system(size: 11, weight: selectedTipIndex == idx ? .bold : .normal))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedTipIndex == idx ? Theme.beerGold : Theme.surfaceDark)
                            .foregroundColor(selectedTipIndex == idx ? .black : .white)
                            .cornerRadius(6)
                    }
                }
            }
            
            // Izračun na osebo
            let total = Double(totalBillAmount.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            let totalWithTip = total * (1.0 + tipOptions[selectedTipIndex])
            let perPerson = peopleCount > 0 ? totalWithTip / Double(peopleCount) : 0.0
            
            HStack {
                Text("Znesek na osebo:")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.2f €", perPerson))
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(Theme.beerGold)
            }
            .padding(12)
            .background(Theme.surfaceDark)
            .cornerRadius(10)
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.darkBorder, lineWidth: 1))
    }
    
    // MARK: - 6. Taksi z naključnim prepričevanjem
    private var taxiSection: some View {
        Button(action: startTaxiConvincing) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.drajvRed.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "car.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.drajvRed)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Končal sem / Pokliči taksi 🚕")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Šaljivo prepričevanje pred varno vrnitvijo domov")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.drajvRed)
            }
            .padding(14)
            .background(Theme.cardDark)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.drajvRed.opacity(0.4), lineWidth: 1))
        }
    }
    
    private var taxiModalView: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "car.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Theme.beerGold)
                
                VStack(spacing: 6) {
                    Text("Čas je za domov... 🚕")
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Text("Ponosno si zdržal večer. Tukaj so številke za varen prevoz:")
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                VStack(spacing: 12) {
                    Link(destination: URL(string: "tel:+38615888888")!) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Taxi Metro: 01 588 88 88")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Theme.beerGold)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    
                    Link(destination: URL(string: "tel:+38615112345")!) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Taxi Laguna: 01 511 23 45")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Theme.surfaceVariantDark)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                
                Button(action: { showFinalTaxiModal = false }) {
                    Text("Prekliči, še malo ostanem...")
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.top, 10)
            }
            .padding(20)
        }
    }
    
    // MARK: - Pomožne funkcije
    private func rollRandomBar() {
        let userPos = locationManager.location ?? LocationManager.defaultCoordinate
        Task {
            do {
                let fetched = try await network.fetchNearbyBars(lat: userPos.latitude, lon: userPos.longitude, radius: 2000, limit: 30)
                DispatchQueue.main.async {
                    if let pick = fetched.randomElement() {
                        self.randomBar = pick
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.randomBar = self.burekSpots.randomElement()
                }
            }
        }
    }
    
    private func spinWheel() {
        isSpinningWheel = true
        selectedPayer = nil
        let turns = Double.random(in: 4...8) * 360.0
        let targetAngle = wheelAngle + turns
        
        withAnimation(.easeOut(duration: 2.5)) {
            wheelAngle = targetAngle
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.isSpinningWheel = false
            self.selectedPayer = self.friendsList.randomElement() ?? "Ti"
            let quotes = [
                "Denar je, da se zapravi!",
                "Legenda večera časti brez pomisleka!",
                "Tvoja jetra morda trpijo, ampak tvoja denarnica bo še bolj!",
                "Runda je sveta stvar!"
            ]
            self.funPayerQuote = quotes.randomElement()
        }
    }
    
    private func startTaxiConvincing() {
        maxTaxiSteps = Int.random(in: 3...6)
        currentTaxiConvinceIndex = 0
        isTaxiConvincing = true
    }
}
