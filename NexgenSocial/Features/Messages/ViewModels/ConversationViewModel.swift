import Foundation

/// One open conversation: history, sending, and the polling refresh.
@MainActor
final class ConversationViewModel: ObservableObject {

    @Published private(set) var messages: [Message] = []
    @Published var draft = ""
    @Published var attachments: [PickedAttachment] = []
    @Published private(set) var isSending = false
    @Published var errorMessage: String?

    private let conversation: Conversation

    init(conversation: Conversation) {
        self.conversation = conversation
    }

    var title: String { conversation.otherUser?.displayName ?? "Chat" }
    var otherUser: User? { conversation.otherUser }
    var canSend: Bool { !draft.isEmpty || !attachments.isEmpty }

    func isMine(_ message: Message) -> Bool {
        message.sender?.id != conversation.otherUser?.id
    }

    func load() async {
        messages = (try? await MessagesService.messages(in: conversation.id)) ?? []
    }

    /// Polling keeps this simple and predictable. A socket would be
    /// lower-latency but adds reconnection handling for little gain at
    /// current scale.
    func pollForNewMessages() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            await load()
        }
    }

    func send() async {
        guard canSend, !isSending else { return }
        isSending = true
        defer { isSending = false }

        // Clear the composer first so it feels immediate, and restore it on
        // failure -- a dropped request must never eat what was typed.
        let text = draft
        let sent = attachments
        draft = ""
        attachments = []
        do {
            try await MessagesService.send(text, attachments: sent, to: conversation.id)
            await load()
        } catch {
            draft = text
            attachments = sent
            errorMessage = error.localizedDescription
        }
    }
}
