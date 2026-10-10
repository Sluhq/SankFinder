import SwiftUI

struct SquadView: View {
    @StateObject private var squad = SquadManager.shared
    @State private var roomCodeInput: String = ""
    @State private var roomNameInput: String = "Pivska Klapa"
    @State private var nicknameInput: String = SquadManager.shared.myUserName
    @State private var messageInput: String = ""
    @State private var selectedTab: Int = 0 // 0: Pridruži se, 1: Ustvari novo
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.bgDark.edgesIgnoringSafeArea(.all)
                
                if let room = squad.activeRoom {
                    activeRoomView(room: room)
                } else {
                    joinOrCreateRoomView
                }
                
                if squad.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .beerGold))
                        .scaleEffect(1.4)
                        .padding(20)
                        .background(Theme.cardDark.opacity(0.85))
                        .cornerRadius(12)
                }
            }
            .navigationTitle(squad.activeRoom == nil ? "Pivska Klapa" : "Soba: \(squad.activeRoom!.code)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if squad.activeRoom != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Zapusti") {
                            squad.leaveRoom()
                        }
                        .foregroundColor(Theme.drajvRed)
                    }
                }
            }
            .onAppear {
                GlobalSyncManager.shared.reportScreen("Pivska Klapa")
            }
        }
    }
    
    // MARK: - Vstop / Ustvari sobo
    private var joinOrCreateRoomView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("👥")
                .font(.system(size: 64))
            
            Text("Pivska Klapa")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Poveži se s prijatelji v živo, spremljaj lokacijo na radirju in štejte runde!")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.appMuted)
                .padding(.horizontal, 32)
            
            // Preklop med Pridruži se in Ustvari novo
            HStack(spacing: 0) {
                Button(action: { selectedTab = 0 }) {
                    Text("Vstopi s kodo")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == 0 ? Theme.beerGold : Theme.cardDark)
                        .foregroundColor(selectedTab == 0 ? .black : .white)
                }
                
                Button(action: { selectedTab = 1 }) {
                    Text("Ustvari novo")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == 1 ? Theme.beerGold : Theme.cardDark)
                        .foregroundColor(selectedTab == 1 ? .black : .white)
                }
            }
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.top, 10)
            
            VStack(spacing: 12) {
                TextField("Tvoj vzdevek", text: $nicknameInput)
                    .onChange(of: nicknameInput) { val in
                        squad.setUserName(val)
                    }
                    .padding(14)
                    .background(Theme.cardDark)
                    .cornerRadius(12)
                    .foregroundColor(.white)
                
                if selectedTab == 0 {
                    TextField("4-mestna koda sobe (npr. VIKEND)", text: $roomCodeInput)
                        .padding(14)
                        .background(Theme.cardDark)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .autocapitalization(.allCharacters)
                } else {
                    TextField("Ime klape (npr. Petkova runda)", text: $roomNameInput)
                        .padding(14)
                        .background(Theme.cardDark)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 24)
            
            if let err = squad.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(Theme.drajvRed)
                    .padding(.horizontal, 24)
            }
            
            Button(action: {
                squad.setUserName(nicknameInput)
                Task {
                    if selectedTab == 0 {
                        await squad.joinRoom(code: roomCodeInput)
                    } else {
                        await squad.createRoom(name: roomNameInput)
                    }
                }
            }) {
                HStack {
                    Image(systemName: selectedTab == 0 ? "arrow.right.circle.fill" : "plus.circle.fill")
                    Text(selectedTab == 0 ? "Vstopi v Klapo" : "Ustvari Klapo")
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
    
    // MARK: - Aktivna soba z živim klepetom in rundami
    private func activeRoomView(room: SquadRoom) -> some View {
        VStack(spacing: 10) {
            // Glava s statusom povezave
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(squad.isConnected ? Theme.drajvGreen : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(squad.isConnected ? "Povezava v živo (OK)" : "Povezovanje...")
                        .font(.caption2)
                        .foregroundColor(.appMuted)
                }
                
                Spacer()
                
                Text("Koda: ")
                    .font(.caption)
                    .foregroundColor(.appMuted)
                Text(room.code)
                    .font(.headline)
                    .fontWeight(.black)
                    .foregroundColor(.beerGold)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            
            // Opozorilni banner (npr. Luka časti rundo!)
            if let alert = squad.bannerAlert {
                HStack {
                    Text(alert)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    Spacer()
                    Button(action: { squad.bannerAlert = nil }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                    }
                }
                .padding(12)
                .background(Theme.beerGold)
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
            
            // Runda Tracker & Osebni števec
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tvoje pijače:")
                        .font(.caption)
                        .foregroundColor(.appMuted)
                    Text("\(squad.myDrinksCount) 🍺")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.beerGold)
                }
                
                Spacer()
                
                Button(action: { squad.incrementDrink() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Spil pijačo!")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.beerGold)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
                
                Button(action: { squad.sendChatMessage("🍻 Jaz častim naslednjo rundo!", msgType: "round_call") }) {
                    Text("Častim rundo! 🎉")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.surfaceDark)
                        .foregroundColor(.beerGold)
                        .cornerRadius(8)
                }
            }
            .padding(12)
            .background(Theme.cardDark)
            .cornerRadius(14)
            .padding(.horizontal, 16)
            
            // Člani Klape
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(squad.members) { m in
                        VStack(spacing: 3) {
                            Text(String(m.name.prefix(1)).uppercased())
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .frame(width: 38, height: 38)
                                .background(m.id == squad.myUserId ? Theme.beerGold : Theme.surfaceDark)
                                .foregroundColor(m.id == squad.myUserId ? .black : .white)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.beerGold, lineWidth: 1))
                            
                            Text(m.name)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text("\(m.drinksCount) 🍺")
                                .font(.system(size: 10))
                                .foregroundColor(.beerAmber)
                        }
                        .frame(width: 58)
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Klepet
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(squad.messages) { msg in
                            chatBubble(msg: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
                .onChange(of: squad.messages.count) { _ in
                    if let last = squad.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Hitre fraze
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quickPhraseButton("Kje ste?")
                    quickPhraseButton("Na zdravje! 🍻")
                    quickPhraseButton("Še eno rundo!")
                    quickPhraseButton("Kdaj gremo naprej?")
                }
                .padding(.horizontal, 16)
            }
            
            // Vnos sporočila
            HStack(spacing: 8) {
                TextField("Sporočilo klapi...", text: $messageInput)
                    .padding(10)
                    .background(Theme.cardDark)
                    .cornerRadius(12)
                    .foregroundColor(.white)
                
                Button(action: {
                    squad.sendChatMessage(messageInput)
                    messageInput = ""
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.black)
                        .padding(10)
                        .background(Theme.beerGold)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
    
    private func chatBubble(msg: SquadMessage) -> some View {
        let isMe = msg.senderId == squad.myUserId
        let isSystem = msg.msgType == "system" || msg.senderId == "system"
        let isRound = msg.msgType == "round_call"
        
        return HStack {
            if isMe { Spacer() }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                if !isMe && !isSystem {
                    Text(msg.senderName)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.beerGold)
                }
                
                Text(msg.content)
                    .font(.subheadline)
                    .padding(10)
                    .background(
                        isSystem ? Theme.surfaceDark :
                        isRound ? Theme.beerGold :
                        isMe ? Theme.beerGold.opacity(0.85) : Theme.cardDark
                    )
                    .foregroundColor(isRound || (isMe && !isSystem) ? .black : .white)
                    .cornerRadius(12)
                
                if !msg.createdAt.isEmpty {
                    Text(msg.createdAt)
                        .font(.system(size: 9))
                        .foregroundColor(.appMuted)
                }
            }
            
            if !isMe { Spacer() }
        }
    }
    
    private func quickPhraseButton(_ text: String) -> some View {
        Button(action: { squad.sendChatMessage(text) }) {
            Text(text)
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.cardDark)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
}
