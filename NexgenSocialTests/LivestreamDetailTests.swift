import XCTest
@testable import NexgenSocial

/// `GET /api/livestreams/:id`. The list only returns LIVE streams, so a
/// viewer's only way to learn the host ended is to ask for the one stream.
@MainActor
final class LivestreamDetailTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    func testEndpointPath() {
        XCTAssertEqual(APIEndpoints.Livestreams.detail("s1"), "/api/livestreams/s1")
    }

    func testDetailDecodesEndedStream() async throws {
        StubAPI.install(json: """
        {"stream":{"id":"s1","title":"Launch day","status":"ENDED",
          "startedAt":"2026-09-03T10:00:00.000Z",
          "host":{"id":"u1","username":"host","displayName":"Host","avatarUrl":null}}}
        """)

        let stream = try await LivestreamsService.detail("s1")
        XCTAssertEqual(stream.status, "ENDED")
        XCTAssertEqual(stream.host?.username, "host")
    }
}
