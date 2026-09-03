import XCTest
@testable import NexgenSocial

/// The feed's ranking knobs. The server clamps to 0...1, so what matters here
/// is that the weights ride along with the feed and survive the round trip.
@MainActor
final class FeedWeightsTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    func testFeedResponseCarriesWeights() async throws {
        StubAPI.install(json: """
        {"posts":[],"feedWeights":{"recency":0.65,"engagement":0.25,"diversity":0.1}}
        """)

        let response = try await PostsService.feed()
        XCTAssertEqual(response.feedWeights, FeedWeights(recency: 0.65, engagement: 0.25, diversity: 0.1))
    }

    /// Older servers, and the group/profile feeds, omit the field entirely.
    func testFeedWithoutWeightsStillDecodes() async throws {
        StubAPI.install(json: #"{"posts":[]}"#)

        let response = try await PostsService.feed()
        XCTAssertNil(response.feedWeights)
    }

    func testSaveReturnsTheServersClampedWeights() async throws {
        StubAPI.install(json: """
        {"feedWeights":{"recency":1,"engagement":0,"diversity":0.5}}
        """)

        let saved = try await PostsService.setFeedWeights(
            FeedWeights(recency: 3, engagement: -1, diversity: 0.5))
        XCTAssertEqual(saved, FeedWeights(recency: 1, engagement: 0, diversity: 0.5))
    }

    func testEndpointPath() {
        XCTAssertEqual(APIEndpoints.Users.feedWeights, "/api/users/me/feed-weights")
    }
}
