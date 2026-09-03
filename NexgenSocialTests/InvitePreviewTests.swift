import XCTest
@testable import NexgenSocial

/// Signup's invite code: parsing what someone pasted, and resolving it to the
/// person who sent it via the public `GET /api/social/invites/:token`.
@MainActor
final class InvitePreviewTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    func testParsesCodeFromLinkQueryBareCodeAndRejectsJunk() {
        XCTAssertEqual(AuthService.inviteToken(in: "https://nexgensocialnet.com/signup?ref=abc123"), "abc123")
        XCTAssertEqual(AuthService.inviteToken(in: "  abc123 "), "abc123")
        XCTAssertNil(AuthService.inviteToken(in: ""))
        XCTAssertNil(AuthService.inviteToken(in: "two words"))
    }

    /// The reset flow uses the same parser with a different query name.
    func testResetTokenStillReadsItsOwnQueryName() {
        XCTAssertEqual(AuthService.resetToken(in: "https://nexgensocialnet.com/reset-password?token=xyz"), "xyz")
    }

    func testEndpointPath() {
        XCTAssertEqual(APIEndpoints.SocialAccounts.invite("abc123"), "/api/social/invites/abc123")
    }

    /// The public route selects only username/displayName/avatarUrl -- no id,
    /// so the sender cannot decode as a `User`.
    func testInviteDecodesSenderWithoutAnId() async throws {
        StubAPI.install(json: """
        {"invite":{"id":"i1","token":"abc123","channel":"link","contact":null,
          "createdAt":"2026-09-01T10:00:00.000Z",
          "sender":{"username":"friend","displayName":"A Friend","avatarUrl":null}}}
        """)

        let invite = try await SocialAccountsService.invite(token: "abc123")
        XCTAssertEqual(invite.sender?.displayName, "A Friend")
    }
}
