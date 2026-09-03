import XCTest
@testable import NexgenSocial

/// `GET /api/suggestions/profile-status` — the payload behind the feed's
/// "finish setting up your profile" banner.
@MainActor
final class ProfileStatusTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    func testEndpointPath() {
        XCTAssertEqual(APIEndpoints.Friends.profileStatus, "/api/suggestions/profile-status")
    }

    func testIncompleteProfileDecodesItsGaps() async throws {
        StubAPI.install(json: """
        {"completeness":40,"isComplete":false,
         "missing":[{"key":"avatarUrl","label":"Add a profile photo","action":"/profile-setup",
                     "hint":"People skip profiles with no photo."},
                    {"key":"interests","label":"Pick a few interests","action":"/profile-setup",
                     "hint":"Used to suggest people and content."},
                    {"key":"firstPost","label":"Write your first post","action":"/","hint":null}]}
        """)

        let status = try await FriendsService.profileStatus()
        XCTAssertEqual(status.completeness, 40)
        XCTAssertFalse(status.isComplete)
        XCTAssertEqual(status.missing.map(\.key), ["avatarUrl", "interests", "firstPost"])
        XCTAssertNil(status.missing.last?.hint)
    }

    /// A finished profile still returns rows for the optional items, so the
    /// banner has to hide on `isComplete`, not on an empty list.
    func testCompleteProfileDecodes() async throws {
        StubAPI.install(json: """
        {"completeness":100,"isComplete":true,
         "missing":[{"key":"connections","label":"Follow a few people","action":"/people","hint":null}]}
        """)

        let status = try await FriendsService.profileStatus()
        XCTAssertTrue(status.isComplete)
    }
}
