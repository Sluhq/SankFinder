import SwiftUI

struct HistoryView: View {
    @ObservedObject private var history = HistoryManager.shared
    @State private var showAddModal: Bool = false
    
    @State private var newBarName: String = ""
    @State private var newAddress: String = ""
    @State private var newAmount: String = ""
    @State private var newRating: Int = 5
    @State private var newNote: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.bgDark.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 12) {
                    // Statistika na vrhu
                    HStack(spacing: 14) {
                        statCard(title: "Obiskov", value: "\(history.visits.count)", icon: "building.2.fill")
                        statCard(title: "Skupaj poraba", value: String(format: "%.2f €", history.totalSpent), icon: "banknote.fill")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    if history.visits.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Text("📜")
                                .font(.system(size: 48))
                            Text("Ni zabeleženih obiskov")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Ko boš v šanku, ga shrani s klikom na 'Shrani obisk'!")
                                .font(.caption)
                                .foregroundColor(.appMuted)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(history.visits) { item in
                                visitRow(item: item)
                                    .listRowBackground(Theme.bgDark)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowSeparator(.hidden)
                            }
                            .onDelete(perform: history.deleteVisit)
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("Zgodovina Obiskov")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddModal = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.beerGold)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddModal) {
                addVisitModal
            }
            .onAppear {
                GlobalSyncManager.shared.reportScreen("Zgodovina obiskov")
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func statCard(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.beerGold.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(.beerGold)
                    .font(.subheadline)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.appMuted)
                Text(value)
                    .font(.headline)
                    .fontWeight(.black)
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.cardDark)
        .cornerRadius(14)
    }
    
    private func visitRow(item: VisitRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.barName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                if item.amount > 0 {
                    Text(String(format: "%.2f €", item.amount))
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.beerGold)
                }
            }
            
            HStack {
                Text(item.date)
                    .font(.caption2)
                    .foregroundColor(.appMuted)
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= item.rating ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundColor(star <= item.rating ? .beerGold : .gray)
                    }
                }
            }
            
            if !item.note.isEmpty {
                Text(item.note)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Theme.cardDark)
        .cornerRadius(14)
    }
    
    private var addVisitModal: some View {
        NavigationView {
            Form {
                Section(header: Text("LOKAL").foregroundColor(.beerGold)) {
                    TextField("Ime šanka / lokala", text: $newBarName)
                    TextField("Naslov ali mesto", text: $newAddress)
                }
                
                Section(header: Text("ZNESEK IN OCENA").foregroundColor(.beerGold)) {
                    TextField("Znesek računa v € (npr. 12.50)", text: $newAmount)
                        .keyboardType(.decimalPad)
                    
                    Stepper("Ocena: \(newRating) ⭐", value: $newRating, in: 1...5)
                }
                
                Section(header: Text("OPOMBA / VTISI").foregroundColor(.beerGold)) {
                    TextField("Kaj ste pili ali posebnosti?", text: $newNote)
                }
            }
            .navigationTitle("Dodaj Obisk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Prekliči") { showAddModal = false }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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
                    .foregroundColor(.beerGold)
                    .fontWeight(.bold)
                }
            }
        }
    }
}
