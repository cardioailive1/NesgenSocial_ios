import Foundation

/// Total unread messages, for the badge on the Messages tab.
///
/// A shared object rather than a value passed down: the tab bar lives in
/// `MainTabView`, and the number comes from the conversation list that
/// `MessagesViewModel` loads several screens away.
///
/// There is no count endpoint -- `GET /api/messages` carries `unreadCount`
/// per conversation, so the total is a sum over the list the Messages screen
/// already fetches. `MessagesViewModel` hands its list over rather than
/// making the same request twice.
@MainActor
final class UnreadBadge: ObservableObject {
    static let shared = UnreadBadge()

    @Published private(set) var count = 0

    private init() {}

    func update(from conversations: [Conversation]) {
        count = conversations.reduce(0) { $0 + ($1.unreadCount ?? 0) }
    }

    /// For callers with no list in hand -- the tab bar on foreground, and
    /// leaving a thread that was just read. Uncached on purpose: both cases
    /// are exactly when the cached list's counts are the stale ones.
    func refresh() async {
        guard let conversations = try? await MessagesService.conversations(maxAge: 0) else { return }
        update(from: conversations)
    }
}
