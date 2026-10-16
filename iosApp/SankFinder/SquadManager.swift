import Foundation
import CoreLocation

class SquadManager: ObservableObject {
    static let shared = SquadManager()
    
    @Published var activeRoom: SquadRoom?
    @Published var members: [SquadMember] = []
    @Published var messages: [SquadMessage] = []
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var bannerAlert: String?
    
    let myUserId: String
    @Published var myUserName: String = "Prijatelj"
    @Published var myDrinksCount: Int = 0
    
    private let userAgent = "SankFinderApp-Slovenia/1.0 (https://sankfinder.sluga.me; contact@sluga.me)"
    
    private var webSocketTask: URLSessionWebSocketTask?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        config.timeoutIntervalForRequest = 8.0
        return URLSession(configuration: config)
    }()
    
    // Kandidata: Javna domena in neposredni lokalni IP kot na Androidu
    private let hosts = [
        (host: "sankfinder.sluga.me", useSsl: true),
        (host: "192.168.200.209:8080", useSsl: false)
    ]
    private var currentHostIndex = 0
    private var pingTimer: Timer?
    
    private var currentBaseUrl: String {
        let h = hosts[currentHostIndex]
        return "\(h.useSsl ? "https" : "http")://\(h.host)"
    }
    
    private var currentWsScheme: String {
        return hosts[currentHostIndex].useSsl ? "wss" : "ws"
    }
    
    init() {
        if let savedId = UserDefaults.standard.string(forKey: "sank_user_id") {
            self.myUserId = savedId
        } else {
            let newId = String(UUID().uuidString.prefix(8)).lowercased()
            UserDefaults.standard.set(newId, forKey: "sank_user_id")
            self.myUserId = newId
        }
        
        if let savedName = UserDefaults.standard.string(forKey: "sank_user_name") {
            self.myUserName = savedName
        }
    }
    
    func setUserName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            self.myUserName = trimmed
            UserDefaults.standard.set(trimmed, forKey: "sank_user_name")
        }
    }
    
    // MARK: - Ustvari sobo (Create Room)
    func createRoom(name: String) async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        let roomName = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Pivska Klapa" : name
        
        for (idx, h) in hosts.enumerated() {
            let scheme = h.useSsl ? "https" : "http"
            guard let url = URL(string: "\(scheme)://\(h.host)/api/rooms/create") else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 6.0
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            
            let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
            let signature = SecureStorage.shared.generateSignature(timestamp: timestamp, deviceId: myUserId)
            request.setValue("\(timestamp)", forHTTPHeaderField: "X-Sank-Timestamp")
            request.setValue(signature, forHTTPHeaderField: "X-Sank-Signature")
            request.setValue(myUserId, forHTTPHeaderField: "X-Device-Id")
            
            let body = ["name": roomName]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            do {
                let (data, response) = try await urlSession.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let success = json["success"] as? Bool, success else {
                    continue
                }
                
                self.currentHostIndex = idx
                let roomId = json["roomId"] as? String ?? UUID().uuidString
                let code = json["code"] as? String ?? "KLAP"
                let returnedName = json["name"] as? String ?? roomName
                
                let room = SquadRoom(id: roomId, code: code, name: returnedName)
                
                DispatchQueue.main.async {
                    self.activeRoom = room
                    self.members = [SquadMember(id: self.myUserId, roomCode: code, name: self.myUserName, lat: nil, lon: nil, drinksCount: self.myDrinksCount, lastSeen: "ravnokar")]
                    self.messages = [SquadMessage(id: 1, roomCode: code, senderId: "system", senderName: "ŠankFinder", msgType: "system", content: "Soba '\(returnedName)' je pripravljena! Koda: \(code)", createdAt: "ravnokar")]
                    self.isLoading = false
                }
                
                connectWebSocket(code: code)
                return
            } catch {
                continue
            }
        }
        
        DispatchQueue.main.async {
            self.errorMessage = "Povezava s strežnikom ni uspela. Preveri internetno povezavo ali poskusi znova."
            self.isLoading = false
        }
    }
    
    // MARK: - Pridruži se sobi (Join Room)
    func joinRoom(code: String) async {
        let cleanCode = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard !cleanCode.isEmpty else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        for (idx, h) in hosts.enumerated() {
            let scheme = h.useSsl ? "https" : "http"
            guard let url = URL(string: "\(scheme)://\(h.host)/api/rooms/join") else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 6.0
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            
            let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
            let signature = SecureStorage.shared.generateSignature(timestamp: timestamp, deviceId: myUserId)
            request.setValue("\(timestamp)", forHTTPHeaderField: "X-Sank-Timestamp")
            request.setValue(signature, forHTTPHeaderField: "X-Sank-Signature")
            request.setValue(myUserId, forHTTPHeaderField: "X-Device-Id")
            
            let body = ["code": cleanCode]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            do {
                let (data, response) = try await urlSession.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let success = json["success"] as? Bool, success,
                      let roomObj = json["room"] as? [String: Any] else {
                    continue
                }
                
                self.currentHostIndex = idx
                let room = SquadRoom(
                    id: roomObj["id"] as? String ?? cleanCode,
                    code: roomObj["code"] as? String ?? cleanCode,
                    name: roomObj["name"] as? String ?? "Pivska Klapa"
                )
                
                var parsedMembers: [SquadMember] = []
                if let membersArr = json["members"] as? [[String: Any]] {
                    for m in membersArr {
                        parsedMembers.append(SquadMember(
                            id: m["id"] as? String ?? UUID().uuidString,
                            roomCode: m["room_code"] as? String ?? cleanCode,
                            name: m["name"] as? String ?? "Član",
                            lat: m["lat"] as? Double,
                            lon: m["lon"] as? Double,
                            drinksCount: m["drinks_count"] as? Int ?? 0,
                            lastSeen: m["last_seen"] as? String
                        ))
                    }
                }
                
                var parsedMessages: [SquadMessage] = []
                if let msgsArr = json["messages"] as? [[String: Any]] {
                    for m in msgsArr {
                        parsedMessages.append(SquadMessage(
                            id: (m["id"] as? NSNumber)?.int64Value ?? 0,
                            roomCode: m["room_code"] as? String ?? cleanCode,
                            senderId: m["sender_id"] as? String ?? "",
                            senderName: m["sender_name"] as? String ?? "",
                            msgType: m["msg_type"] as? String ?? "text",
                            content: m["content"] as? String ?? "",
                            createdAt: m["created_at"] as? String ?? ""
                        ))
                    }
                }
                
                DispatchQueue.main.async {
                    self.activeRoom = room
                    self.members = parsedMembers
                    self.messages = parsedMessages.reversed()
                    self.isLoading = false
                }
                
                connectWebSocket(code: cleanCode)
                return
            } catch {
                continue
            }
        }
        
        DispatchQueue.main.async {
            self.errorMessage = "Soba s kodo '\(cleanCode)' ne obstaja ali strežnik ni dosegljiv."
            self.isLoading = false
        }
    }
    
    // MARK: - WebSocket v živo
    private func connectWebSocket(code: String) {
        disconnectWebSocket()
        
        let encName = myUserName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Prijatelj"
        let hostInfo = hosts[currentHostIndex]
        let scheme = hostInfo.useSsl ? "wss" : "ws"
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let signature = SecureStorage.shared.generateSignature(timestamp: timestamp, deviceId: myUserId)
        let urlString = "\(scheme)://\(hostInfo.host)/ws?code=\(code)&name=\(encName)&userId=\(myUserId)&deviceId=\(myUserId)&t=\(timestamp)&sig=\(signature)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("\(timestamp)", forHTTPHeaderField: "X-Sank-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-Sank-Signature")
        request.setValue(myUserId, forHTTPHeaderField: "X-Device-Id")
        request.timeoutInterval = 8.0
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        listenForWsMessages()
        startPingTimer()
        
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }
    
    func disconnectWebSocket() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    func leaveRoom() {
        disconnectWebSocket()
        DispatchQueue.main.async {
            self.activeRoom = nil
            self.members = []
            self.messages = []
        }
    }
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { [weak self] _ in
            self?.webSocketTask?.sendPing { _ in }
        }
    }
    
    private func listenForWsMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleIncomingWsText(text)
                default:
                    break
                }
                self.listenForWsMessages()
            case .failure(let error):
                print("Squad WS napaka: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isConnected = false
                }
            }
        }
    }
    
    private func handleIncomingWsText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        let type = json["type"] as? String ?? ""
        DispatchQueue.main.async {
            switch type {
            // Strežnik index.js oddaja 'new_message' za novo klepetno sporočilo
            case "new_message", "chat":
                let msgObj = (json["message"] as? [String: Any]) ?? json
                let senderId = msgObj["senderId"] as? String ?? (msgObj["sender_id"] as? String ?? "")
                let senderName = msgObj["senderName"] as? String ?? (msgObj["sender_name"] as? String ?? "")
                let content = msgObj["content"] as? String ?? ""
                let msgType = msgObj["msgType"] as? String ?? (msgObj["msg_type"] as? String ?? "text")
                let createdAt = msgObj["createdAt"] as? String ?? (msgObj["created_at"] as? String ?? "ravnokar")
                let id = (msgObj["id"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970)
                
                let newMsg = SquadMessage(
                    id: id,
                    roomCode: self.activeRoom?.code ?? "",
                    senderId: senderId,
                    senderName: senderName,
                    msgType: msgType,
                    content: content,
                    createdAt: createdAt
                )
                
                // Prepreči podvajanje
                if !self.messages.contains(where: { $0.id == newMsg.id && $0.content == newMsg.content }) {
                    self.messages.append(newMsg)
                }
                
                if msgType == "round_call" {
                    self.bannerAlert = "\(senderName) časti naslednjo rundo!"
                }
                
            // Strežnik oddaja 'drinks_updated'
            case "drinks_updated":
                if let uid = json["userId"] as? String,
                   let count = json["drinksCount"] as? Int {
                    if let idx = self.members.firstIndex(where: { $0.id == uid }) {
                        var m = self.members[idx]
                        m = SquadMember(id: m.id, roomCode: m.roomCode, name: m.name, lat: m.lat, lon: m.lon, drinksCount: count, lastSeen: "ravnokar")
                        self.members[idx] = m
                    }
                    if uid == self.myUserId {
                        self.myDrinksCount = count
                    }
                }
                
            // Strežnik oddaja 'peer_location'
            case "peer_location":
                if let uid = json["userId"] as? String,
                   let name = json["name"] as? String,
                   let lat = json["lat"] as? Double,
                   let lon = json["lon"] as? Double {
                    if let idx = self.members.firstIndex(where: { $0.id == uid }) {
                        var m = self.members[idx]
                        m = SquadMember(id: m.id, roomCode: m.roomCode, name: name, lat: lat, lon: lon, drinksCount: m.drinksCount, lastSeen: "ravnokar")
                        self.members[idx] = m
                    } else {
                        let newMem = SquadMember(id: uid, roomCode: self.activeRoom?.code ?? "", name: name, lat: lat, lon: lon, drinksCount: 0, lastSeen: "ravnokar")
                        self.members.append(newMem)
                    }
                }
                
            // Strežnik oddaja 'member_joined'
            case "member_joined":
                if let uid = json["userId"] as? String,
                   let name = json["name"] as? String {
                    if !self.members.contains(where: { $0.id == uid }) {
                        let m = SquadMember(id: uid, roomCode: self.activeRoom?.code ?? "", name: name, lat: nil, lon: nil, drinksCount: 0, lastSeen: "ravnokar")
                        self.members.append(m)
                    }
                    let joinMsg = SquadMessage(
                        id: Int64(Date().timeIntervalSince1970 * 1000),
                        roomCode: self.activeRoom?.code ?? "",
                        senderId: "system",
                        senderName: "Sistem",
                        msgType: "system",
                        content: "\(name) se je pridružil klapi.",
                        createdAt: "ravnokar"
                    )
                    self.messages.append(joinMsg)
                }
                
            // Strežnik oddaja 'member_left'
            case "member_left":
                if let uid = json["userId"] as? String,
                   let name = json["name"] as? String {
                    self.members.removeAll(where: { $0.id == uid })
                    let leaveMsg = SquadMessage(
                        id: Int64(Date().timeIntervalSince1970 * 1000),
                        roomCode: self.activeRoom?.code ?? "",
                        senderId: "system",
                        senderName: "Sistem",
                        msgType: "system",
                        content: "\(name) je zapustil klapo.",
                        createdAt: "ravnokar"
                    )
                    self.messages.append(leaveMsg)
                }
                
            // Strežnik oddaja 'eta_alert'
            case "eta_alert":
                if let name = json["name"] as? String,
                   let target = json["targetLokal"] as? String,
                   let eta = json["etaMinutes"] as? Int {
                    self.bannerAlert = "\(name) prihaja v \(target) čez \(eta) min."
                }
                
            // Strežnik oddaja 'message_deleted' ob izbrisu sporočila na nadzorni plošči
            case "message_deleted":
                if let delId = (json["id"] as? NSNumber)?.int64Value ?? (json["id"] as? Int64) ?? (json["id"] as? Int).map({ Int64($0) }) {
                    self.messages.removeAll(where: { $0.id == delId })
                }
                
            // Strežnik oddaja 'room_closed_by_admin'
            case "room_closed_by_admin":
                self.leaveSquad()
                self.errorMessage = "Sobo je administrator zaprl."
                
            // Strežnik oddaja 'admin_broadcast'
            case "admin_broadcast":
                let title = json["title"] as? String ?? "Obvestilo uprave"
                let msg = json["message"] as? String ?? ""
                if !msg.isEmpty {
                    self.bannerAlert = "\(title): \(msg)"
                }
                
            default:
                break
            }
        }
    }
    
    // MARK: - Pošiljanje podatkov (Uspešno usklajeno s strežnikom server/index.js)
    func sendChatMessage(_ content: String, msgType: String = "text") {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let payload: [String: Any] = [
            "type": "chat_message",
            "content": trimmed,
            "msgType": msgType
        ]
        sendJson(payload)
    }
    
    func incrementDrink() {
        myDrinksCount += 1
        let payload: [String: Any] = [
            "type": "drink_update",
            "delta": 1
        ]
        sendJson(payload)
    }
    
    func decrementDrink() {
        guard myDrinksCount > 0 else { return }
        myDrinksCount -= 1
        let payload: [String: Any] = [
            "type": "drink_update",
            "delta": -1
        ]
        sendJson(payload)
    }
    
    func updateLocation(lat: Double, lon: Double, speed: Float = 0.0) {
        let payload: [String: Any] = [
            "type": "location_update",
            "lat": lat,
            "lon": lon,
            "speed": speed
        ]
        sendJson(payload)
    }
    
    func sendEtaAlert(targetLokal: String, etaMinutes: Int) {
        let payload: [String: Any] = [
            "type": "eta_status",
            "targetLokal": targetLokal,
            "etaMinutes": etaMinutes
        ]
        sendJson(payload)
    }
    
    private func sendJson(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(str)) { error in
            if let error = error {
                print("Napaka pri pošiljanju WS: \(error.localizedDescription)")
            }
        }
    }
}
