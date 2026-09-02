import Foundation

/// Direct messaging: conversation list, message history, sending, and opening
/// a conversation with a specific person.
enum MessagesService {

    static func conversations() async throws -> [Conversation] {
        try await APIClient.shared
            .get(APIEndpoints.Messages.root, as: ConversationsResponse.self).conversations
    }

    /// Polled every 5 seconds while a conversation is open, so it is never
    /// served from the cache -- that is the one place stale content would be
    /// plainly wrong. The conversation *list* above is cached normally.
    static func messages(in conversationId: String) async throws -> [Message] {
        try await APIClient.shared
            .get(APIEndpoints.Messages.messages(in: conversationId),
                 as: MessagesResponse.self, maxAge: 0).messages
    }

    static func send(_ body: String,
                     attachments: [PickedAttachment],
                     to conversationId: String) async throws {
        _ = try await APIClient.shared.upload(
            APIEndpoints.Messages.messages(in: conversationId),
            fields: ["body": body],
            files: attachments.uploadFiles,
            as: EmptyResponse.self
        )
    }

    /// Opens the direct conversation with `username`, creating it if this is
    /// the first message between the two. The server is the one that decides
    /// whether a conversation already exists, so there's no "does it exist"
    /// round trip to make first.
    static func conversation(with username: String) async throws -> Conversation {
        try await APIClient.shared
            .post(APIEndpoints.Messages.withUser(username), as: ConversationResponse.self).conversation
    }
}
