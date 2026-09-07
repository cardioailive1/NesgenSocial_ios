import XCTest
@testable import NexgenSocial

/// Phase 4 of the parity backlog: deleting your own reel, and the profile
/// screen for somebody else — its counts, its relationship buttons, and the
/// two grids behind them.
@MainActor
final class Phase4ProfileTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    // MARK: - Reel delete

    func testDeletingAReelHitsTheReelRoute() async throws {
        let box = RequestBox()
        StubAPI.install { request in
            box.record(request)
            return (204, Data())
        }

        try await ReelsService.delete("r1")

        XCTAssertEqual(box.path, "/api/reels/r1")
        XCTAssertEqual(box.method, "DELETE")
    }

    /// The server 404s when you don't own the reel, and that must not read as
    /// a successful delete — the cell would vanish from a list it's still in.
    func testARefusedReelDeleteLeavesTheListAlone() async {
        StubAPI.install(json: #"{"reels":[{"id":"r1","videoUrl":"a.mp4"},{"id":"r2","videoUrl":"b.mp4"}]}"#)
        let model = ReelsViewModel()
        await model.load()
        XCTAssertEqual(model.reels.count, 2)

        StubAPI.install(json: #"{"error":"Reel not found."}"#, status: 404)
        await model.delete(Reel(id: "r1", videoUrl: "a.mp4"))

        XCTAssertEqual(model.reels.map(\.id), ["r1", "r2"])
        XCTAssertNotNil(model.errorMessage)
    }

    /// A reel shows in the pager and on its author's profile at once, so the
    /// removal travels by broadcast rather than by return value.
    func testTheDeleteBroadcastRemovesTheReelFromAnotherList() async {
        StubAPI.install(json: #"{"reels":[{"id":"r1","videoUrl":"a.mp4"},{"id":"r2","videoUrl":"b.mp4"}]}"#)
        let model = ReelsViewModel()
        await model.load()

        model.removeDeleted("r1")

        XCTAssertEqual(model.reels.map(\.id), ["r2"])
    }

    // MARK: - Profile

    /// `viewerContext` is on the response the profile already fetches, so the
    /// follow and connect buttons cost no extra request. The view model used
    /// to decode it and throw it away.
    func testTheProfileKeepsTheViewerContextItAlreadyFetches() async {
        StubAPI.install { request in
            if request.url?.path == "/api/users/ada" {
                return (200, Data(#"""
                {"user":{"id":"u1","username":"ada","displayName":"Ada"},
                 "stats":{"followerCount":466,"followingCount":561},
                 "viewerContext":{"isFollowing":true,"friendStatus":"PENDING"}}
                """#.utf8))
            }
            return (200, Data(#"{"posts":[],"reels":[]}"#.utf8))
        }

        let model = ProfileViewModel()
        await model.load(username: "ada")

        XCTAssertEqual(model.user?.displayName, "Ada")
        XCTAssertEqual(model.stats?.followerCount, 466)
        XCTAssertTrue(model.isFollowing)
        XCTAssertEqual(model.friendStatus, "PENDING")
        XCTAssertFalse(model.loadFailed)
    }

    /// A username that doesn't exist must say so, not draw an empty grid that
    /// reads as "this person has posted nothing".
    func testAMissingProfileIsFlaggedRatherThanShownEmpty() async {
        StubAPI.install(json: #"{"error":"That profile doesn't exist."}"#, status: 404)

        let model = ProfileViewModel()
        await model.load(username: "ghost")

        XCTAssertTrue(model.loadFailed)
        XCTAssertNotNil(model.errorMessage)
    }

    func testFollowingFlipsTheButtonAndTheFollowerCountAtOnce() async {
        StubAPI.install { request in
            if request.url?.path == "/api/users/ada" {
                return (200, Data(#"""
                {"user":{"id":"u1","username":"ada","displayName":"Ada"},
                 "stats":{"followerCount":10},
                 "viewerContext":{"isFollowing":false,"friendStatus":"NONE"}}
                """#.utf8))
            }
            return (200, Data(#"{"posts":[],"reels":[]}"#.utf8))
        }
        let model = ProfileViewModel()
        await model.load(username: "ada")

        StubAPI.install(json: "{}")
        await model.toggleFollow(username: "ada")

        XCTAssertTrue(model.isFollowing)
        XCTAssertEqual(model.stats?.followerCount, 11)
    }

    /// Optimistic, so a failed follow has to put both the button and the
    /// count back where they were.
    func testAFailedFollowRestoresTheButtonAndTheCount() async {
        StubAPI.install { request in
            if request.url?.path == "/api/users/ada" {
                return (200, Data(#"""
                {"user":{"id":"u1","username":"ada","displayName":"Ada"},
                 "stats":{"followerCount":10},
                 "viewerContext":{"isFollowing":false,"friendStatus":"NONE"}}
                """#.utf8))
            }
            return (200, Data(#"{"posts":[],"reels":[]}"#.utf8))
        }
        let model = ProfileViewModel()
        await model.load(username: "ada")

        StubAPI.install(json: #"{"error":"nope"}"#, status: 500)
        await model.toggleFollow(username: "ada")

        XCTAssertFalse(model.isFollowing)
        XCTAssertEqual(model.stats?.followerCount, 10)
    }

    func testSendingAFriendRequestMovesTheButtonToRequested() async {
        StubAPI.install(json: "{}")

        let model = ProfileViewModel()
        await model.sendFriendRequest(username: "ada")

        XCTAssertEqual(model.friendStatus, "PENDING")
    }

    func testTheReelsTabComesFromTheReelsByUserRoute() async throws {
        let box = RequestBox()
        StubAPI.install { request in
            box.record(request)
            return (200, Data(#"{"reels":[{"id":"r1","videoUrl":"a.mp4"}]}"#.utf8))
        }

        let reels = try await ReelsService.reels(by: "ada")

        XCTAssertEqual(box.path, "/api/reels/by/ada")
        XCTAssertEqual(reels.map(\.id), ["r1"])
    }

    /// The Message button opens — or creates — the direct conversation for
    /// the person whose profile is open.
    func testTheMessageButtonOpensTheConversationForThatUsername() async throws {
        let box = RequestBox()
        StubAPI.install { request in
            box.record(request)
            return (200, Data(#"{"conversation":{"id":"c1"}}"#.utf8))
        }

        let conversation = try await MessagesService.conversation(with: "ada")

        XCTAssertEqual(box.path, "/api/messages/with/ada")
        XCTAssertEqual(box.method, "POST")
        XCTAssertEqual(conversation.id, "c1")
    }

    /// Liking from a profile used to be a dead heart: `ProfileView` handed
    /// `PostCard` an empty closure.
    func testLikingFromAProfileFlipsThePostAndCallsTheServer() async {
        StubAPI.install { request in
            if request.url?.path == "/api/users/ada" {
                return (200, Data(#"{"user":{"id":"u1","username":"ada","displayName":"Ada"}}"#.utf8))
            }
            return (200, Data(#"{"posts":[{"id":"p1","body":"hi","likeCount":2}]}"#.utf8))
        }
        let model = ProfileViewModel()
        await model.load(username: "ada")

        StubAPI.install(json: "{}")
        await model.toggleLike(Post(id: "p1", body: "hi"))

        XCTAssertTrue(model.posts[0].isLiked)
        XCTAssertEqual(model.posts[0].likeCount, 3)
    }

    /// A refused like has to go back where it was, or the count lies.
    func testAFailedLikeFromAProfileIsPutBack() async {
        StubAPI.install { request in
            if request.url?.path == "/api/users/ada" {
                return (200, Data(#"{"user":{"id":"u1","username":"ada","displayName":"Ada"}}"#.utf8))
            }
            return (200, Data(#"{"posts":[{"id":"p1","body":"hi","likeCount":2}]}"#.utf8))
        }
        let model = ProfileViewModel()
        await model.load(username: "ada")

        StubAPI.install(json: #"{"error":"nope"}"#, status: 500)
        await model.toggleLike(Post(id: "p1", body: "hi"))

        XCTAssertFalse(model.posts[0].isLiked)
        XCTAssertEqual(model.posts[0].likeCount, 2)
    }

    // MARK: -

    private final class RequestBox: @unchecked Sendable {
        var path: String?
        var method: String?

        func record(_ request: URLRequest) {
            path = request.url?.path
            method = request.httpMethod
        }
    }
}
