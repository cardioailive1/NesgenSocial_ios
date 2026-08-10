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
}

struct ConversationsResponse: Codable { let conversations: [Conversation] }
struct ConversationResponse: Codable { let conversation: Conversation }
struct MessagesResponse: Codable { let messages: [Message] }
struct IncomingCallResponse: Codable { let call: Call? }
struct CallResponse: Codable { let call: Call }
