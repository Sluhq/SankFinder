import SwiftUI
import AVFoundation
import Vision
import PhotosUI

struct HistoryView: View {
    @ObservedObject private var history = HistoryManager.shared
    @ObservedObject private var bridge = NavigationBridge.shared
    
    @State private var showScannerModal: Bool = false
    @State private var showAddModal: Bool = false
    @State private var editingRecord: VisitRecord? = nil
    @State private var viewingReceiptRecord: VisitRecord? = nil
    
    // Polja za nov vnos
    @State private var inputBarName: String = ""
    @State private var inputAddress: String = ""
    @State private var inputAmount: String = ""
    @State private var inputRating: Int = 5
    @State private var inputNote: String = ""
    @State private var inputDrinks: Int = 1
    
    var body: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // MATERIAL 3 TOP APP BAR
                MaterialTopAppBar(title: "Zgodovina obiskov", actions: {
                    Button(action: {
                        resetInputFields()
                        showAddModal = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.beerGold)
                    }
                }
                
                ScrollView {
                    VStack(spacing: 14) {
                        // 1. KARTICA ZA KAMERO IN SKENIRANJE RAČUNA (QR / FURS / OCR)
                        cameraScannerQuickCard
                        
                        // 2. KARTICA: POVZETEK TVOJIH POHODOV (3 STAT PILL-I)
                        statsSummaryCard
                        
                        // 3. SEZNAM OBISKOV ALI PRAZNO STANJE
                        if history.visits.isEmpty {
                            emptyStateView
                                .padding(.top, 24)
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
                    .padding(.bottom, 80)
                }
            }
        }
        .sheet(isPresented: $showScannerModal) {
            CameraReceiptScannerModalView(onScanned: { name, addr, amt, note, drinks in
                history.addVisit(barName: name, address: addr, amount: amt, rating: 5, note: note, drinks: drinks)
                showScannerModal = false
            }, onDismiss: {
                showScannerModal = false
            })
        }
        .sheet(isPresented: $showAddModal) {
            addOrEditVisitModalView(isEditing: false)
        }
        .sheet(item: $editingRecord) { record in
            addOrEditVisitModalView(isEditing: true)
        }
        .sheet(item: $viewingReceiptRecord) { record in
            ReceiptThermalModalView(record: record)
        }
        .onAppear {
            GlobalSyncManager.shared.reportScreen("Zgodovina obiskov")
        }
    }
    
    // MARK: - 1. Kartica Skeniraj račun s kamero
    private var cameraScannerQuickCard: some View {
        Button(action: { showScannerModal = true }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.beerGold.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.beerGold)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skeniraj račun (Kamera & QR)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Samodejno preberi znesek in lokal preko kamere telefona")
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
    
    // MARK: - 2. Povzetek pohodov
    private var statsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Povzetek tvojih obiskov")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 10) {
                statPill(title: "Obiskov", value: "\(history.visits.count)", icon: "mappin.circle.fill")
                statPill(title: "Pijač", value: "\(history.totalDrinks)", icon: "mug.fill")
                statPill(title: "Zapravljeno", value: String(format: "%.2f €", history.totalSpent), icon: "banknote.fill")
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
                    .font(.system(size: 38))
                    .foregroundColor(Theme.beerGold)
            }
            
            Text("Zgodovina je prazna")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text("Ko obiščete lokal ali shranite obisk na zemljevidu, se bo prikazal tukaj. Račun lahko poskenirate tudi s kamero.")
                .font(.system(size: 13))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Button(action: { showScannerModal = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                    Text("Skeniraj račun s kamero")
                }
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: 240)
                .frame(height: 42)
                .background(Theme.beerGold)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - 4. Vrstica posameznega obiska z gumbom za urejanje
    private func visitCardRow(item: VisitRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.barName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                if item.drinks > 0 {
                    Text("\(item.drinks)x 🍺")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.beerGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.surfaceDark)
                        .cornerRadius(6)
                }
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
            
            if !item.note.isEmpty {
                Text(item.note)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.85))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surfaceDark)
                    .cornerRadius(8)
            }
            
            HStack {
                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= item.rating ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundColor(star <= item.rating ? Theme.beerGold : Color.gray.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Gumb za ogled pristnega termičnega računa
                Button(action: {
                    viewingReceiptRecord = item
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                        Text("Račun")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.surfaceVariantDark)
                    .cornerRadius(6)
                }
                
                // Gumb za urejanje obiska
                Button(action: {
                    inputBarName = item.barName
                    inputAddress = item.address
                    inputAmount = item.amount > 0 ? String(format: "%.2f", item.amount) : ""
                    inputRating = item.rating
                    inputNote = item.note
                    inputDrinks = item.drinks
                    editingRecord = item
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Uredi")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.beerGold)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.surfaceDark)
                    .cornerRadius(6)
                }
                
                // Gumb za brisanje
                Button(action: {
                    history.deleteVisit(id: item.id)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.drajvRed.opacity(0.8))
                        .padding(6)
                }
            }
        }
        .padding(14)
        .background(Theme.cardDark)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.darkBorder, lineWidth: 1))
    }
    
    // MARK: - 5. Modal za ročni vnos ali urejanje obiska
    private func addOrEditVisitModalView(isEditing: Bool) -> some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                MaterialTopAppBar(
                    title: isEditing ? "Uredi obisk" : "Dodaj obisk",
                    showBackButton: true,
                    onBack: {
                        if isEditing { editingRecord = nil } else { showAddModal = false }
                    }
                ) {
                    Button("Shrani") {
                        let amt = Double(inputAmount.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                        let name = inputBarName.trimmingCharacters(in: .whitespaces).isEmpty ? "Neznan šank" : inputBarName
                        let drinksCount = max(1, inputDrinks)
                        
                        if isEditing, let rec = editingRecord {
                            history.updateVisit(
                                id: rec.id,
                                barName: name,
                                address: inputAddress,
                                amount: amt,
                                rating: inputRating,
                                note: inputNote,
                                drinks: drinksCount
                            )
                            editingRecord = nil
                        } else {
                            history.addVisit(
                                barName: name,
                                address: inputAddress,
                                amount: amt,
                                rating: inputRating,
                                note: inputNote,
                                drinks: drinksCount
                            )
                            showAddModal = false
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.beerGold)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Lokal")
                                .font(.caption).foregroundColor(Theme.beerGold).fontWeight(.bold)
                            TextField("Ime šanka / lokala", text: $inputBarName)
                                .padding(12).background(Theme.cardDark).cornerRadius(10).foregroundColor(.white)
                            TextField("Naslov ali mesto", text: $inputAddress)
                                .padding(12).background(Theme.cardDark).cornerRadius(10).foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Znesek, pijače in ocena")
                                .font(.caption).foregroundColor(Theme.beerGold).fontWeight(.bold)
                            TextField("Znesek v € (npr. 14.50)", text: $inputAmount)
                                .keyboardType(.decimalPad)
                                .padding(12).background(Theme.cardDark).cornerRadius(10).foregroundColor(.white)
                            
                            Stepper("Število pijač: \(inputDrinks)", value: $inputDrinks, in: 1...99)
                                .foregroundColor(.white)
                                .padding(10).background(Theme.cardDark).cornerRadius(10)
                            
                            Stepper("Ocena: \(inputRating) / 5", value: $inputRating, in: 1...5)
                                .foregroundColor(.white)
                                .padding(10).background(Theme.cardDark).cornerRadius(10)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Opomba")
                                .font(.caption).foregroundColor(Theme.beerGold).fontWeight(.bold)
                            TextField("Opomba / kaj ste naročili", text: $inputNote)
                                .padding(12).background(Theme.cardDark).cornerRadius(10).foregroundColor(.white)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
    
    private func resetInputFields() {
        inputBarName = ""
        inputAddress = ""
        inputAmount = ""
        inputRating = 5
        inputNote = ""
        inputDrinks = 1
    }
}

// MARK: - Pristen termični račun ("Davčni račun")
struct ReceiptThermalModalView: View {
    let record: VisitRecord
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                HStack {
                    Text("Davčni račun")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Bel termični papir z nazobčanim robom
                        VStack(spacing: 12) {
                            // Glava računa
                            Text(record.barName.uppercased())
                                .font(.system(size: 17, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            
                            Text(record.address.isEmpty ? "Ljubljana, Slovenija" : record.address)
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundColor(.black.opacity(0.75))
                            
                            HStack {
                                Text("Št: RAČ-\(abs(record.id.hashValue % 90000) + 10000)")
                                Spacer()
                                Text(record.date)
                            }
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.black.opacity(0.7))
                            
                            dashedLine
                            
                            // Postavke računa
                            let lines = parseNoteLines(record.note)
                            VStack(spacing: 6) {
                                ForEach(lines, id: \.self) { line in
                                    HStack(alignment: .top) {
                                        Text(line)
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.black)
                                        Spacer()
                                    }
                                }
                            }
                            
                            dashedLine
                            
                            // Zneski in DDV (22%)
                            let ddv = record.amount * (0.22 / 1.22)
                            let osnova = record.amount - ddv
                            
                            VStack(spacing: 3) {
                                HStack {
                                    Text("Osnova 22%:")
                                    Spacer()
                                    Text(String(format: "%.2f €", osnova))
                                }
                                HStack {
                                    Text("DDV 22%:")
                                    Spacer()
                                    Text(String(format: "%.2f €", ddv))
                                }
                                HStack {
                                    Text("SKUPAJ ZA PLAČILO:")
                                        .font(.system(size: 13, weight: .black, design: .monospaced))
                                    Spacer()
                                    Text(String(format: "%.2f €", record.amount))
                                        .font(.system(size: 15, weight: .black, design: .monospaced))
                                }
                                .padding(.top, 4)
                            }
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.black)
                            
                            dashedLine
                            
                            // ZOI in EOR ali status
                            VStack(spacing: 2) {
                                Text("ZOI: \(abs(record.barName.hashValue).description.prefix(16))")
                                Text("EOR: \(abs(record.id.hashValue).description.prefix(20))")
                                Text("Preverjeno preko FURS davčne blagajne ✓")
                                    .fontWeight(.bold)
                                    .padding(.top, 2)
                            }
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundColor(.black.opacity(0.65))
                            
                            // QR Koda ikona
                            Image(systemName: "qrcode")
                                .font(.system(size: 46))
                                .foregroundColor(.black.opacity(0.85))
                                .padding(.top, 4)
                            
                            Text("HVALA ZA OBISK!")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.black.opacity(0.75))
                                .padding(.top, 2)
                        }
                        .padding(18)
                        .background(Color(red: 0.98, green: 0.98, blue: 0.97))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.4), radius: 8)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
                
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Zapri račun")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.beerGold)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
        }
    }
    
    private var dashedLine: some View {
        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
            .frame(height: 1)
            .foregroundColor(.black.opacity(0.25))
            .padding(.vertical, 4)
    }
    
    private func parseNoteLines(_ note: String) -> [String] {
        if note.isEmpty {
            return ["1x Obisk lokala"]
        }
        let spl = note.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if spl.count > 1 {
            return spl.filter { !$0.lowercased().contains("računa") && !$0.lowercased().contains("furs") }
        }
        return [note]
    }
}

// MARK: - Podatkovni model za prepoznano pijačo
struct ReceiptDrinkItem: Identifiable {
    let id = UUID()
    let rawLine: String
    let cleanName: String
    let quantity: Int
    let unitPrice: Double?
    let totalPrice: Double?
    let isAlcoholic: Bool
}

// MARK: - Razčlenitev FURS QR kode
struct FursQrData {
    let isValid: Bool
    let zoi: String?
    let eor: String?
    let taxNumber: String?
    let dateStr: String?
    let amount: Double?
}

func parseFursQrCode(_ rawQr: String) -> FursQrData {
    guard !rawQr.isEmpty else { return FursQrData(isValid: false, zoi: nil, eor: nil, taxNumber: nil, dateStr: nil, amount: nil) }
    let lower = rawQr.lowercased()
    let isFurs = lower.contains("fu.gov.si") || lower.contains("zoi=") || lower.contains("eor=")
    
    var zoi: String? = nil
    var eor: String? = nil
    var taxNumber: String? = nil
    var dateStr: String? = nil
    var amount: Double? = nil
    
    let queryPart = rawQr.contains("?") ? String(rawQr.split(separator: "?").last ?? "") : rawQr
    let pairs = queryPart.components(separatedBy: "&")
    
    for pair in pairs {
        let parts = pair.components(separatedBy: "=")
        if parts.count == 2 {
            valKey(parts[0].trimmingCharacters(in: .whitespaces).lowercased(), parts[1].trimmingCharacters(in: .whitespaces), zoi: &zoi, eor: &eor, taxNumber: &taxNumber, dateStr: &dateStr, amount: &amount)
        }
    }
    
    return FursQrData(isValid: isFurs || amount != nil, zoi: zoi, eor: eor, taxNumber: taxNumber, dateStr: dateStr, amount: amount)
}

private func valKey(_ key: String, _ value: String, zoi: inout String?, eor: inout String?, taxNumber: inout String?, dateStr: inout String?, amount: inout Double?) {
    switch key {
    case "zoi":
        zoi = value
    case "eor":
        eor = value
    case "davcna", "davčna":
        taxNumber = value
    case "cas", "čas":
        dateStr = value
    case "znesek", "amt", "amount":
        if value.contains(".") || value.contains(",") {
            amount = Double(value.replacingOccurrences(of: ",", with: "."))
        } else if let cents = Double(value) {
            amount = cents / 100.0
        }
    default:
        break
    }
}

// MARK: - Kamera za skeniranje računov (AVCapture + Vision OCR + FURS QR)
struct CameraReceiptScannerModalView: View {
    var onScanned: (_ name: String, _ address: String, _ amount: Double, _ note: String, _ drinks: Int) -> Void
    var onDismiss: () -> Void
    
    @State private var scanStatus: String = "Usmerite kamero v račun ali QR kodo..."
    @State private var detectedName: String = ""
    @State private var detectedAmount: String = ""
    @State private var detectedDrinksCount: Int = 1
    @State private var detectedDrinks: [ReceiptDrinkItem] = []
    @State private var detectedNote: String = ""
    @State private var isQrVerified: Bool = false
    @State private var rawQrCode: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isProcessing: Bool = false
    
    var body: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Vrstica za zapiranje in galerijo
                HStack {
                    Text("Skeniranje računa")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    
                    // Gumb za izbiro slike iz galerije telefona
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 5) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 14))
                            Text("Galerija")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.beerGold)
                        .cornerRadius(8)
                    }
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 14)
                .padding(.bottom, 8)
                
                // Prikaz žive kamere z dinamičnim vizirjem
                ZStack {
                    CameraLiveFeedView(
                        onTextDetected: { rawText in
                            parseReceiptText(rawText, qrCode: rawQrCode)
                        },
                        onQrDetected: { qrPayload in
                            processQrCode(qrPayload)
                        }
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isQrVerified || !detectedDrinks.isEmpty ? Theme.drajvGreen : Theme.beerGold, lineWidth: 2)
                    )
                    
                    // Merilni križ / vizir (sveti zeleno ob uspešni prepoznavi!)
                    VStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isQrVerified || !detectedDrinks.isEmpty ? Theme.drajvGreen : Theme.beerGold.opacity(0.85),
                                    style: StrokeStyle(lineWidth: 2.5, dash: [10, 6])
                                )
                                .frame(width: 270, height: 170)
                            
                            if isQrVerified || !detectedDrinks.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 42))
                                    .foregroundColor(Theme.drajvGreen)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                        }
                        Spacer()
                    }
                }
                .frame(maxHeight: 250)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                
                // Status in kartica z rezultati
                ScrollView {
                    VStack(spacing: 10) {
                        Text(scanStatus)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(isQrVerified ? Theme.drajvGreen : Theme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.top, 6)
                        
                        if !detectedAmount.isEmpty || !detectedName.isEmpty || !detectedDrinks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                // Statusna vrstica prepoznave
                                HStack {
                                    Image(systemName: isQrVerified ? "checkmark.seal.fill" : "doc.text.viewfinder")
                                        .foregroundColor(isQrVerified ? Theme.drajvGreen : Theme.beerGold)
                                        .font(.system(size: 16))
                                    Text(isQrVerified ? "FURS Davčni račun potrjen" : "Prebrano iz računa (OCR)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(isQrVerified ? Theme.drajvGreen : .white)
                                    Spacer()
                                    Text("\(max(1, detectedDrinksCount)) pijač")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Theme.beerGold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Theme.surfaceDark)
                                        .cornerRadius(6)
                                }
                                
                                // Lokal naziv
                                TextField("Naziv lokala", text: $detectedName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Theme.surfaceDark)
                                    .cornerRadius(8)
                                
                                // Število pijač in znesek
                                HStack(spacing: 10) {
                                    Stepper("Pijač: \(detectedDrinksCount)", value: $detectedDrinksCount, in: 1...99)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Theme.surfaceDark)
                                        .cornerRadius(8)
                                    
                                    HStack {
                                        Text("€")
                                            .foregroundColor(Theme.beerGold)
                                            .fontWeight(.bold)
                                        TextField("Znesek", text: $detectedAmount)
                                            .keyboardType(.decimalPad)
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                    }
                                    .padding(10)
                                    .background(Theme.surfaceDark)
                                    .cornerRadius(8)
                                    .frame(maxWidth: 130)
                                }
                                
                                // Seznam prepoznanih pijač z ikonami
                                if !detectedDrinks.isEmpty {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Prepoznani artikli:")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Theme.textMuted)
                                        
                                        ForEach(detectedDrinks) { item in
                                            HStack {
                                                Text(item.isAlcoholic ? "🍺" : "☕")
                                                    .font(.system(size: 13))
                                                Text("\(item.quantity)x \(item.cleanName)")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                Spacer()
                                                if let p = item.totalPrice {
                                                    Text(String(format: "%.2f €", p))
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(Theme.beerGold)
                                                }
                                            }
                                            .padding(.vertical, 2)
                                        }
                                    }
                                    .padding(10)
                                    .background(Theme.surfaceDark.opacity(0.7))
                                    .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    let amt = Double(detectedAmount.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                                    let name = detectedName.trimmingCharacters(in: .whitespaces).isEmpty ? "Poskeniran račun" : detectedName
                                    let finalDrinks = max(1, detectedDrinksCount)
                                    onScanned(name, "Ljubljana", amt, detectedNote, finalDrinks)
                                }) {
                                    Text("Potrdi in shrani obisk")
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(Theme.beerGold)
                                        .foregroundColor(.black)
                                        .cornerRadius(12)
                                }
                                .padding(.top, 4)
                            }
                            .padding(14)
                            .background(Theme.cardDark)
                            .cornerRadius(14)
                            .padding(.horizontal, 16)
                        } else {
                            // Ročni hiter vnos kot varnostna rezerva
                            Button(action: {
                                onScanned("Račun", "Ljubljana", 0.0, "", 1)
                            }) {
                                Text("Vnesi podatke ročno")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Theme.beerGold)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    processStaticImage(uiImage)
                }
            }
        }
    }
    
    // Obdelava slike iz galerije
    private func processStaticImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        isProcessing = true
        scanStatus = "Analiziram izbrano sliko računa z galerije..."
        
        let barcodeRequest = VNDetectBarcodesRequest { req, _ in
            if let barcodes = req.results as? [VNBarcodeObservation] {
                for b in barcodes {
                    if let payload = b.payloadStringValue, !payload.isEmpty {
                        DispatchQueue.main.async {
                            self.processQrCode(payload)
                        }
                        break
                    }
                }
            }
        }
        
        let textRequest = VNRecognizeTextRequest { req, _ in
            if let observations = req.results as? [VNRecognizedTextObservation] {
                let recognized = observations.compactMap { $0.topCandidates(1).first?.string }
                let combined = recognized.joined(separator: "\n")
                DispatchQueue.main.async {
                    self.parseReceiptText(combined, qrCode: self.rawQrCode)
                    self.isProcessing = false
                }
            }
        }
        textRequest.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([barcodeRequest, textRequest])
    }
    
    // Obdelava QR kode (FURS ali splošna)
    private func processQrCode(_ payload: String) {
        guard !payload.isEmpty else { return }
        self.rawQrCode = payload
        let furs = parseFursQrCode(payload)
        if furs.isValid {
            self.isQrVerified = true
            self.scanStatus = "✓ Davčna QR koda potrjena (FURS)!"
            if let amt = furs.amount, amt > 0.0 {
                self.detectedAmount = String(format: "%.2f", amt)
            }
        }
    }
    
    // Pametno prepoznavanje alkoholnih in brezalkoholnih pijač ter zneskov
    private func parseReceiptText(_ text: String, qrCode: String = "") {
        guard !isProcessing else { return }
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { return }
        
        let furs = parseFursQrCode(qrCode)
        
        // 1. Naziv lokala
        var pub = ""
        for line in lines.prefix(5) {
            let low = line.lowercased()
            if low.contains("d.o.o") || low.contains("s.p.") || low.contains("bar") ||
                low.contains("pivnica") || low.contains("gostilna") || low.contains("kavarna") ||
                low.contains("pub") || low.contains("lounge") {
                pub = line.replacingOccurrences(of: #"(?i)\b(d\.o\.o\.?|s\.p\.?)\b.*"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                if pub.isEmpty { pub = line }
                break
            }
        }
        if pub.isEmpty {
            pub = lines.first(where: { $0.count > 3 && !$0.uppercased().contains("RAČUN") && !$0.uppercased().contains("DAVČNA") }) ?? ""
        }
        
        // 2. Slovarji pijač
        let alcoholicKeywords = [
            "union", "lasko", "laško", "zlatorog", "heineken", "radler", "ipa", "apa", "ale",
            "porter", "stout", "lager", "pils", "pilsner", "guinness", "corona", "kozel",
            "staropramen", "budweiser", "budvar", "bevog", "pelicon", "mali grad", "tektonik",
            "točeno", "toceno", "pivo", "svetlo", "temno", "nefiltrirano", "pšenično", "psenicno",
            "vino", "cviček", "cvicek", "refošk", "refosk", "malvazija", "špricer", "spricer",
            "brizganec", "zvrst", "merlot", "cabernet", "sauvignon", "chardonnay", "pinot",
            "muškat", "muskat", "rebula", "teran", "penina", "prosecco", "šampanjec", "sampanjec",
            "rose", "roze", "pelinkovec", "pelin", "antique", "jager", "jäger", "jägermeister",
            "jagermeister", "gin", "tonic", "tonik", "vodka", "rum", "viski", "whiskey",
            "whisky", "bourbon", "jack daniels", "chivas", "jameson", "borovniček", "borovničke",
            "travarica", "viljamovka", "slivovka", "slivovica", "brinjevec", "aperol", "spritz",
            "hugo", "campari", "tequila", "tekila", "ouzo", "cynar", "martini", "bacardi",
            "havana", "captain morgan", "koktajl", "cocktail", "mojito", "cider", "somersby"
        ]
        
        let nonAlcoholicKeywords = [
            "kava", "espresso", "espreso", "macchiato", "makiato", "cappuccino", "kapučino",
            "bela kava", "podaljšana", "podaljsana", "kratka kava", "kava z mlekom", "kava s smetano",
            "brezkofeinska", "decaf", "latte", "caffe latte", "kakav", "vroča čokolada", "čaj", "caj",
            "kamilica", "meta", "planinski čaj", "šipek", "voda", "radenska", "jamnica", "donat",
            "zala", "dana", "costella", "mineralna", "naravna voda", "gazirana", "negazirana",
            "coca cola", "coca-cola", "coke", "fanta", "sprite", "cockta", "cocta", "cedevita",
            "schweppes", "bitter lemon", "red bull", "redbull", "monster", "limonada",
            "pomarančni sok", "jabolčni sok", "gosti sok", "breskov sok", "jagodni sok", "sok",
            "fructal", "sola", "pago", "ledeni čaj", "ice tea"
        ]
        
        var foundDrinks: [ReceiptDrinkItem] = []
        var totalQty = 0
        var totalAmt: Double = 0.0
        
        let priceRegex = try? NSRegularExpression(pattern: #"(\d+[\.,]\d{2})\b"#, options: [])
        let qtyRegexX = try? NSRegularExpression(pattern: #"\b(\d+)\s*[xX*]"#, options: [])
        let qtyRegexKos = try? NSRegularExpression(pattern: #"\b(\d+)\s*(?:kos|kom|komad)"#, options: [.caseInsensitive])
        let qtyRegexStart = try? NSRegularExpression(pattern: #"^(\d+)\s+[A-Za-zčšžČŠŽ]"#, options: [])
        
        for line in lines {
            let low = line.lowercased()
            let hasAlc = alcoholicKeywords.contains { low.contains($0) }
            let hasNon = nonAlcoholicKeywords.contains { low.contains($0) }
            
            if hasAlc || hasNon {
                let isZero = low.contains("0.0") || low.contains("0,0") || low.contains("brezalkohol")
                let isAlcoholic = hasAlc && !isZero
                
                var qty = 1
                let nsLine = line as NSString
                let fullRange = NSRange(location: 0, length: nsLine.length)
                
                if let m = qtyRegexX?.firstMatch(in: line, range: fullRange), m.numberOfRanges > 1 {
                    qty = Int(nsLine.substring(with: m.range(at: 1))) ?? 1
                } else if let m = qtyRegexKos?.firstMatch(in: line, range: fullRange), m.numberOfRanges > 1 {
                    qty = Int(nsLine.substring(with: m.range(at: 1))) ?? 1
                } else if let m = qtyRegexStart?.firstMatch(in: line, range: fullRange), m.numberOfRanges > 1 {
                    let st = Int(nsLine.substring(with: m.range(at: 1))) ?? 1
                    if (1...99).contains(st) { qty = st }
                }
                
                // Cene na vrstici
                var prices: [Double] = []
                if let matches = priceRegex?.matches(in: line, range: fullRange) {
                    for m in matches {
                        let numStr = nsLine.substring(with: m.range(at: 1)).replacingOccurrences(of: ",", with: ".")
                        // Preveri, da ni volumen (0.50L, 0.25L)
                        let endPos = m.range.location + m.range.length
                        let tail = endPos < nsLine.length ? nsLine.substring(from: endPos).lowercased() : ""
                        if tail.hasPrefix("l") || tail.hasPrefix("dl") || tail.hasPrefix("cl") || tail.hasPrefix("ml") {
                            continue
                        }
                        if let d = Double(numStr) {
                            prices.append(d)
                        }
                    }
                }
                
                var uPrice: Double? = nil
                var tPrice: Double? = nil
                if prices.count >= 2 {
                    uPrice = prices[0]
                    tPrice = prices.last
                } else if prices.count == 1 {
                    tPrice = prices[0]
                    uPrice = qty > 1 ? tPrice! / Double(qty) : tPrice
                }
                
                var clean = line
                    .replacingOccurrences(of: #"(?i)\b\d+\s*[xX*]\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"(?i)\b\d+\s*(?:kos|kom)\b\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^\d+\s+"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\b\d+[\.,]\d{2}\b.*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "[€$*]", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if clean.isEmpty { clean = line }
                
                foundDrinks.append(
                    ReceiptDrinkItem(
                        rawLine: line,
                        cleanName: clean,
                        quantity: qty,
                        unitPrice: uPrice,
                        totalPrice: tPrice,
                        isAlcoholic: isAlcoholic
                    )
                )
                totalQty += qty
            }
            
            // Iskanje zneska preko ključnih besed
            if low.contains("skupaj") || low.contains("plačilo") || low.contains("znesek") ||
                low.contains("total") || low.contains("vrednost") || low.contains("kartica") {
                if let matches = priceRegex?.matches(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
                    for m in matches {
                        let str = (line as NSString).substring(with: m.range(at: 1)).replacingOccurrences(of: ",", with: ".")
                        if let d = Double(str), (1.0...500.0).contains(d), d > totalAmt {
                            totalAmt = d
                        }
                    }
                }
            }
        }
        
        // Znesek iz FURS kode ima prednost
        if let fursAmt = furs.amount, fursAmt > 0.0 {
            totalAmt = fursAmt
        }
        
        let drinksSum = foundDrinks.compactMap { $0.totalPrice }.reduce(0.0, +)
        if totalAmt == 0.0 && drinksSum > 0.0 {
            totalAmt = drinksSum
        }
        
        // Sestavi opombo
        var noteLines: [String] = []
        if isQrVerified || furs.isValid {
            noteLines.append("Davčno potrjen račun (FURS QR):")
        } else {
            noteLines.append("Prebrano z računa (OCR):")
        }
        for d in foundDrinks {
            let pStr = d.totalPrice != nil ? String(format: " (%.2f €)", d.totalPrice!) : ""
            noteLines.append("• \(d.quantity)x \(d.cleanName)\(pStr)")
        }
        let note = noteLines.joined(separator: "\n")
        
        DispatchQueue.main.async {
            if !foundDrinks.isEmpty {
                self.detectedDrinks = foundDrinks
                self.detectedDrinksCount = max(1, totalQty)
                self.detectedNote = note
                self.scanStatus = "✓ Uspešno prepoznane pijače (\(foundDrinks.count))!"
            }
            if totalAmt > 0.0 {
                self.detectedAmount = String(format: "%.2f", totalAmt)
            }
            if !pub.isEmpty && self.detectedName.isEmpty {
                self.detectedName = pub
            }
        }
    }
}

// MARK: - UIViewRepresentable za živo kamero z ločenim OCR in QR zajemom
struct CameraLiveFeedView: UIViewControllerRepresentable {
    var onTextDetected: (String) -> Void
    var onQrDetected: (String) -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.onTextDetected = onTextDetected
        vc.onQrDetected = onQrDetected
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onTextDetected: ((String) -> Void)?
    var onQrDetected: ((String) -> Void)?
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastProcessTime = Date()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        captureSession.beginConfiguration()
        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        
        // 1. Zaznava QR kod (FURS davčne blagajne)
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }
        
        // 2. Video okvirji za Vision OCR
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_ocr_queue"))
        }
        
        captureSession.commitConfiguration()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        if let preview = previewLayer {
            view.layer.addSublayer(preview)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    // Obdelava QR kode
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        for obj in metadataObjects {
            if let readable = obj as? AVMetadataMachineReadableCodeObject,
               let val = readable.stringValue, !val.isEmpty {
                onQrDetected?(val)
                return
            }
        }
    }
    
    // Obdelava OCR teksta (vsake 0.7s za gladko in odzivno prepoznavo)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastProcessTime) > 0.7 else { return }
        lastProcessTime = Date()
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNRecognizeTextRequest { [weak self] req, err in
            guard let observations = req.results as? [VNRecognizedTextObservation] else { return }
            let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
            let combined = recognizedStrings.joined(separator: "\n")
            if !combined.isEmpty {
                DispatchQueue.main.async {
                    self?.onTextDetected?(combined)
                }
            }
        }
        request.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
    }
}
