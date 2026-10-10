import Foundation
import UIKit

class GlobalSyncManager: ObservableObject {
    static let shared = GlobalSyncManager()
    
    @Published var isConnected: Bool = false
    @Published var lastAnnouncement: String?
    @Published var motd: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession = URLSession(configuration: .default)
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    
    private var currentScreen: String = "Zemljevid & Šanki"
    private var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: "sankfinder_device_id") {
            return id
        }
        let newId = "ios_" + UUID().uuidString.prefix(8).lowercased()
        UserDefaults.standard.set(newId, forKey: "sankfinder_device_id")
        return newId
    }
    
    init() {}
    
    func start() {
        connect()
    }
    
    func reportScreen(_ screen: String) {
        currentScreen = screen
        sendScreenChange(screen)
    }
    
    private func connect() {
        disconnect()
        
        let model = UIDevice.current.model
        let os = "iOS \(UIDevice.current.systemVersion)"
        
        let encModel = model.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "iPhone"
        let encOs = os.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "iOS"
        let encScreen = currentScreen.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Main"
        
        let urlString = "wss://sankfinder.sluga.me/ws?clientType=app&deviceId=\(deviceId)&model=\(encModel)&os=\(encOs)&screen=\(encScreen)&version=1.2"
        guard let url = URL(string: urlString) else { return }
        
        let request = URLRequest(url: url)
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        listenForMessages()
        startPingTimer()
        
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }
    
    private func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleIncomingText(text)
                default:
                    break
                }
                self.listenForMessages() // Poslušaj naprej
            case .failure(let error):
                print("Global WS prekinjen: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                self.scheduleReconnect()
            }
        }
    }
    
    private func handleIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        let type = json["type"] as? String ?? ""
        DispatchQueue.main.async {
            if type == "push_notification" {
                let title = json["title"] as? String ?? "Obvestilo"
                let msg = json["message"] as? String ?? ""
                self.lastAnnouncement = "\(title): \(msg)"
            } else if type == "motd" {
                self.motd = json["message"] as? String
            }
        }
    }
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        let pingObj = ["type": "ping"]
        if let data = try? JSONSerialization.data(withJSONObject: pingObj),
           let str = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(str)) { _ in }
        }
    }
    
    private func sendScreenChange(_ screen: String) {
        let obj: [String: Any] = ["type": "screen_change", "screen": screen]
        if let data = try? JSONSerialization.data(withJSONObject: obj),
           let str = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(str)) { _ in }
        }
    }
    
    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }
}
