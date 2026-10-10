import Foundation

struct VisitRecord: Identifiable, Codable {
    var id: String = UUID().uuidString
    let barName: String
    let address: String
    let date: String
    let amount: Double
    let rating: Int // 1 do 5
    let note: String
}

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var visits: [VisitRecord] = []
    
    private let storageKey = "sankfinder_history_records"
    
    init() {
        loadVisits()
        if visits.isEmpty {
            // Začetni vzorčni obiski
            visits = [
                VisitRecord(id: "1", barName: "Dvorni Bar", address: "Dvorni trg 2, Ljubljana", date: "Včeraj ob 21:30", amount: 14.50, rating: 5, note: "Odlična družba in prijazna postrežba!"),
                VisitRecord(id: "2", barName: "Kolibri Bar", address: "Židovska steza 2, Ljubljana", date: "Petek ob 23:15", amount: 22.00, rating: 4, note: "Pivska runda s prijatelji.")
            ]
            saveVisits()
        }
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
    
    func deleteVisit(at offsets: IndexSet) {
        visits.remove(atOffsets: offsets)
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
