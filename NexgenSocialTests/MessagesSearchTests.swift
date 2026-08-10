import XCTest
@testable import NexgenSocial

/// The friend-search half of the Messages screen. Both properties are pure
/// reads over already-loaded state, so nothing here touches the network.
@MainActor
final class MessagesSearchTests: XCTestCase {

    private func makeModel() -> MessagesViewModel {
        let model = MessagesViewModel()
        model.conversations = [conversation(with: user("u1", "ada", "Ada Lovelace"))]
        model.friends = [
            user("u1", "ada", "Ada Lovelace"),
            user("u2", "grace", "Grace Hopper"),
            user("u3", "alan", "Alan Turing")
        ]
        return model
    }

    func testEmptyQueryShowsEveryConversationAndNoFriendSuggestions() {
        let model = makeModel()
        XCTAssertEqual(model.filteredConversations.count, 1)
        XCTAssertTrue(model.matchingFriends.isEmpty)
        XCTAssertFalse(model.isSearching)
    }

    /// Whitespace is not a search. Otherwise a stray space empties the list.
    func testWhitespaceOnlyQueryCountsAsNoQuery() {
        let model = makeModel()
        model.searchText = "   "
        XCTAssertFalse(model.isSearching)
        XCTAssertEqual(model.filteredConversations.count, 1)
    }

    func testSearchMatchesDisplayNameAndUsernameCaseInsensitively() {
        let model = makeModel()
        model.searchText = "GRACE"
        XCTAssertEqual(model.matchingFriends.map(\.username), ["grace"])

        model.searchText = "hopper"
        XCTAssertEqual(model.matchingFriends.map(\.username), ["grace"])
    }

    /// The whole point of `matchingFriends`: a friend already in the chat list
    /// must not also appear under "Start a new chat".
    func testFriendWithAnExistingConversationIsNotOfferedAsANewChat() {
        let model = makeModel()
        model.searchText = "a"

        XCTAssertEqual(model.filteredConversations.compactMap { $0.otherUser?.username }, ["ada"])
        XCTAssertEqual(model.matchingFriends.map(\.username).sorted(), ["alan", "grace"])
    }

    func testQueryMatchingNobodyReturnsBothListsEmpty() {
        let model = makeModel()
        model.searchText = "zzz"
        XCTAssertTrue(model.filteredConversations.isEmpty)
        XCTAssertTrue(model.matchingFriends.isEmpty)
    }

    // MARK: - Fixtures

    private func user(_ id: String, _ username: String, _ displayName: String) -> User {
        User(id: id, username: username, displayName: displayName)
    }

    private func conversation(with other: User) -> Conversation {
        Conversation(id: "c-\(other.id)", otherUser: other)
    }
}
