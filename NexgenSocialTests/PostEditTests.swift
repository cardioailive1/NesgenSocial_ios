import XCTest
@testable import NexgenSocial

/// Editing has to be a PATCH to the post itself, and the screen has to adopt
/// the post the server returns — the `editedAt` stamp in that response is what
/// reveals the "edited" marker and the history button.
@MainActor
final class PostEditTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    private func post(id: String = "p1", body: String = "first draft") -> Post {
        Post(id: id, body: body)
    }

    func testSavingSendsAPatchToThePost() async {
        let box = RequestBox()
        StubAPI.install { request in
            box.calls.append((request.httpMethod ?? "", request.url?.path ?? ""))
            return (200, Data(#"{"post":{"id":"p1","body":"second draft","editedAt":"2026-09-03T10:00:00.000Z"}}"#.utf8))
        }

        let model = PostDetailViewModel(post: post())
        model.editDraft = "second draft"
        let saved = await model.saveEdit()

        XCTAssertTrue(saved)
        XCTAssertTrue(box.calls.contains { $0 == ("PATCH", "/api/posts/p1") },
                      "expected a PATCH to /api/posts/p1; sent \(box.calls)")
        XCTAssertEqual(model.post.body, "second draft")
        XCTAssertNotNil(model.post.editedAt, "the edited marker depends on this")
    }

    /// The server rejects an empty body, and re-saving the same text would add
    /// a pointless revision — neither should reach the network.
    func testUnchangedOrEmptyTextIsNotSent() async {
        let box = RequestBox()
        StubAPI.install { request in
            box.calls.append((request.httpMethod ?? "", request.url?.path ?? ""))
            return (200, Data(#"{"post":{"id":"p1","body":"x"}}"#.utf8))
        }

        let model = PostDetailViewModel(post: post())
        model.editDraft = "  first draft  "
        var saved = await model.saveEdit()
        XCTAssertFalse(saved)

        model.editDraft = "   "
        saved = await model.saveEdit()
        XCTAssertFalse(saved)

        XCTAssertTrue(box.calls.isEmpty, "nothing should have been sent; sent \(box.calls)")
    }

    func testAFailedEditKeepsTheOriginalBodyOnScreen() async {
        StubAPI.install(json: #"{"error":"A post can't be edited to be empty."}"#, status: 400)

        let model = PostDetailViewModel(post: post())
        model.editDraft = "second draft"
        let saved = await model.saveEdit()

        XCTAssertFalse(saved)
        XCTAssertEqual(model.post.body, "first draft")
        XCTAssertNotNil(model.errorMessage)
    }

    func testHistoryIsReadOldestFirstFromTheHistoryPath() async {
        let box = RequestBox()
        StubAPI.install { request in
            box.calls.append((request.httpMethod ?? "", request.url?.path ?? ""))
            return (200, Data(#"{"revisions":[{"id":"r1","body":"first draft","editedAt":"2026-09-03T10:00:00.000Z"}]}"#.utf8))
        }

        let model = PostDetailViewModel(post: post())
        await model.loadHistory()

        XCTAssertEqual(box.calls.map(\.1), ["/api/posts/p1/history"])
        XCTAssertEqual(model.revisions?.map(\.body), ["first draft"])
    }

    /// A successful edit adds a version, so any history already fetched is out
    /// of date and must be re-read rather than shown again.
    func testAnEditDiscardsPreviouslyLoadedHistory() async {
        StubAPI.install { request in
            request.url?.path.hasSuffix("/history") == true
                ? (200, Data(#"{"revisions":[]}"#.utf8))
                : (200, Data(#"{"post":{"id":"p1","body":"second draft"}}"#.utf8))
        }

        let model = PostDetailViewModel(post: post())
        await model.loadHistory()
        XCTAssertNotNil(model.revisions)

        model.editDraft = "second draft"
        _ = await model.saveEdit()
        XCTAssertNil(model.revisions)
    }

}

fileprivate final class RequestBox: @unchecked Sendable {
    var calls: [(String, String)] = []
}

/// Deleting is a DELETE to the post itself, and the lists that show the post
/// learn about it from the `.postDeleted` broadcast rather than a reload.
@MainActor
final class PostDeleteTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    func testDeletingSendsADeleteAndAnnouncesThePostId() async {
        let box = RequestBox()
        StubAPI.install { request in
            box.calls.append((request.httpMethod ?? "", request.url?.path ?? ""))
            return (200, Data("{}".utf8))
        }

        var announced: String?
        let observer = NotificationCenter.default.addObserver(
            forName: .postDeleted, object: nil, queue: .main) { announced = $0.object as? String }
        defer { NotificationCenter.default.removeObserver(observer) }

        let model = PostDetailViewModel(post: Post(id: "p1", body: "goodbye"))
        let deleted = await model.deletePost()

        XCTAssertTrue(deleted)
        XCTAssertTrue(box.calls.contains { $0 == ("DELETE", "/api/posts/p1") },
                      "expected a DELETE to /api/posts/p1; sent \(box.calls)")
        XCTAssertEqual(announced, "p1", "the lists filter on this id")
    }

    /// A refused delete must not dismiss the screen or hide the post anywhere.
    func testAFailedDeleteReportsTheErrorAndAnnouncesNothing() async {
        StubAPI.install(json: #"{"error":"Not your post."}"#, status: 403)

        var announced = false
        let observer = NotificationCenter.default.addObserver(
            forName: .postDeleted, object: nil, queue: .main) { _ in announced = true }
        defer { NotificationCenter.default.removeObserver(observer) }

        let model = PostDetailViewModel(post: Post(id: "p1", body: "still here"))
        let deleted = await model.deletePost()

        XCTAssertFalse(deleted)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(announced)
    }
}
