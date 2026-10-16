import SwiftUI

struct SquadView: View {
    @ObservedObject private var squad = SquadManager.shared
    @State private var roomCodeInput: String = ""
    @State private var roomNameInput: String = ""
    @State private var nicknameInput: String = ""
    @State private var messageInput: String = ""
    @State private var selectedTab: Int = 0 // 0 = Vstopi, 1 = Ustvari
    @State private var showTrackerSheet: Bool = false
    @State private var isLeaveConvincing: Bool = false
    @State private var currentLeaveStepIndex: Int = 0
    @State private var activeLeaveSteps: [LeaveConvinceStep] = []
    @State private var showShareSheet: Bool = false
    @State private var chatExportText: String = ""
    
    struct LeaveConvinceStep {
        let title: String
        let message: String
        let stayButton: String
        let leaveButton: String
    }
    
    let allLeaveStepsPool: [LeaveConvinceStep] = [
        LeaveConvinceStep(
            title: "A res že greš?!",
            message: "Noč v mestu je še mlada, pipe pa še točijo! Brez tebe klapa nikoli več ne bo ista.",
            stayButton: "Imaš prav, ostanem!",
            leaveButton: "Vseeno grem..."
        ),
        LeaveConvinceStep(
            title: "Lahko greš, ampak kje je runda?!",
            message: "Zlato pravilo Pivske Klape: kdor zapusti mizo pred polnočjo, mora najprej vsem častiti še eno rundo za slovo!",
            stayButton: "Dobra ideja, častim rundo!",
            leaveButton: "Nimam več za rundo, grem..."
        ),
        LeaveConvinceStep(
            title: "Kdo bo pa pel z nami?!",
            message: "Brez tebe klapa ni več ista! Kdo bo pel refrene, tolkel po mizi in držal vzdušje? Ne razdiraj ekipe!",
            stayButton: "Ostajam do konca!",
            leaveButton: "Moram domov..."
        ),
        LeaveConvinceStep(
            title: "Tvoja jetra pravijo: Zdrži!",
            message: "Ravnokar smo se ogreli, ti bi pa že stisnil rep med noge? Saj nismo prišli na otroško čajanko!",
            stayButton: "Ok, še eno pivo z vami!",
            leaveButton: "Moja jetra prosijo milosti..."
        ),
        LeaveConvinceStep(
            title: "Predsednik šanka bo razočaran!",
            message: "Predčasen odhod iz klape se uradno vpiše v register izdajalcev mize. Si res pripravljen na ta sramotni pečat?",
            stayButton: "Nočem sramote, ostajam!",
            leaveButton: "Vseeno sprejmem pečat..."
        ),
        LeaveConvinceStep(
            title: "Kaj pa nočni burek?!",
            message: "Zapustiti klapo pred obveznim nočnim burekom z vsem je protizakonito po 3. členu šankerskega zakonika!",
            stayButton: "Burek me je prepričal!",
            leaveButton: "Burek bo počakal, jaz grem..."
        ),
        LeaveConvinceStep(
            title: "Pivo brez tebe bo žalostno...",
            message: "Natakar ravno odpira nov sod, ti bi pa zapustil svojo zvesto klapo? Daj no, še en požirek!",
            stayButton: "Še en požirek z vami!",
            leaveButton: "Res moram iti..."
        ),
        LeaveConvinceStep(
            title: "Tvoja postelja ne gre nikamor!",
            message: "Postelja bo doma počakala, tale večer in nepozabne zgodbe s klapo pa so samo danes!",
            stayButton: "Res je, postelja počaka!",
            leaveButton: "Moja postelja me kliče..."
        ),
        LeaveConvinceStep(
            title: "Zadnji poskus: Bodi legenda!",
            message: "Legende nikoli ne zapustijo bojišča prve. Bodi tisti, ki zdrži, ne tisti, o katerem se jutri govori z obžalovanjem!",
            stayButton: "Sem legenda, ostajam!",
            leaveButton: "Danes nisem legenda, grem..."
        ),
        LeaveConvinceStep(
            title: "Klapa te ima rada!",
            message: "Poglej okoli sebe – to so tvoji pivski tovariši! Če odideš zdaj, bo na mizi ostal prazen stol in prazno srce.",
            stayButton: "Tudi jaz vas imam rad, ostanem!",
            leaveButton: "Saj se kmalu spet vidimo..."
        )
    ]
    
    var body: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // MATERIAL 3 TOP APP BAR
                MaterialTopAppBar(
                    title: squad.activeRoom != nil ? squad.activeRoom!.name : "Pivska Klapa",
                    showBackButton: false,
                    actions: {
                        if squad.activeRoom != nil {
                            HStack(spacing: 12) {
                                Button(action: exportChat) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Theme.beerGold)
                                }
                                
                                Button(action: startLeaveSequence) {
                                    Text("Zapusti")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Theme.drajvRed)
                                }
                            }
                        }
                    }
                )
                
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
        .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })
        .doneButtonKeyboardToolbar()
        .onAppear {
            GlobalSyncManager.shared.reportScreen("Pivska Klapa")
            nicknameInput = squad.myUserName
        }
        .alert(isPresented: $isLeaveConvincing) {
            guard activeLeaveSteps.indices.contains(currentLeaveStepIndex) else {
                return Alert(title: Text("Pivska Klapa"), dismissButton: .default(Text("V redu")))
            }
            let step = activeLeaveSteps[currentLeaveStepIndex]
            let isLast = (currentLeaveStepIndex == activeLeaveSteps.count - 1)
            
            return Alert(
                title: Text(step.title),
                message: Text(step.message),
                primaryButton: .default(Text(step.stayButton)) {
                    isLeaveConvincing = false
                },
                secondaryButton: .destructive(Text(step.leaveButton)) {
                    if isLast {
                        isLeaveConvincing = false
                        squad.leaveRoom()
                    } else {
                        currentLeaveStepIndex += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            isLeaveConvincing = true
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showTrackerSheet) {
            drinksTrackerSubmenu
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: [chatExportText])
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
                
                // Obvestilo o pogojih in deljenju lokacije
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.beerGold)
                    Text("Z vstopom v klapo soglašaš s Pogoji uporabe in deljenjem lokacije s člani sobe (podatki se samodejno izbrišejo po 24 urah).")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.leading)
                }
                .padding(10)
                .background(Theme.surfaceDark.opacity(0.6))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .padding(.bottom, 80)
    }
    
    // MARK: - Aktivna soba z živo kodo, prečiščenim vrhom in klepetom
    private var activeSquadView: some View {
        VStack(spacing: 8) {
            // Enotna prečiščena statusna vrstica klape (Koda + Submeni za Tracker)
            if let room = squad.activeRoom {
                let totalSquadDrinks = squad.members.map { $0.drinksCount }.reduce(0, +)
                
                HStack(spacing: 10) {
                    // Koda sobe s hitrim kopiranjem
                    Button(action: {
                        UIPasteboard.general.string = room.code
                    }) {
                        HStack(spacing: 4) {
                            Text(room.code)
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(.black)
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black.opacity(0.8))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Theme.beerGold)
                        .cornerRadius(8)
                    }
                    
                    // Gumb za odpiranje podmenija Trackerja pijač
                    Button(action: { showTrackerSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "list.clipboard.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.beerGold)
                            Text("Tracker (\(totalSquadDrinks) piv • \(squad.members.count) oseb)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textMuted)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Theme.surfaceDark)
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Osebni hitri števec [-] [count] [+]
                    HStack(spacing: 6) {
                        Button(action: { squad.decrementDrink() }) {
                            Text("-")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 26, height: 26)
                                .background(Theme.surfaceDark)
                                .cornerRadius(6)
                        }
                        
                        Text("\(squad.myDrinksCount)")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(Theme.beerGold)
                            .frame(minWidth: 20)
                        
                        Button(action: { squad.incrementDrink() }) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 26, height: 26)
                                .background(Theme.beerGold)
                                .cornerRadius(6)
                        }
                    }
                    .padding(3)
                    .background(Theme.cardDark)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            
            // Klepet v živo (prostorno, neobremenjeno zgoraj)
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
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: squad.messages.count) { _ in
                    if let last = squad.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Hitre fraze brez emojijev (Poenoteno z Androidom)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quickPhraseButton("Naročil sem rundo!", msgType: "round_call")
                    quickPhraseButton("Kdo gre na hrano?")
                    quickPhraseButton("Pridem čez 5 min", msgType: "eta")
                    quickPhraseButton("Kje točno sedite?")
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
    
    // MARK: - Podmeni za Tracker pijač (Podroben pregled vseh udeležencev)
    private var drinksTrackerSubmenu: some View {
        ZStack {
            Theme.bgDark.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                // Ročaj za zapiranje
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 10)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pivski Tracker Klape")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Stanje popitih pijač po posameznih članih")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    Button(action: { showTrackerSheet = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(Theme.textMuted)
                    }
                }
                .padding(.horizontal, 20)
                
                let totalDrinks = squad.members.map { $0.drinksCount }.reduce(0, +)
                let leader = squad.members.max(by: { $0.drinksCount < $1.drinksCount })
                
                // Povzetek kartica
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Skupaj popitih piv:")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                        Text("\(totalDrinks) pijač")
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(Theme.beerGold)
                    }
                    Spacer()
                    if let leader = leader, leader.drinksCount > 0 {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Pivski vodja:")
                                .font(.caption)
                                .foregroundColor(Theme.textMuted)
                            Text("\(leader.name) (\(leader.drinksCount))")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(14)
                .background(Theme.cardDark)
                .cornerRadius(14)
                .padding(.horizontal, 20)
                
                // Seznam vseh članov klape
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(squad.members) { member in
                            let isMe = member.id == squad.myUserId
                            HStack(spacing: 12) {
                                Text(String(member.name.prefix(1)).uppercased())
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .frame(width: 38, height: 38)
                                    .background(isMe ? Theme.beerGold : Theme.surfaceDark)
                                    .foregroundColor(isMe ? .black : .white)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Theme.beerGold, lineWidth: 1.5))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isMe ? "\(member.name) (Ti)" : member.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Text(isMe ? "Tvoj profil" : "Član klape")
                                        .font(.caption2)
                                        .foregroundColor(Theme.textMuted)
                                }
                                
                                Spacer()
                                
                                if isMe {
                                    HStack(spacing: 8) {
                                        Button(action: { squad.decrementDrink() }) {
                                            Text("-")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .frame(width: 30, height: 30)
                                                .background(Theme.surfaceDark)
                                                .cornerRadius(6)
                                        }
                                        Text("\(squad.myDrinksCount) pijač")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(Theme.beerGold)
                                        Button(action: { squad.incrementDrink() }) {
                                            Image(systemName: "plus")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.black)
                                                .frame(width: 30, height: 30)
                                                .background(Theme.beerGold)
                                                .cornerRadius(6)
                                        }
                                    }
                                } else {
                                    Text("\(member.drinksCount) pijač")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.beerAmber)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Theme.surfaceDark)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(10)
                            .background(isMe ? Theme.surfaceDark.opacity(0.8) : Theme.cardDark)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Gumb Jaz častim rundo
                Button(action: {
                    squad.sendChatMessage("Jaz častim naslednjo rundo!", msgType: "round_call")
                    showTrackerSheet = false
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Jaz častim naslednjo rundo!")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.beerGold)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func exportChat() {
        guard let room = squad.activeRoom else { return }
        var export = "ŠankFinder - Pivska Klapa: \(room.name) (\(room.code))\n"
        export += "Izvoz klepeta: \(Date().formatted())\n"
        export += "--- Sporočila ---\n"
        for msg in squad.messages {
            export += "\(msg.senderName): \(msg.content)\n"
        }
        export += "--- Osebni števec pijač ---\n"
        export += "Tvoje zabeležene pijače: \(squad.myDrinksCount)\n"
        chatExportText = export
        showShareSheet = true
    }
    
    private func startLeaveSequence() {
        let count = Int.random(in: 3...5)
        var steps = Array(allLeaveStepsPool.shuffled().prefix(count))
        steps.append(
            LeaveConvinceStep(
                title: "Zadnja potrditev: Zapustiti klapo?",
                message: "Prestal si vsa prepričevanja klape! Ali res želiš zapustiti to Pivsko Klapo ter prekiniti klepet v živo in radar prijateljev?",
                stayButton: "Premislil sem si, ostajam!",
                leaveButton: "Dokončno zapusti"
            )
        )
        activeLeaveSteps = steps
        currentLeaveStepIndex = 0
        isLeaveConvincing = true
    }
    
    private func quickPhraseButton(_ text: String, msgType: String = "text") -> some View {
        Button(action: { squad.sendChatMessage(text, msgType: msgType) }) {
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
        let isRound = msg.msgType == "round_call"
        
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
                        .foregroundColor(isRound ? .black : (isMe ? .black : .white))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isRound ? Theme.beerGold : (isMe ? Theme.beerGold : Theme.cardDark))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isRound ? Color.white : Color.clear, lineWidth: 1.5)
                        )
                }
                
                if !isMe { Spacer() }
            }
        }
    }
}

// MARK: - UIActivityViewController ovijalec za deljenje transkripta klepeta
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
