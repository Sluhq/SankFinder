import SwiftUI

struct SquadView: View {
    @State private var roomCode: String = ""
    @State private var joinedRoom: String? = nil
    @State private var nickname: String = "Pivski Mojster"
    @State private var myDrinks: Int = 2
    
    @State private var members: [SquadMember] = [
        SquadMember(id: "1", roomCode: "PETEK", name: "Anže", lat: 46.056, lon: 14.505, drinksCount: 4, lastSeen: "ravnokar"),
        SquadMember(id: "2", roomCode: "PETEK", name: "Luka", lat: 46.057, lon: 14.506, drinksCount: 3, lastSeen: "pred 2 min"),
        SquadMember(id: "3", roomCode: "PETEK", name: "Maja", lat: 46.055, lon: 14.504, drinksCount: 2, lastSeen: "pred 5 min")
    ]
    
    @State private var chatMessages: [SquadMessage] = [
        SquadMessage(id: 1, roomCode: "PETEK", senderId: "1", senderName: "Anže", msgType: "text", content: "Kje se dobimo fantje?", createdAt: "20:15"),
        SquadMessage(id: 2, roomCode: "PETEK", senderId: "2", senderName: "Luka", msgType: "round_call", content: "🍻 Jaz častim naslednjo rundo v Cukrarni!", createdAt: "20:20")
    ]
    
    @State private var messageInput: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.bgDark.edgesIgnoringSafeArea(.all)
                
                if let room = joinedRoom {
                    activeSquadView(room: room)
                } else {
                    joinSquadView
                }
            }
            .navigationTitle(joinedRoom == nil ? "Pivska Klapa" : "Soba: \(joinedRoom!)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if joinedRoom != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Zapusti") {
                            joinedRoom = nil
                        }
                        .foregroundColor(Theme.drajvRed)
                    }
                }
            }
        }
    }
    
    // MARK: - Join / Create Room
    private var joinSquadView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("👥")
                .font(.system(size: 60))
            
            Text("Pivska Klapa")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Pridruži se prijateljem, spremljaj lokacijo v živo in glej, kdo je na vrsti za rundo!")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.appMuted)
                .padding(.horizontal, 32)
            
            VStack(spacing: 12) {
                TextField("Tvoj vzdevek", text: $nickname)
                    .padding(14)
                    .background(Theme.cardDark)
                    .cornerRadius(12)
                    .foregroundColor(.white)
                
                TextField("Koda sobe (npr. VIKEND)", text: $roomCode)
                    .padding(14)
                    .background(Theme.cardDark)
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .autocapitalization(.allCharacters)
            }
            .padding(.horizontal, 24)
            
            Button(action: {
                if !roomCode.isEmpty {
                    joinedRoom = roomCode.uppercased()
                } else {
                    joinedRoom = "ŠANK-VIP"
                }
            }) {
                HStack {
                    Image(systemName: "person.3.fill")
                    Text("Vstopi v Klapo")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.beerGold)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Active Squad View
    private func activeSquadView(room: String) -> some View {
        VStack(spacing: 12) {
            // Runda Tracker & Osebni števec
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tvoje pijače danes:")
                        .font(.caption)
                        .foregroundColor(.appMuted)
                    Text("\(myDrinks) 🍺")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.beerGold)
                }
                
                Spacer()
                
                Button(action: { myDrinks += 1 }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Spil pijačo!")
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.beerGold)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
            }
            .padding(14)
            .background(Theme.cardDark)
            .cornerRadius(16)
            .padding(.horizontal, 16)
            
            // Člani Klape
            VStack(alignment: .leading, spacing: 8) {
                Text("Člani v sobi:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.appMuted)
                    .padding(.horizontal, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(members) { m in
                            VStack(spacing: 4) {
                                Text(m.name.prefix(1))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.surfaceDark)
                                    .foregroundColor(.beerGold)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Theme.beerGold, lineWidth: 1.5))
                                
                                Text(m.name)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                
                                Text("\(m.drinksCount) 🍺")
                                    .font(.caption2)
                                    .foregroundColor(.beerAmber)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Klepet & Klici rund
            VStack(spacing: 8) {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(chatMessages) { msg in
                            HStack {
                                if msg.senderId == "1" {
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(msg.content)
                                            .padding(10)
                                            .background(Theme.beerGold.opacity(0.85))
                                            .foregroundColor(.black)
                                            .cornerRadius(12)
                                        Text(msg.createdAt)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(msg.senderName)
                                            .font(.caption2)
                                            .foregroundColor(.beerGold)
                                        Text(msg.content)
                                            .padding(10)
                                            .background(Theme.cardDark)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                        Text(msg.createdAt)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                
                // Vnos sporočila
                HStack {
                    TextField("Sporočilo klapi...", text: $messageInput)
                        .padding(10)
                        .background(Theme.cardDark)
                        .cornerRadius(10)
                        .foregroundColor(.white)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.beerGold)
                            .padding(10)
                            .background(Theme.surfaceDark)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }
    
    private func sendMessage() {
        guard !messageInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let newMsg = SquadMessage(
            id: Int64(chatMessages.count + 1),
            roomCode: joinedRoom ?? "SOBA",
            senderId: "1",
            senderName: nickname,
            msgType: "text",
            content: messageInput,
            createdAt: "ravnokar"
        )
        chatMessages.append(newMsg)
        messageInput = ""
    }
}
