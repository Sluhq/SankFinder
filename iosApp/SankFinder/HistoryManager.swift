import Foundation

struct VisitRecord: Identifiable, Codable {
    var id: String = UUID().uuidString
    var barName: String
    var address: String
    var date: String
    var amount: Double
    var rating: Int // 1 do 5
    var note: String
}

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var visits: [VisitRecord] = []
    
    private let storageKey = "sankfinder_history_records"
    
    init() {
        loadVisits()
        // Počisti vzorčne/lažne začetne obiske, ki jih je uporabnik želel odstraniti
        visits.removeAll { $0.id == "1" || $0.id == "2" }
        saveVisits()
    }
    
    func addVisit(barName: String, address: String, amount: Double = 0.0, rating: Int = 5, note: String = "") {
        let formatter = DateFormatter()
        formatter.dateFormat = "d. M. yyyy ob HH:mm"
        let dateStr = formatter.string(from: Date())
        
        let newRecord = VisitRecord(
            barName: barName,
            address: address,
            date: dateStr,
            amount: amount,
            rating: rating,
            note: note
        )
        visits.insert(newRecord, at: 0)
        saveVisits()
    }
    
    func updateVisit(id: String, barName: String, address: String, amount: Double, rating: Int, note: String) {
        if let idx = visits.firstIndex(where: { $0.id == id }) {
            var existing = visits[idx]
            existing.barName = barName
            existing.address = address
            existing.amount = amount
            existing.rating = rating
            existing.note = note
            visits[idx] = existing
            saveVisits()
        }
    }
    
    func deleteVisit(at offsets: IndexSet) {
        visits.remove(atOffsets: offsets)
        saveVisits()
    }
    
    func deleteVisit(id: String) {
        visits.removeAll { $0.id == id }
        saveVisits()
    }
    
    var totalSpent: Double {
        visits.reduce(0.0) { $0 + $1.amount }
    }
    
    private func saveVisits() {
        if let encoded = try? JSONEncoder().encode(visits) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadVisits() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([VisitRecord].self, from: data) {
            self.visits = decoded
        }
    }
}
