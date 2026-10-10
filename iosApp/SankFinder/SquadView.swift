import SwiftUI

struct SquadView: View {
    @ObservedObject private var squad = SquadManager.shared
    @State private var roomCodeInput: String = ""
    @State private var roomNameInput: String = ""
    @State private var nicknameInput: String = ""
    @State private var messageInput: String = ""
    @State private var selectedTab: Int = 0 // 0 = Vstopi, 1 = Ustvari
    
    var body: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // MATERIAL 3 TOP APP BAR
                MaterialTopAppBar(
                    title: squad.activeRoom != nil ? squad.activeRoom!.name : "Pivska Klapa",
                    showBackButton: false
                ) {
                    if squad.activeRoom != nil {
                        Button(action: { squad.leaveRoom() }) {
                            Text("Zapusti")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Theme.drajvRed)
                        }
                    }
                }
                
                if let alert = squad.bannerAlert {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(Theme.beerGold)
                        Text(alert)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { squad.bannerAlert = nil }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(red: 27/255, green: 94/255, blue: 32/255))
                }
                
                if squad.activeRoom == nil {
                    joinOrCreateRoomView
                } else {
                    activeSquadView
                }
            }
        }
        .onAppear {
            GlobalSyncManager.shared.reportScreen("Pivska Klapa")
            nicknameInput = squad.myUserName
        }
    }
    
    // MARK: - Vstop / Ustvari sobo
    private var joinOrCreateRoomView: some View {
        VStack(spacing: 18) {
            Spacer()
            
            Image(systemName: "person.3.fill")
                .font(.system(size: 54))
                .foregroundColor(Theme.beerGold)
            
            Text("Pivska Klapa")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Poveži se s prijatelji v živo, spremljaj lokacijo na radarju in beležite skupne runde.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.textMuted)
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
            .padding(.top, 8)
            
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
                    TextField("4-mestna koda (npr. PANK)", text: $roomCodeInput)
                        .textCase(.uppercase)
                        .padding(14)
                        .background(Theme.cardDark)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        Task { await squad.joinRoom(code: roomCodeInput) }
                    }) {
                        HStack {
                            if squad.isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text("Vstopi v klapo")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.beerGold)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .disabled(squad.isLoading || roomCodeInput.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    TextField("Ime klape (npr. Petkov pohod)", text: $roomNameInput)
                        .padding(14)
                        .background(Theme.cardDark)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        Task { await squad.createRoom(name: roomNameInput) }
                    }) {
                        HStack {
                            if squad.isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text("Ustvari novo klapo")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.beerGold)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .disabled(squad.isLoading)
                }
                
                if let err = squad.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(Theme.drajvRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .padding(.bottom, 80)
    }
    
    // MARK: - Aktivna soba z živo kodo in klepetom
    private var activeSquadView: some View {
        VStack(spacing: 8) {
            // Glava s kodo za povabilo
            if let room = squad.activeRoom {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(room.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        Text("Koda za vstop: \(room.code)")
                            .font(.subheadline)
                            .fontWeight(.heavy)
                            .foregroundColor(.black.opacity(0.8))
                    }
                    Spacer()
                    Button(action: {
                        UIPasteboard.general.string = room.code
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("Kopiraj")
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.15))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                .background(Theme.beerGold)
                .cornerRadius(14)
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }
            
            // Števec pijač in runda
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tvoje pijače:")
                        .font(.caption)
                        .foregroundColor(Theme.textMuted)
                    Text("\(squad.myDrinksCount) pijač")
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(Theme.beerGold)
                }
                
                Spacer()
                
                Button(action: { squad.incrementDrink() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Spil pijačo")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.beerGold)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
                
                Button(action: { squad.sendChatMessage("Jaz častim naslednjo rundo!", msgType: "round_call") }) {
                    Text("Častim rundo")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.surfaceDark)
                        .foregroundColor(Theme.beerGold)
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
                            
                            Text("\(m.drinksCount) pijač")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.beerAmber)
                        }
                        .frame(width: 58)
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Klepet v živo
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
            
            // Hitre fraze brez emojijev
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quickPhraseButton("Kje ste?")
                    quickPhraseButton("Na zdravje!")
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
                .disabled(messageInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
        }
    }
    
    private func quickPhraseButton(_ text: String) -> some View {
        Button(action: { squad.sendChatMessage(text) }) {
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.surfaceDark)
                .foregroundColor(Theme.beerGold)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.beerGold.opacity(0.4), lineWidth: 1))
        }
    }
    
    private func chatBubble(msg: SquadMessage) -> some View {
        let isMe = msg.senderId == squad.myUserId
        let isSystem = msg.msgType == "system" || msg.senderId == "system"
        
        return HStack {
            if isSystem {
                Spacer()
                Text(msg.content)
                    .font(.caption2)
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Theme.surfaceDark.opacity(0.6))
                    .cornerRadius(10)
                Spacer()
            } else {
                if isMe { Spacer() }
                
                VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                    if !isMe {
                        Text(msg.senderName)
                            .font(.caption2)
                            .foregroundColor(Theme.beerGold)
                            .fontWeight(.bold)
                    }
                    
                    Text(msg.content)
                        .font(.subheadline)
                        .foregroundColor(isMe ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isMe ? Theme.beerGold : Theme.cardDark)
                        .cornerRadius(14)
                }
                
                if !isMe { Spacer() }
            }
        }
    }
}
