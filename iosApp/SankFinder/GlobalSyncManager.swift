import Foundation
import UIKit
import UserNotifications

struct PushEvent: Identifiable {
    let id: String
    let title: String
    let message: String
}

class GlobalSyncManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = GlobalSyncManager()
    
    @Published var isConnected: Bool = false
    @Published var lastAnnouncement: String?
    @Published var activePushAlert: PushEvent?
    @Published var motd: String?
    @Published var latestVersion: String = "1.2.0"
    @Published var isOutdated: Bool = false
    @Published var versionNotes: String = ""
    
    func isVersionOlder(current: String, latest: String) -> Bool {
        let currParts = current.split(separator: ".").compactMap { Int($0.filter { $0.isNumber }) }
        let latestParts = latest.split(separator: ".").compactMap { Int($0.filter { $0.isNumber }) }
        let maxLen = max(currParts.count, latestParts.count)
        for i in 0..<maxLen {
            let c = i < currParts.count ? currParts[i] : 0
            let l = i < latestParts.count ? latestParts[i] : 0
            if c < l { return true }
            if c > l { return false }
        }
        return false
    }
    
    func checkVersionConfig() {
        for hostInfo in hosts {
            let scheme = hostInfo.useSsl ? "https" : "http"
            guard let url = URL(string: "\(scheme)://\(hostInfo.host)/api/app/config") else { continue }
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let self = self, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                
                let versions = json["versions"] as? [String: Any]
                let latest = versions?["ios"] as? String ?? versions?["latestIos"] as? String ?? "1.2.1"
                let notes = versions?["notes"] as? String ?? ""
                let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.1"
                let motdMsg = json["motd"] as? String
                
                DispatchQueue.main.async {
                    self.latestVersion = latest
                    self.versionNotes = notes
                    self.isOutdated = self.isVersionOlder(current: current, latest: latest)
                    if let m = motdMsg, !m.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.motd = m
                    }
                }
            }.resume()
        }
    }
    
    private var webSocketTask: URLSessionWebSocketTask?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        return URLSession(configuration: config)
    }()
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    
    private let userAgent = "SankFinderApp-Slovenia/1.0 (https://sankfinder.sluga.me; contact@sluga.me)"
    
    // Kandidata za povezavo: Javna domena in neposredni lokalni strežnik
    private let hosts = [
        (host: "sankfinder.sluga.me", useSsl: true),
        (host: "192.168.200.209:8080", useSsl: false)
    ]
    private var currentHostIndex = 0
    
    private var currentScreen: String = "Glavna stran"
    private var deviceId: String {
        if let id = SecureStorage.shared.getString(key: "sankfinder_device_id") {
            return id
        }
        // Samodejna migracija iz UserDefaults, če že obstaja
        if let oldId = UserDefaults.standard.string(forKey: "sankfinder_device_id") {
            SecureStorage.shared.saveString(key: "sankfinder_device_id", value: oldId)
            return oldId
        }
        let newId = "ios_" + UUID().uuidString.prefix(8).lowercased()
        SecureStorage.shared.saveString(key: "sankfinder_device_id", value: newId)
        return newId
    }
    
    private var deviceModelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }
        
        let map: [String: String] = [
            "iPhone14,2": "Apple iPhone 13 Pro",
            "iPhone14,3": "Apple iPhone 13 Pro Max",
            "iPhone14,4": "Apple iPhone 13 mini",
            "iPhone14,5": "Apple iPhone 13",
            "iPhone14,7": "Apple iPhone 14",
            "iPhone14,8": "Apple iPhone 14 Plus",
            "iPhone15,2": "Apple iPhone 14 Pro",
            "iPhone15,3": "Apple iPhone 14 Pro Max",
            "iPhone15,4": "Apple iPhone 15",
            "iPhone15,5": "Apple iPhone 15 Plus",
            "iPhone16,1": "Apple iPhone 15 Pro",
            "iPhone16,2": "Apple iPhone 15 Pro Max",
            "iPhone17,1": "Apple iPhone 16 Pro",
            "iPhone17,2": "Apple iPhone 16 Pro Max",
            "iPhone17,3": "Apple iPhone 16",
            "iPhone17,4": "Apple iPhone 16 Plus",
            "arm64": "Apple iPhone Simulator",
            "x86_64": "Apple iPhone Simulator"
        ]
        
        if let friendly = map[identifier] {
            return friendly
        }
        if identifier.hasPrefix("iPhone") {
            return "Apple iPhone (\(identifier))"
        } else if identifier.hasPrefix("iPad") {
            return "Apple iPad (\(identifier))"
        }
        return "Apple \(UIDevice.current.model)"
    }
    
    override init() {
        super.init()
    }
    
    func start() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Dovoljenje za obvestila na iOS: \(error.localizedDescription)")
            }
        }
        checkVersionConfig()
        connect()
    }
    
    // Obvestila se shranijo v Center za obvestila (.list) in prikažejo na zaklenjenem zaslonu,
    // VENDAR BREZ pojavnih pasic (.banner), da med uporabo aplikacije ne zakrivajo pogleda na zemljevid!
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            // Samo .list in .badge - brez .banner in brez zvoka, ki bi motil med hojo
            completionHandler([.list, .badge])
        } else {
            completionHandler([])
        }
    }
    
    func reportScreen(_ screen: String) {
        currentScreen = screen
        sendScreenChange(screen)
    }
    
    func reportTermsAccepted() {
        UserDefaults.standard.set(true, forKey: "hasAcceptedTerms")
        
        let obj: [String: Any] = [
            "type": "terms_accepted",
            "accepted": true,
            "deviceId": deviceId
        ]
        if let data = try? JSONSerialization.data(withJSONObject: obj),
           let str = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(str)) { _ in }
        }
        
        Task {
            for host in hosts {
                let scheme = host.useSsl ? "https" : "http"
                guard let url = URL(string: "\(scheme)://\(host.host)/api/app/terms/accept") else { continue }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                let body: [String: Any] = [
                    "deviceId": deviceId,
                    "clientType": "ios",
                    "accepted": true
                ]
                req.httpBody = try? JSONSerialization.data(withJSONObject: body)
                do {
                    let (_, resp) = try await URLSession.shared.data(for: req)
                    if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                        break
                    }
                } catch {}
            }
        }
    }
    
    private func connect() {
        disconnect()
        
        let model = deviceModelName
        let os = "iOS \(UIDevice.current.systemVersion)"
        
        let encModel = model.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "iPhone"
        let encOs = os.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "iOS"
        let encScreen = currentScreen.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Glavna"
        
        let hostInfo = hosts[currentHostIndex]
        let scheme = hostInfo.useSsl ? "wss" : "ws"
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let signature = SecureStorage.shared.generateSignature(timestamp: timestamp, deviceId: deviceId)
        let currentVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.1"
        let encVer = currentVer.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "1.2.1"
        let isTerms = UserDefaults.standard.bool(forKey: "hasAcceptedTerms") ? "1" : "0"
        let urlString = "\(scheme)://\(hostInfo.host)/ws?clientType=app&deviceId=\(deviceId)&model=\(encModel)&os=\(encOs)&screen=\(encScreen)&version=\(encVer)&terms=\(isTerms)&t=\(timestamp)&sig=\(signature)"
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("\(timestamp)", forHTTPHeaderField: "X-Sank-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-Sank-Signature")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
        request.timeoutInterval = 8.0
        
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        listenForMessages()
        startPingTimer()
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
                DispatchQueue.main.async {
                    self.isConnected = true
                }
                switch message {
                case .string(let text):
                    self.handleIncomingText(text)
                default:
                    break
                }
                self.listenForMessages()
            case .failure(let error):
                print("GlobalSync WS začasna prekinitev: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                // Preklopi na rezervni gostitelj, če glavni pade
                self.currentHostIndex = (self.currentHostIndex + 1) % self.hosts.count
                self.scheduleReconnect()
            }
        }
    }
    
    private func handleIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        let type = json["type"] as? String ?? ""
        DispatchQueue.main.async {
            if type == "global_push" || type == "push_notification" {
                let title = json["title"] as? String ?? "ŠankFinder Obvestilo"
                let msg = json["message"] as? String ?? ""
                let notifId = "\(json["id"] ?? UUID().uuidString)"
                
                self.lastAnnouncement = "\(title): \(msg)"
                self.activePushAlert = PushEvent(id: notifId, title: title, message: msg)
                
                // 1. Prikaži pravo sistemsko iOS obvestilo v notification centru
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = msg
                content.sound = .default
                let request = UNNotificationRequest(identifier: notifId, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request) { error in
                    if let err = error {
                        print("Napaka pri prikazu iOS obvestila: \(err.localizedDescription)")
                    }
                }
            } else if type == "motd" {
                self.motd = json["message"] as? String
            } else if type == "version_info" || type == "app_version_update" {
                let verObj = (json["versions"] as? [String: Any]) ?? json
                let latest = verObj["ios"] as? String ?? verObj["latestIos"] as? String ?? "1.2.1"
                let notes = verObj["notes"] as? String ?? ""
                let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.1"
                self.latestVersion = latest
                self.versionNotes = notes
                self.isOutdated = self.isVersionOlder(current: current, latest: latest)
            }
        }
    }
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if error != nil {
                self?.currentHostIndex = ((self?.currentHostIndex ?? 0) + 1) % (self?.hosts.count ?? 1)
                self?.scheduleReconnect()
            }
        }
        
        let currentVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
        let pingObj: [String: Any] = [
            "type": "ping",
            "deviceId": deviceId,
            "screen": currentScreen,
            "version": currentVer
        ]
        if let data = try? JSONSerialization.data(withJSONObject: pingObj),
           let str = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(str)) { _ in }
        }
    }
    
    private func sendScreenChange(_ screen: String) {
        let currentVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
        let obj: [String: Any] = [
            "type": "screen_change",
            "screen": screen,
            "version": currentVer
        ]
        if let data = try? JSONSerialization.data(withJSONObject: obj),
           let str = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(str)) { _ in }
        }
    }
    
    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }
}
