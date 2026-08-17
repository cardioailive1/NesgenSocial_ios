import XCTest
@testable import NexgenSocial

/// View models driven against a stubbed network — G7 in `FEATURE_AUDIT.md`.
///
/// These assert the behaviour the error-handling sweep (G3/G4) introduced:
/// a failed load must set `errorMessage` rather than leave an empty list
/// looking like an empty account. That was the bug class the audit found, and
/// until now nothing could catch it regressing.
@MainActor
final class ViewModelNetworkTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    // MARK: - Loading

    func testConversationListLoadsFromTheServer() async {
        StubAPI.install(json: """
        {"conversations":[
          {"id":"c1","otherUser":{"id":"u1","username":"ada","displayName":"Ada Lovelace"},
           "lastMessage":{"id":"m1","body":"hello"}},
          {"id":"c2","otherUser":{"id":"u2","username":"grace","displayName":"Grace Hopper"}}
        ]}
        """)

        let model = MessagesViewModel()
        await model.load()

        XCTAssertEqual(model.conversations.map(\.id), ["c1", "c2"])
        XCTAssertEqual(model.conversations.first?.otherUser?.displayName, "Ada Lovelace")
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    func testAServerErrorSurfacesItsOwnMessage() async {
        StubAPI.install(json: #"{"error":"Conversations are down for maintenance."}"#, status: 500)

        let model = MessagesViewModel()
        await model.load()

        XCTAssertTrue(model.conversations.isEmpty)
        XCTAssertEqual(model.errorMessage, "Conversations are down for maintenance.")
    }

    func testAnExpiredSessionIsReportedAsSuch() async {
        StubAPI.install(json: "{}", status: 401)

        let model = MessagesViewModel()
        await model.load()

        XCTAssertEqual(model.errorMessage, APIError.unauthorized.errorDescription)
    }

    func testUndecodableResponseDoesNotPassAsAnEmptyList() async {
        StubAPI.install(json: #"{"unexpected":true}"#)

        let model = MessagesViewModel()
        await model.load()

        XCTAssertTrue(model.conversations.isEmpty)
        XCTAssertNotNil(model.errorMessage, "a shape the app can't read must not look like no conversations")
    }

    /// The reason the whole sweep happened: a failed load used to be drawn as
    /// an empty screen.
    func testFriendsLoadFailureSetsAnError() async {
        StubAPI.install(json: #"{"error":"nope"}"#, status: 500)

        let model = FriendsViewModel()
        await model.load()

        XCTAssertTrue(model.friends.isEmpty)
        XCTAssertEqual(model.errorMessage, "nope")
    }

    /// Suggestions are deliberately best-effort: they must not manufacture an
    /// error of their own when the main load worked.
    func testFriendsSuggestionsFailingQuietlyLeavesNoError() async {
        StubAPI.install { request in
            let path = request.url?.path ?? ""
            if path == "/api/suggestions/friends" { return (500, Data(#"{"error":"nope"}"#.utf8)) }
            return (200, Data(#"{"incomingRequests":[],"sentRequests":[],"friends":[]}"#.utf8))
        }

        let model = FriendsViewModel()
        await model.load()

        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.suggestions.isEmpty)
    }
}
