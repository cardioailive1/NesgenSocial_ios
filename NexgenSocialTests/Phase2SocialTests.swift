import XCTest
@testable import NexgenSocial

/// Phase 2 of the parity backlog: the follower and following lists behind the
/// profile counts, the unread badge on the Messages tab, and deleting a
/// message.
@MainActor
final class Phase2SocialTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    // MARK: - Follower / following lists

    func testFollowersComeFromTheFollowersRoute() async throws {
        var path: String?
        StubAPI.install { request in
            path = request.url?.path
            return (200, Data(#"{"followers":[{"id":"u1","username":"ada","displayName":"Ada"}]}"#.utf8))
        }

        let people = try await DiscoveryService.followers(of: "grace")

        XCTAssertEqual(path, "/api/follows/grace/followers")
        XCTAssertEqual(people.map(\.username), ["ada"])
    }

    /// The two routes return different top-level keys, which is the one thing
    /// a shared screen could get wrong.
    func testFollowingComesFromTheFollowingRouteAndItsOwnKey() async throws {
        var path: String?
        StubAPI.install { request in
            path = request.url?.path
            return (200, Data(#"{"following":[{"id":"u2","username":"linus","displayName":"Linus"}]}"#.utf8))
        }

        let people = try await DiscoveryService.following(of: "grace")

        XCTAssertEqual(path, "/api/follows/grace/following")
        XCTAssertEqual(people.map(\.username), ["linus"])
    }

    // MARK: - Unread badge

    func testTheBadgeSumsUnreadCountsAndTreatsAMissingOneAsZero() {
        UnreadBadge.shared.update(from: [
            Conversation(id: "a", unreadCount: 3),
            Conversation(id: "b", unreadCount: nil),
            Conversation(id: "c", unreadCount: 4),
        ])

        XCTAssertEqual(UnreadBadge.shared.count, 7)
    }

    func testLoadingTheConversationListUpdatesTheBadge() async {
        UnreadBadge.shared.update(from: [])
        StubAPI.install(json: #"{"conversations":[{"id":"a","unreadCount":2},{"id":"b","unreadCount":5}]}"#)

        await MessagesViewModel().load()

        XCTAssertEqual(UnreadBadge.shared.count, 7)
    }

    /// The list route is cached for the Messages screen; the badge asks for a
    /// fresh copy, because it refreshes exactly when the cached counts are
    /// the stale ones.
    func testTheBadgeRefreshBypassesTheResponseCache() async {
        var requests = 0
        StubAPI.install { _ in
            requests += 1
            return (200, Data(#"{"conversations":[{"id":"a","unreadCount":1}]}"#.utf8))
        }

        await UnreadBadge.shared.refresh()
        await UnreadBadge.shared.refresh()

        XCTAssertEqual(requests, 2)
        XCTAssertEqual(UnreadBadge.shared.count, 1)
    }

    // MARK: - Delete a message

    func testDeletingAmessageHitsTheFlatMessageRoute() async throws {
        var path: String?
        var method: String?
        StubAPI.install { request in
            path = request.url?.path
            method = request.httpMethod
            return (204, Data())
        }

        try await MessagesService.delete(messageId: "m1")

        XCTAssertEqual(method, "DELETE")
        XCTAssertEqual(path, "/api/messages/messages/m1")
    }

    func testAfailedDeletePutsTheMessageBack() async {
        let mine = User(id: "me", username: "me", displayName: "Me")
        let model = ConversationViewModel(
            conversation: Conversation(id: "c1",
                                       otherUser: User(id: "them", username: "them", displayName: "Them")))
        StubAPI.install { request in
            request.httpMethod == "DELETE"
                ? (403, Data(#"{"error":"Not yours."}"#.utf8))
                : (200, Data(#"{"messages":[{"id":"m1","body":"hi"}]}"#.utf8))
        }
        await model.load()
        XCTAssertEqual(model.messages.count, 1)

        await model.delete(Message(id: "m1", body: "hi", sender: mine))

        XCTAssertEqual(model.messages.map(\.id), ["m1"])
        XCTAssertNotNil(model.errorMessage)
    }
}
