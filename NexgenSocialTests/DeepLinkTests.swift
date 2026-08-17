import XCTest
@testable import NexgenSocial

/// The only part of deep linking that can be checked without a device: which
/// tab a notification's `url` resolves to, and whether it names a
/// conversation.
final class DeepLinkTests: XCTestCase {

    func testFullURLsAndBarePathsParseTheSame() {
        XCTAssertEqual(DeepLink.parse("https://nexgensocial-udp.fly.dev/reels"), .reels)
        XCTAssertEqual(DeepLink.parse("/reels"), .reels)
        XCTAssertEqual(DeepLink.parse("reels"), .reels)
    }

    func testMessageLinkCarriesItsConversationId() {
        XCTAssertEqual(DeepLink.parse("/messages/abc123"), .messages(conversationId: "abc123"))
        XCTAssertEqual(DeepLink.parse("/conversations/abc123"), .messages(conversationId: "abc123"))
    }

    func testBareMessagesLinkOpensTheListOnly() {
        XCTAssertEqual(DeepLink.parse("/messages"), .messages(conversationId: nil))
    }

    func testEachDestinationLandsOnItsOwnTab() {
        XCTAssertEqual(DeepLink.parse("/feed")?.tab, 0)
        XCTAssertEqual(DeepLink.parse("/posts/xyz")?.tab, 0)
        XCTAssertEqual(DeepLink.parse("/reels")?.tab, 1)
        XCTAssertEqual(DeepLink.parse("/friends")?.tab, 2)
        XCTAssertEqual(DeepLink.parse("/groups")?.tab, 2)
        XCTAssertEqual(DeepLink.parse("/notifications")?.tab, 2)
        XCTAssertEqual(DeepLink.parse("/messages/abc")?.tab, 3)
        XCTAssertEqual(DeepLink.parse("/profile")?.tab, 4)
    }

    /// An unknown link must leave the user where they are rather than
    /// bouncing them to the Feed.
    func testUnknownLinksResolveToNothing() {
        XCTAssertNil(DeepLink.parse("/settings/billing"))
        XCTAssertNil(DeepLink.parse(""))
        XCTAssertNil(DeepLink.parse("/"))
    }
}
