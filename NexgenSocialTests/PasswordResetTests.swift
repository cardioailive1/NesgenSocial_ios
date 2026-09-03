import XCTest
@testable import NexgenSocial

/// The reset token arrives inside whatever the user copies out of the email
/// client — a full link, a link with tracking parameters, or occasionally the
/// token alone. Everything the parser accepts must be the token and nothing
/// else, because a wrong guess is sent to the server as if it were real.
final class PasswordResetTests: XCTestCase {

    func testTokenIsReadFromTheQueryParameter() {
        XCTAssertEqual(
            AuthService.resetToken(in: "https://nexgensocialnet.com/reset-password?token=abc123"),
            "abc123")
    }

    func testOtherQueryParametersAreIgnored() {
        XCTAssertEqual(
            AuthService.resetToken(in: "https://nexgensocialnet.com/reset-password?utm=email&token=abc123"),
            "abc123")
    }

    func testPathStyleLinkFallsBackToTheLastComponent() {
        XCTAssertEqual(
            AuthService.resetToken(in: "https://nexgensocialnet.com/reset-password/abc123"),
            "abc123")
    }

    func testSurroundingWhitespaceFromAPasteIsTrimmed() {
        XCTAssertEqual(AuthService.resetToken(in: "  abc123\n"), "abc123")
    }

    func testNothingUsableIsRejectedRatherThanGuessed() {
        XCTAssertNil(AuthService.resetToken(in: ""))
        XCTAssertNil(AuthService.resetToken(in: "   "))
        XCTAssertNil(AuthService.resetToken(in: "here is your link"))
        XCTAssertNil(AuthService.resetToken(in: "https://nexgensocialnet.com/"))
    }

    func testTokenIsEscapedIntoTheValidationPath() {
        XCTAssertEqual(APIEndpoints.Auth.resetPasswordToken("a b"),
                       "/api/auth/reset-password/a%20b")
    }
}
