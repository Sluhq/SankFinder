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
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession = URLSession(configuration: .default)
    private let baseUrl = "https://sankfinder.sluga.me"
    
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
        guard let url = URL(string: "\(baseUrl)/api/rooms/create") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["name": roomName]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success else {
                throw NSError(domain: "Squad", code: 400, userInfo: [NSLocalizedDescriptionKey: "Napaka pri ustvarjanju sobe na strežniku."])
            }
            
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
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
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
        
        guard let url = URL(string: "\(baseUrl)/api/rooms/join") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["code": cleanCode]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success,
                  let roomObj = json["room"] as? [String: Any] else {
                throw NSError(domain: "Squad", code: 404, userInfo: [NSLocalizedDescriptionKey: "Soba s kodo '\(cleanCode)' ne obstaja ali je že potekla."])
            }
            
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
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - WebSocket v živo
    private func connectWebSocket(code: String) {
        disconnectWebSocket()
        
        let encName = myUserName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Prijatelj"
        let urlString = "wss://sankfinder.sluga.me/ws?code=\(code)&name=\(encName)&userId=\(myUserId)"
        guard let url = URL(string: urlString) else { return }
        
        let request = URLRequest(url: url)
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        listenForWsMessages()
        
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }
    
    func disconnectWebSocket() {
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
            case "chat":
                if let msgObj = json["message"] as? [String: Any] {
                    let msg = SquadMessage(
                        id: (msgObj["id"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970),
                        roomCode: msgObj["room_code"] as? String ?? (self.activeRoom?.code ?? ""),
                        senderId: msgObj["sender_id"] as? String ?? "",
                        senderName: msgObj["sender_name"] as? String ?? "",
                        msgType: msgObj["msg_type"] as? String ?? "text",
                        content: msgObj["content"] as? String ?? "",
                        createdAt: msgObj["created_at"] as? String ?? "ravnokar"
                    )
                    self.messages.append(msg)
                }
            case "members":
                if let arr = json["members"] as? [[String: Any]] {
                    self.members = arr.compactMap { m in
                        SquadMember(
                            id: m["id"] as? String ?? UUID().uuidString,
                            roomCode: m["room_code"] as? String ?? "",
                            name: m["name"] as? String ?? "",
                            lat: m["lat"] as? Double,
                            lon: m["lon"] as? Double,
                            drinksCount: m["drinks_count"] as? Int ?? 0,
                            lastSeen: m["last_seen"] as? String
                        )
                    }
                }
            case "member_update":
                if let m = json["member"] as? [String: Any],
                   let memberId = m["id"] as? String {
                    if let index = self.members.firstIndex(where: { $0.id == memberId }) {
                        var updated = self.members[index]
                        if let drinks = m["drinks_count"] as? Int { updated.drinksCount = drinks }
                        if let lat = m["lat"] as? Double { updated = SquadMember(id: updated.id, roomCode: updated.roomCode, name: updated.name, lat: lat, lon: m["lon"] as? Double ?? updated.lon, drinksCount: updated.drinksCount, lastSeen: "ravnokar") }
                        self.members[index] = updated
                    }
                }
            case "round_call":
                if let name = json["sender_name"] as? String {
                    self.bannerAlert = "🍻 \(name) časti naslednjo rundo!"
                }
            case "delete_message":
                if let idNum = json["id"] as? NSNumber {
                    self.messages.removeAll { $0.id == idNum.int64Value }
                }
            default:
                break
            }
        }
    }
    
    // MARK: - Pošiljanje podatkov
    func sendChatMessage(_ content: String, msgType: String = "text") {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let payload: [String: Any] = [
            "type": "chat",
            "content": trimmed,
            "msgType": msgType
        ]
        sendJson(payload)
    }
    
    func incrementDrink() {
        myDrinksCount += 1
        let payload: [String: Any] = ["type": "drink_inc"]
        sendJson(payload)
    }
    
    func updateLocation(lat: Double, lon: Double) {
        let payload: [String: Any] = [
            "type": "location",
            "lat": lat,
            "lon": lon
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
