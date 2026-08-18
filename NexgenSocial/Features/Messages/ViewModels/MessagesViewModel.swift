import Foundation

enum MessagesTab: String, CaseIterable, Identifiable {
    case chats = "Chats"
    case calls = "Calls"

    var id: String { rawValue }
}

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

    /// Which half of the tab is on screen. Calls live here rather than on a
    /// screen of their own because they are the same list of people, reached
    /// the same way.
    @Published var tab: MessagesTab = .chats
    @Published var calls: [Call] = []

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

    /// Call history, newest first. Loaded with the rest of the screen rather
    /// than on tab switch: it's one small request, and switching tabs to a
    /// spinner reads as slower than it is.
    func loadCalls() async {
        do {
            calls = try await CallsService.history()
        } catch {
            errorMessage = errorMessage ?? error.localizedDescription
        }
    }

    /// Loaded once when the screen opens. The friend list is small and changes
    /// rarely, so searching it locally beats a request per keystroke.
    func loadFriends() async {
        do {
            friends = try await FriendsService.friends()
        } catch {
            // Doesn't clear an existing error: the conversation list failing
            // is the more useful message of the two.
            errorMessage = errorMessage ?? error.localizedDescription
        }
    }

    /// Opens the conversation a `/messages/{id}` deep link points at.
    ///
    /// It comes out of the list rather than a request of its own because the
    /// backend has no single-conversation route; the list is loaded first if
    /// the screen hasn't got there yet. An id that isn't in the list — an old
    /// notification for a deleted thread — leaves the user on the list.
    func open(conversationId: String) async {
        if conversations.isEmpty { await load() }
        if let match = conversations.first(where: { $0.id == conversationId }) {
            openedConversation = match
        }
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

    /// Calls matching the search field. Takes the viewer's id because which
    /// party a row is "about" depends on which side of the call they were on.
    func filteredCalls(forUserId userId: String?) -> [Call] {
        guard isSearching else { return calls }
        return calls.filter { $0.otherParty(forUserId: userId)?.matches(trimmedQuery) ?? false }
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
