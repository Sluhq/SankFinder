import SwiftUI

struct GamesView: View {
    @State private var selectedTab: Int = 0 // 0: Alko kalkulator, 1: Ruleta, 2: Resnica/Izziv
    
    // MARK: - Kalkulator promilov
    @State private var weightKg: Double = 75.0
    @State private var isMale: Bool = true
    @State private var beersCount: Int = 3      // 0.5l pivo (ca. 20g alkohola)
    @State private var wineCount: Int = 0       // 2dcl vino (ca. 19g alkohola)
    @State private var shotsCount: Int = 0      // 0.3dcl žganje (ca. 10g alkohola)
    @State private var hoursSinceStart: Double = 2.0
    
    // MARK: - Ruleta
    @State private var rouletteResult: String = "Pritisni gumb za vrtenje!"
    @State private var isSpinning: Bool = false
    
    // MARK: - Resnica ali Izziv
    @State private var truthOrDarePrompt: String = "Izberi Resnico ali Izziv!"
    
    private let rouletteTasks = [
        "🍻 Spij 2 požirka!",
        "👥 Vsi za mizo spijejo požirek!",
        "👉 Izberi soigralca, ki mora spiti cel kozarec!",
        "🛡️ Varno mimo – ne piješ nič!",
        "💃 Naredi 10 počepov ali spij požirek!",
        "🎤 Zapoj refren znane slovenske pesmi!",
        "🔄 Obratna runda: tisti na tvoji desni pije!"
    ]
    
    private let truths = [
        "Katero je bilo tvoje najbolj nerodno pijansko sporočilo bivšemu/bivši?",
        "Kdaj si nazadnje lagal o tem, koliko si v resnici spil?",
        "Kdo za to mizo po tvojem mnenju drži najmanj pijače?",
        "Kakšna je bila tvoja najslabša izkušnja s šankom v mestu?"
    ]
    
    private let dares = [
        "Naroči naslednjo rundo s smešnim naglasom!",
        "Pojdi do natakarja in mu povej vic o pivu!",
        "Menjaj pijačo s soigralcem na tvoji levi za 1 krog!",
        "Odrastel človek ne rabi stola: stoj naslednjih 15 minut!"
    ]
    
    // Izračun promilov po Widmarkovi formuli
    var calculatedPromils: Double {
        let totalAlcoholGrams = Double(beersCount) * 20.0 + Double(wineCount) * 19.0 + Double(shotsCount) * 10.0
        let r = isMale ? 0.68 : 0.55
        let rawPromil = totalAlcoholGrams / (weightKg * r)
        let metabolized = hoursSinceStart * 0.15 // telo razgradi ca. 0.15 promila na uro
        return max(0.0, rawPromil - metabolized)
    }
    
    var timeUntilSoberHours: Double {
        return calculatedPromils / 0.15
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.bgDark.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 16) {
                    // Preklopni gumbi za mini igre
                    HStack(spacing: 8) {
                        tabButton(title: "Alko Merilnik", index: 0, icon: "gauge.medium")
                        tabButton(title: "Pivska Ruleta", index: 1, icon: "die.face.5")
                        tabButton(title: "Resnica / Izziv", index: 2, icon: "questionmark.bubble")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    ScrollView {
                        if selectedTab == 0 {
                            alkoCalculatorView
                        } else if selectedTab == 1 {
                            rouletteView
                        } else {
                            truthOrDareView
                        }
                    }
                }
            }
            .navigationTitle("Zabava & Igre 🍻")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func tabButton(title: String, index: Int, icon: String) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectedTab == index ? Theme.beerGold : Theme.cardDark)
            .foregroundColor(selectedTab == index ? .black : .white)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Alko Kalkulator
    private var alkoCalculatorView: some View {
        VStack(spacing: 16) {
            // Rezultat promilov
            VStack(spacing: 6) {
                Text(String(format: "%.2f ‰", calculatedPromils))
                    .font(.system(size: 46, weight: .black))
                    .foregroundColor(calculatedPromils > 0.5 ? Theme.drajvRed : Theme.beerGold)
                
                Text(promilStatusText)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if calculatedPromils > 0 {
                    Text("Čas do 0.0‰: ca. \(String(format: "%.1f", timeUntilSoberHours)) ur")
                        .font(.caption)
                        .foregroundColor(.appMuted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Theme.cardDark)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Theme.beerGold.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            
            // Nastavitve uporabnika
            VStack(alignment: .leading, spacing: 14) {
                Text("Tvoji podatki:")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Text("Spol:")
                        .foregroundColor(.appMuted)
                    Spacer()
                    Picker("Spol", selection: $isMale) {
                        Text("Moški").tag(true)
                        Text("Ženska").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 160)
                }
                
                HStack {
                    Text("Telesna teža: \(Int(weightKg)) kg")
                        .foregroundColor(.appMuted)
                    Spacer()
                    Slider(value: $weightKg, in: 45...130, step: 1)
                        .accentColor(Theme.beerGold)
                        .frame(width: 160)
                }
                
                HStack {
                    Text("Čas od prve pijače: \(String(format: "%.1f", hoursSinceStart)) h")
                        .foregroundColor(.appMuted)
                    Spacer()
                    Slider(value: $hoursSinceStart, in: 0.5...12, step: 0.5)
                        .accentColor(Theme.beerGold)
                        .frame(width: 160)
                }
            }
            .padding(16)
            .background(Theme.cardDark)
            .cornerRadius(16)
            .padding(.horizontal, 16)
            
            // Števec pijač
            VStack(spacing: 12) {
                drinkCounter(title: "Pivo (0.5 L)", count: $beersCount, icon: "🍺")
                drinkCounter(title: "Vino (2 dcl)", count: $wineCount, icon: "🍷")
                drinkCounter(title: "Žgana pijača (kratki)", count: $shotsCount, icon: "🥃")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
    
    private func drinkCounter(title: String, count: Binding<Int>, icon: String) -> some View {
        HStack {
            Text(icon)
                .font(.title2)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
            
            Button(action: { if count.wrappedValue > 0 { count.wrappedValue -= 1 } }) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            
            Text("\(count.wrappedValue)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.beerGold)
                .frame(width: 28)
            
            Button(action: { count.wrappedValue += 1 }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(Theme.beerGold)
            }
        }
        .padding(12)
        .background(Theme.cardDark)
        .cornerRadius(12)
    }
    
    private var promilStatusText: String {
        if calculatedPromils == 0 {
            return "Popolnoma trezen / varno za volan"
        } else if calculatedPromils < 0.24 {
            return "Blaga sproščenost (dovoljeno za voznike z izpitom)"
        } else if calculatedPromils < 0.5 {
            return "Meja za vožnjo (previdno!)"
        } else if calculatedPromils < 1.0 {
            return "Opitost – avto pusti na parkirišču!"
        } else {
            return "Čas za vodenje domov s ŠankFinderjem!"
        }
    }
    
    // MARK: - Pivska Ruleta
    private var rouletteView: some View {
        VStack(spacing: 24) {
            Text("🎯 Šankovska Ruleta")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 16)
            
            ZStack {
                Circle()
                    .stroke(Theme.beerGold, lineWidth: 6)
                    .frame(width: 220, height: 220)
                
                Text(rouletteResult)
                    .font(.headline)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(24)
            }
            
            Button(action: spinRoulette) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Zavrti ruleto!")
                        .fontWeight(.bold)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.beerGold)
                .foregroundColor(.black)
                .cornerRadius(14)
            }
            .padding(.horizontal, 32)
        }
    }
    
    private func spinRoulette() {
        guard !isSpinning else { return }
        isSpinning = true
        rouletteResult = "Kolo se vrti..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.rouletteResult = self.rouletteTasks.randomElement() ?? "Spij požirek!"
            self.isSpinning = false
        }
    }
    
    // MARK: - Resnica ali Izziv
    private var truthOrDareView: some View {
        VStack(spacing: 20) {
            Text("🤫 Resnica ali Izziv")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 16)
            
            Text(truthOrDarePrompt)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: 160)
                .background(Theme.cardDark)
                .cornerRadius(18)
                .padding(.horizontal, 20)
            
            HStack(spacing: 16) {
                Button(action: { truthOrDarePrompt = truths.randomElement() ?? "" }) {
                    Text("Resnica 💬")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.surfaceDark)
                        .foregroundColor(.beerGold)
                        .cornerRadius(14)
                }
                
                Button(action: { truthOrDarePrompt = dares.randomElement() ?? "" }) {
                    Text("Izziv 🔥")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.beerGold)
                        .foregroundColor(.black)
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
