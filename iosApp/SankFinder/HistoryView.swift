import SwiftUI
import AVFoundation
import Vision

struct HistoryView: View {
    @ObservedObject private var history = HistoryManager.shared
    @ObservedObject private var bridge = NavigationBridge.shared
    
    @State private var showScannerModal: Bool = false
    @State private var showAddModal: Bool = false
    @State private var editingRecord: VisitRecord? = nil
    
    // Polja za nov vnos
    @State private var inputBarName: String = ""
    @State private var inputAddress: String = ""
    @State private var inputAmount: String = ""
    @State private var inputRating: Int = 5
    @State private var inputNote: String = ""
    
    var body: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // MATERIAL 3 TOP APP BAR
                MaterialTopAppBar(title: "Zgodovina obiskov") {
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
            CameraReceiptScannerModalView(onScanned: { name, addr, amt, note in
                history.addVisit(barName: name, address: addr, amount: amt, rating: 5, note: note)
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
                statPill(title: "Pijač", value: "\(history.visits.count * 2)", icon: "mug.fill")
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
                
                // Gumb za urejanje obiska
                Button(action: {
                    inputBarName = item.barName
                    inputAddress = item.address
                    inputAmount = item.amount > 0 ? String(format: "%.2f", item.amount) : ""
                    inputRating = item.rating
                    inputNote = item.note
                    editingRecord = item
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Uredi")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.beerGold)
                    .padding(.horizontal, 10)
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
                        
                        if isEditing, let rec = editingRecord {
                            history.updateVisit(
                                id: rec.id,
                                barName: name,
                                address: inputAddress,
                                amount: amt,
                                rating: inputRating,
                                note: inputNote
                            )
                            editingRecord = nil
                        } else {
                            history.addVisit(
                                barName: name,
                                address: inputAddress,
                                amount: amt,
                                rating: inputRating,
                                note: inputNote
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
                            Text("Znesek in Ocena")
                                .font(.caption).foregroundColor(Theme.beerGold).fontWeight(.bold)
                            TextField("Znesek v € (npr. 14.50)", text: $inputAmount)
                                .keyboardType(.decimalPad)
                                .padding(12).background(Theme.cardDark).cornerRadius(10).foregroundColor(.white)
                            
                            Stepper("Ocena: \(inputRating) / 5", value: $inputRating, in: 1...5)
                                .foregroundColor(.white)
                                .padding(8).background(Theme.cardDark).cornerRadius(10)
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
    }
}

// MARK: - Kamera za skeniranje računov (AVCapture + Vision OCR)
struct CameraReceiptScannerModalView: View {
    var onScanned: (_ name: String, _ address: String, _ amount: Double, _ note: String) -> Void
    var onDismiss: () -> Void
    
    @State private var scanStatus: String = "Usmerite kamero v račun ali QR kodo..."
    @State private var detectedName: String = ""
    @State private var detectedAmount: String = ""
    @State private var detectedNote: String = ""
    @State private var isProcessing: Bool = false
    @State private var showConfirmSheet: Bool = false
    
    var body: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Vrstica za zapiranje
                HStack {
                    Text("Skeniranje računa")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                // Prikaz žive kamere
                ZStack {
                    CameraLiveFeedView(onTextOrQrDetected: { rawText in
                        parseReceiptText(rawText)
                    })
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.beerGold, lineWidth: 2)
                    )
                    
                    // Merilni križ / vizir
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.beerGold.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .frame(width: 260, height: 180)
                        Spacer()
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 16)
                
                // Status in gumbe spodaj
                VStack(spacing: 12) {
                    Text(scanStatus)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    if !detectedAmount.isEmpty || !detectedName.isEmpty {
                        VStack(spacing: 6) {
                            Text("Prepoznan znesek: \(detectedAmount) €")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.beerGold)
                            if !detectedName.isEmpty {
                                Text("Lokal: \(detectedName)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: {
                                let amt = Double(detectedAmount.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                                onScanned(detectedName.isEmpty ? "Poskeniran račun" : detectedName, "Ljubljana", amt, detectedNote)
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
                        .padding(12)
                        .background(Theme.cardDark)
                        .cornerRadius(14)
                    } else {
                        // Ročni hiter vnos kot varnostna rezerva
                        Button(action: {
                            onScanned("Račun", "Ljubljana", 0.0, "")
                        }) {
                            Text("Vnesi podatke ročno")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.beerGold)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(16)
            }
        }
    }
    
    private func parseReceiptText(_ text: String) {
        guard !isProcessing else { return }
        
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        // Iskanje zneska (EUR / Skupaj / Za plačilo)
        var foundAmount: Double? = nil
        let regex = try? NSRegularExpression(pattern: #"(\d+[\.,]\d{2})"#, options: [])
        
        for line in lines.reversed() {
            let upper = line.uppercased()
            if upper.contains("SKUPAJ") || upper.contains("PLAČILO") || upper.contains("EUR") || upper.contains("ZNESEK") {
                if let match = regex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    if let range = Range(match.range(at: 1), in: line) {
                        let str = String(line[range]).replacingOccurrences(of: ",", with: ".")
                        if let d = Double(str), d > 0 {
                            foundAmount = d
                            break
                        }
                    }
                }
            }
        }
        
        // Če ni našel po ključni besedi, poišči največjo ceno
        if foundAmount == nil {
            for line in lines {
                if let match = regex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    if let range = Range(match.range(at: 1), in: line) {
                        let str = String(line[range]).replacingOccurrences(of: ",", with: ".")
                        if let d = Double(str), d > (foundAmount ?? 0.0) && d < 500.0 {
                            foundAmount = d
                        }
                    }
                }
            }
        }
        
        let possibleName = lines.first(where: { $0.count > 3 && !$0.contains("D.O.O") && !$0.contains("D.N.O") && !$0.contains("RAČUN") }) ?? ""
        
        DispatchQueue.main.async {
            if let amt = foundAmount {
                self.detectedAmount = String(format: "%.2f", amt)
                self.scanStatus = "Račun uspešno prepoznan!"
            }
            if !possibleName.isEmpty && self.detectedName.isEmpty {
                self.detectedName = possibleName
            }
            self.detectedNote = "Poskenirano preko kamere"
        }
    }
}

// MARK: - UIViewRepresentable za prikaz kamere z AVCapture
struct CameraLiveFeedView: UIViewControllerRepresentable {
    var onTextOrQrDetected: (String) -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.onDetected = onTextOrQrDetected
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onDetected: ((String) -> Void)?
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
        
        // 1. QR Koda (FURS davčna blagajna)
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
               let val = readable.stringValue {
                onDetected?(val)
                return
            }
        }
    }
    
    // Obdelava OCR teksta (vsake 0.8s)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastProcessTime) > 0.8 else { return }
        lastProcessTime = Date()
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNRecognizeTextRequest { [weak self] req, err in
            guard let observations = req.results as? [VNRecognizedTextObservation] else { return }
            let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
            let combined = recognizedStrings.joined(separator: "\n")
            if !combined.isEmpty {
                DispatchQueue.main.async {
                    self?.onDetected?(combined)
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
