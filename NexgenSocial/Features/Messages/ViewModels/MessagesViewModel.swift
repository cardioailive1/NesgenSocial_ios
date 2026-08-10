import Foundation

/// Drives the conversation list plus the "start a new chat" friend search.
///
/// Both live here rather than in separate models because they share one piece
/// of state: opening a conversation from search has to land in the same list
/// the screen is already showing.
@MainActor
final class MessagesViewModel: ObservableObject {

    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// What the user typed. Filters the conversation list in place, and is
    /// also what `matchingFriends` searches against.
    @Published var searchText = ""

    @Published var friends: [User] = []

    /// Set when a search result is tapped; the view pushes this conversation.
    @Published var openedConversation: Conversation?

    // MARK: - Loading

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await MessagesService.conversations()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Loaded once when the screen opens. The friend list is small and changes
    /// rarely, so searching it locally beats a request per keystroke.
    func loadFriends() async {
        friends = (try? await FriendsService.friends()) ?? []
    }

    // MARK: - Search

    var isSearching: Bool { !trimmedQuery.isEmpty }

    /// Existing conversations whose other participant matches the query.
    var filteredConversations: [Conversation] {
        guard isSearching else { return conversations }
        return conversations.filter { $0.otherUser?.matches(trimmedQuery) ?? false }
    }

    /// Friends the user has no open conversation with yet — the ones worth
    /// offering as a *new* chat. Friends already in the list above would
    /// otherwise appear twice under two different headings.
    var matchingFriends: [User] {
        guard isSearching else { return [] }
        let existing = Set(conversations.compactMap { $0.otherUser?.id })
        return friends.filter { !existing.contains($0.id) && $0.matches(trimmedQuery) }
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Actions

    /// Opens (creating if needed) the direct conversation with `user`.
    func startChat(with user: User) async {
        do {
            let conversation = try await MessagesService.conversation(with: user.username)
            searchText = ""
            openedConversation = conversation
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension User {
    /// Case-insensitive match on either name the user might search by.
    func matches(_ query: String) -> Bool {
        displayName.localizedCaseInsensitiveContains(query)
            || username.localizedCaseInsensitiveContains(query)
    }
}
