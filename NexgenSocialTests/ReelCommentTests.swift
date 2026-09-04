import XCTest
@testable import NexgenSocial

/// Reel comments live in their own table server-side but come back in the
/// post-comment shape, and the count under the bubble has to move when one is
/// posted — it was decoded and never shown before this existed.
@MainActor
final class ReelCommentTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    func testCommentsAreFetchedFromTheReelsCommentRoute() async throws {
        var path: String?
        StubAPI.install { request in
            path = request.url?.path
            return (200, Data(#"{"comments":[{"id":"c1","body":"first"}]}"#.utf8))
        }

        let comments = try await ReelsService.comments(for: "r1")

        XCTAssertEqual(path, "/api/reels/r1/comments")
        XCTAssertEqual(comments.map(\.body), ["first"])
    }

    func testPostingAcommentReturnsTheServersCopy() async throws {
        var method: String?
        StubAPI.install { request in
            method = request.httpMethod
            return (201, Data(#"{"comment":{"id":"c2","body":"nice one"}}"#.utf8))
        }

        let comment = try await ReelsService.addComment("nice one", to: "r1")

        XCTAssertEqual(method, "POST")
        XCTAssertEqual(comment.id, "c2")
        XCTAssertEqual(comment.body, "nice one")
    }

    func testANewCommentBumpsTheCountOnThatReelOnly() {
        let model = ReelsViewModel()
        model.reels = [Reel(id: "r1", videoUrl: "a.mp4", commentCount: 2),
                       Reel(id: "r2", videoUrl: "b.mp4", commentCount: 9)]

        model.countNewComment(on: model.reels[0])

        XCTAssertEqual(model.reels[0].commentCount, 3)
        XCTAssertEqual(model.reels[1].commentCount, 9)
    }
}
