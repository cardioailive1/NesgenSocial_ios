import XCTest
@testable import NexgenSocial

/// The tag filter is a query parameter, and the server treats a missing
/// parameter as "the ranked For You feed" — so an empty tag must not send an
/// empty `?hashtag=`, which would filter on the empty string instead.
@MainActor
final class ReelHashtagTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    func testEmptyTagAsksForTheUnfilteredFeed() {
        XCTAssertEqual(APIEndpoints.Reels.discover(hashtag: ""), "/api/reels/discover")
    }

    func testTagIsSentAsAnEscapedQueryParameter() {
        XCTAssertEqual(APIEndpoints.Reels.discover(hashtag: "trail run"),
                       "/api/reels/discover?hashtag=trail%20run")
    }

    func testSelectingATagReloadsTheFeedThroughThatTag() async {
        let box = PathBox()
        StubAPI.install { request in
            box.paths.append(request.url?.path ?? "")
            box.queries.append(request.url?.query ?? "")
            if request.url?.path.hasSuffix("/hashtags/trending") == true {
                return (200, Data(#"{"trending":[{"tag":"trail","reelCount":4}]}"#.utf8))
            }
            return (200, Data(#"{"reels":[]}"#.utf8))
        }

        let model = ReelsViewModel()
        await model.load()
        XCTAssertEqual(model.trending.map(\.tag), ["trail"])
        XCTAssertTrue(model.activeTag.isEmpty)

        await model.select(tag: "trail")
        XCTAssertEqual(model.activeTag, "trail")
        XCTAssertTrue(box.queries.contains("hashtag=trail"),
                      "the reload should carry the tag; sent \(box.queries)")
    }

    func testSelectingTheTagAlreadyActiveDoesNotRefetch() async {
        let box = PathBox()
        StubAPI.install { request in
            box.paths.append(request.url?.path ?? "")
            if request.url?.path.hasSuffix("/hashtags/trending") == true {
                return (200, Data(#"{"trending":[]}"#.utf8))
            }
            return (200, Data(#"{"reels":[]}"#.utf8))
        }

        let model = ReelsViewModel()
        await model.load()
        let before = box.paths.count
        await model.select(tag: "")
        XCTAssertEqual(box.paths.count, before, "re-picking For you should be a no-op")
    }

    private final class PathBox: @unchecked Sendable {
        var paths: [String] = []
        var queries: [String] = []
    }
}
