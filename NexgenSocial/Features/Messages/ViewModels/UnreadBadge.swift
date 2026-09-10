import Foundation

/// Total unread messages, for the badge on the Messages tab.
///
/// A shared object rather than a value passed down: the tab bar lives in
/// `MainTabView`, and the number comes from the conversation list that
/// `MessagesViewModel` loads several screens away.
///
/// Two ways in. `update(from:)` sums the `unreadCount` each conversation
/// already carries, so the Messages screen updates the badge from the list it
/// just loaded rather than making a second request. `refresh()` asks
/// `GET /api/messages/unread-count` for the server's own total, for callers
/// with no list in hand.
@MainActor
final class UnreadBadge: ObservableObject {
    static let shared = UnreadBadge()

    @Published private(set) var count = 0

    private init() {}

    func update(from conversations: [Conversation]) {
        count = conversations.reduce(0) { $0 + ($1.unreadCount ?? 0) }
    }

    /// For callers with no list in hand -- the tab bar on foreground, and
    /// leaving a thread that was just read. One small request instead of the
    /// whole conversation list.
    func refresh() async {
        guard let total = try? await MessagesService.unreadCount() else { return }
        count = total
    }
}
