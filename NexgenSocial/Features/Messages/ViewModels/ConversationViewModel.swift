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

    /// Which side of the thread a message is drawn on.
    ///
    /// A message with no `sender` used to come out as *mine* — `nil != otherId`
    /// is true — which drew someone else's message in the viewer's own bubble.
    /// Unknown now falls on the safer side.
    ///
    /// ponytail: infers ownership from "not the other participant", which is
    /// only right for a 1:1 thread. The API marks group conversations with
    /// `isGroup`, which the app neither decodes nor offers a way to create;
    /// compare against the signed-in user's id if group chats ever ship.
    func isMine(_ message: Message) -> Bool {
        guard let senderId = message.sender?.id else { return false }
        return senderId != conversation.otherUser?.id
    }

    func load() async {
        do {
            let fetched = try await MessagesService.messages(in: conversation.id)
            // Reassigning an identical array re-diffs the whole thread, which
            // is a visible hitch every 5 seconds while someone is reading a
            // long conversation. Most polls return exactly what is already
            // on screen.
            if fetched.map(\.id) != messages.map(\.id) { messages = fetched }
            errorMessage = nil
        } catch {
            // Keeps whatever is already on screen: a dropped poll shouldn't
            // blank the history. The next poll clears the message.
            errorMessage = error.localizedDescription
        }
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
