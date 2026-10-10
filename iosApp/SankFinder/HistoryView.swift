import SwiftUI

struct HistoryView: View {
    @ObservedObject private var history = HistoryManager.shared
    @ObservedObject private var bridge = NavigationBridge.shared
    @State private var showAddModal: Bool = false
    
    @State private var newBarName: String = ""
    @State private var newAddress: String = ""
    @State private var newAmount: String = ""
    @State private var newRating: Int = 5
    @State private var newNote: String = ""
    
    var body: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // MATERIAL 3 TOP APP BAR
                MaterialTopAppBar(title: "Zgodovina obiskov") {
                    Button(action: { showAddModal = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.beerGold)
                    }
                }
                
                ScrollView {
                    VStack(spacing: 14) {
                        // 1. KARTICA ZA SKENIRANJE RAČUNA (QR / FURS)
                        qrScannerQuickCard
                        
                        // 2. KARTICA: POVZETEK TVOJIH POHODOV (3 STAT PILL-I KOT NA ANDROIDU)
                        statsSummaryCard
                        
                        // 3. SEZNAM OBISKOV ALI PRAZNO STANJE
                        if history.visits.isEmpty {
                            emptyStateView
                                .padding(.top, 20)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(history.visits) { item in
                                    visitCardRow(item: item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 80) // Prostor za BottomNavBar
                }
            }
        }
        .sheet(isPresented: $showAddModal) {
            addVisitModalView
        }
        .onAppear {
            GlobalSyncManager.shared.reportScreen("Zgodovina obiskov")
        }
    }
    
    // MARK: - 1. Kartica Skeniraj račun (QR)
    private var qrScannerQuickCard: some View {
        Button(action: { showAddModal = true }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.beerGold.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.beerGold)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skeniraj račun (QR koda / FURS)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Samodejno preberi pijače in znesek ter osveži zgodovino")
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
                    .stroke(Theme.beerGold.opacity(0.4), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 2. Povzetek tvojih pohodov (3 StatPill kot na Androidu)
    private var statsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Povzetek tvojih pohodov")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 10) {
                statPill(title: "Obiskov", value: "\(history.visits.count)", icon: "mappin.circle.fill")
                statPill(title: "Pijač", value: "\(history.visits.count * 2)", icon: "mug.fill")
                statPill(title: "Zapravljeno", value: String(format: "%.1f €", history.totalSpent), icon: "banknote.fill")
            }
        }
        .padding(14)
        .background(Theme.surfaceVariantDark.opacity(0.45))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.darkBorder, lineWidth: 1))
    }
    
    private func statPill(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.beerGold)
            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surfaceDark)
        .cornerRadius(12)
    }
    
    // MARK: - 3. Prazno stanje
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.primaryContainerDark)
                    .frame(width: 80, height: 80)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.beerGold)
            }
            
            Text("Zgodovina je še prazna")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text("Ko obiščete lokal ali kliknete 'Označi' pri poljubnem šanku, se bo vaša pot zabeležila tukaj. Lahko pa že takoj poskenirate račun!")
                .font(.system(size: 13))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Button(action: { showAddModal = true }) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Skeniraj račun (QR)")
                }
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: 240)
                .frame(height: 42)
                .background(Theme.beerGold)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
            
            Button(action: { bridge.selectedTab = 0 }) {
                HStack {
                    Image(systemName: "mug.fill")
                    Text("Poišči šank v bližini")
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: 240)
                .frame(height: 42)
                .foregroundColor(Theme.beerGold)
                .background(Theme.surfaceDark)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.beerGold.opacity(0.5), lineWidth: 1))
            }
        }
    }
    
    // MARK: - 4. Vrstica posameznega obiska
    private func visitCardRow(item: VisitRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.barName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if item.amount > 0 {
                    Text(String(format: "%.2f €", item.amount))
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(Theme.beerGold)
                }
            }
            
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.drajvRed)
                Text(item.address.isEmpty ? "Ljubljana" : item.address)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textMuted)
                Spacer()
                Text(item.date)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted)
            }
            
            HStack {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= item.rating ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundColor(star <= item.rating ? Theme.beerGold : Color.gray.opacity(0.5))
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if let idx = history.visits.firstIndex(where: { $0.id == item.id }) {
                        history.deleteVisit(at: IndexSet(integer: idx))
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray)
                }
            }
            
            if !item.note.isEmpty {
                Text(item.note)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.85))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surfaceDark)
                    .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.darkBorder, lineWidth: 1))
    }
    
    // MARK: - 5. Modal za ročni vnos obiska
    private var addVisitModalView: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                MaterialTopAppBar(title: "Dodaj Obisk", showBackButton: true, onBack: { showAddModal = false }) {
                    Button("Shrani") {
                        let amt = Double(newAmount.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                        let name = newBarName.trimmingCharacters(in: .whitespaces).isEmpty ? "Neznan šank" : newBarName
                        history.addVisit(barName: name, address: newAddress, amount: amt, rating: newRating, note: newNote)
                        newBarName = ""
                        newAddress = ""
                        newAmount = ""
                        newNote = ""
                        showAddModal = false
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.beerGold)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Lokal")
                                .font(.caption).foregroundColor(Theme.beerGold).fontWeight(.bold)
                            TextField("Ime šanka / lokala", text: $newBarName)
                                .padding(12).background(Theme.cardDark).cornerRadius(10).foregroundColor(.white)
                            TextField("Naslov ali mesto", text: $newAddress)
                                .padding(12).background(Theme.cardDark).cornerRadius(10).foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Znesek in Ocena")
                                .font(.caption).foregroundColor(Theme.beerGold).fontWeight(.bold)
                            TextField("Znesek računa v € (npr. 12.50)", text: $newAmount)
                                .keyboardType(.decimalPad)
                                .padding(12).background(Theme.cardDark).cornerRadius(10).foregroundColor(.white)
                            
                            Stepper("Ocena: \(newRating) ⭐", value: $newRating, in: 1...5)
                                .foregroundColor(.white)
                                .padding(8).background(Theme.cardDark).cornerRadius(10)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Opomba")
                                .font(.caption).foregroundColor(Theme.beerGold).fontWeight(.bold)
                            TextField("Kaj ste pili ali posebnosti?", text: $newNote)
                                .padding(12).background(Theme.cardDark).cornerRadius(10).foregroundColor(.white)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}
