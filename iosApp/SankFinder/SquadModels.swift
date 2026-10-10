import Foundation

struct SquadRoom: Identifiable, Codable {
    let id: String
    let code: String
    let name: String
}

struct SquadMember: Identifiable, Codable {
    let id: String
    let roomCode: String
    let name: String
    let lat: Double?
    let lon: Double?
    var drinksCount: Int
    let lastSeen: String?
}

struct SquadMessage: Identifiable, Codable {
    let id: Int64
    let roomCode: String
    let senderId: String
    let senderName: String
    let msgType: String
    let content: String
    let createdAt: String
}
