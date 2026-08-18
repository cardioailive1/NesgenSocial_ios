import Foundation

struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    var otherUser: User?
    var lastMessage: Message?
    var lastMessageAt: String?
    var unreadCount: Int?
}

struct Message: Codable, Identifiable, Hashable {
    let id: String
    var body: String?
    var createdAt: String?
    var sender: User?
    var attachments: [MediaItem]?
}

struct Call: Codable, Identifiable {
    let id: String
    let callerId: String
    let calleeId: String
    let kind: String
    var status: String
    var caller: User?
    var callee: User?
    var startedAt: String?
    var answeredAt: String?
    var endedAt: String?
}

extension Call {
    /// A call record is symmetric -- both sides get the same row -- so every
    /// label on it depends on who is looking at it.
    func isOutgoing(forUserId userId: String?) -> Bool { callerId == userId }

    func otherParty(forUserId userId: String?) -> User? {
        isOutgoing(forUserId: userId) ? (callee ?? caller) : (caller ?? callee)
    }

    var isVideo: Bool { kind == "VIDEO" }

    /// A missed call is the one thing worth calling out, and only the callee
    /// missed it -- for the caller the same record is just unanswered.
    func wasMissed(forUserId userId: String?) -> Bool {
        !isOutgoing(forUserId: userId) && (status == "MISSED" || status == "DECLINED")
    }

    /// "Missed · Video", "Outgoing · 2:14", "Incoming · Voice".
    func summary(forUserId userId: String?) -> String {
        let medium = isVideo ? "Video" : "Voice"
        if wasMissed(forUserId: userId) { return "Missed · \(medium)" }
        let direction = isOutgoing(forUserId: userId) ? "Outgoing" : "Incoming"
        if let length = ServerDate.duration(from: answeredAt, to: endedAt) {
            return "\(direction) · \(length)"
        }
        return "\(direction) · \(medium)"
    }
}

struct ConversationsResponse: Codable { let conversations: [Conversation] }
struct ConversationResponse: Codable { let conversation: Conversation }
struct MessagesResponse: Codable { let messages: [Message] }
struct IncomingCallResponse: Codable { let call: Call? }
struct CallsResponse: Codable { let calls: [Call] }
struct CallResponse: Codable { let call: Call }
