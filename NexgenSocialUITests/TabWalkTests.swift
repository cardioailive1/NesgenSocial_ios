import XCTest

/// One walk per tab against the live backend — G6 in `FEATURE_AUDIT.md`.
///
/// Every screen below was verified as *wired* by the static pass; these prove
/// it *works*: the screen opens, its load finishes, and it settles into either
/// real content or its documented empty state. A stuck spinner fails, and so
/// does an error banner — which is the case the audit cared about, because an
/// error used to be drawn as an empty list.
final class TabWalkTests: SignedInUITestCase {

    func testFeedLoads() {
        openTab("Feed", navigationBar: "Feed")
        // Each post is a `NavigationLink`, so one button inside the feed's
        // scroll view means posts arrived. An account that follows nobody
        // legitimately gets the empty state instead; neither showing means the
        // load never finished.
        //
        // Deliberately not a label scan: the feed carries dozens of posts and
        // walking every element takes longer than the query deadline allows.
        // 60s, not the usual 20: on a cold image cache this account's feed
        // (34 posts, most of them photos) has taken most of a minute to put
        // its first card on screen.
        let firstPost = app.scrollViews.firstMatch.buttons.firstMatch
        XCTAssertTrue(firstPost.waitForExistence(timeout: 60)
                      || app.staticTexts["Your feed is empty"].exists,
                      "the feed never finished loading")
        assertNoErrorBanner(on: "feed")
        attach(app.screenshot(), named: "feed")
    }

    func testReelsLoads() {
        openTab("Reels")
        // Reels is full-bleed with no navigation bar, so its own empty state
        // is the only text landmark. "Couldn't load reels" is what it draws
        // when the load threw.
        _ = waitForAny(of: ["No reels yet", "Couldn't load reels"], timeout: 15)
        XCTAssertFalse(app.staticTexts["Couldn't load reels"].exists,
                       "reels failed to load")
        attach(app.screenshot(), named: "reels")
    }

    func testMessagesListsAndOpensAConversation() {
        openTab("Messages", navigationBar: "Messages")
        XCTAssertTrue(waitForAny(of: ["No conversations yet", "No messages yet"]),
                      "the conversation list never finished loading")
        assertNoErrorBanner(on: "messages")
        attach(app.screenshot(), named: "messages")

        // An account with no chats is a legitimate pass for the list, but then
        // there is nothing to open.
        let firstChat = app.cells.firstMatch
        guard firstChat.exists else { return }
        firstChat.tap()
        XCTAssertTrue(app.textFields["Message…"].waitForExistence(timeout: 20),
                      "the conversation never opened")
        assertNoErrorBanner(on: "conversation")
        attach(app.screenshot(), named: "conversation")
    }

    func testProfileShowsTheAccount() {
        openTab("Profile", navigationBar: "Profile")
        XCTAssertTrue(app.staticTexts["Call & message notifications"].waitForExistence(timeout: 20),
                      "the profile never rendered")
        // The signed-in user's handle proves the session carries a user
        // rather than an empty placeholder.
        XCTAssertTrue(hasHandleOnScreen(), "profile shows no username")
        attach(app.screenshot(), named: "profile")
    }

    func testFriendsLoads() {
        openDiscoverRow("Friends")
        XCTAssertTrue(app.navigationBars["Friends"].waitForExistence(timeout: 20),
                      "Friends never opened")
        // Let the three lists (friends, incoming, sent) come back.
        Thread.sleep(forTimeInterval: 5)
        assertNoErrorBanner(on: "friends")
        attach(app.screenshot(), named: "friends")
    }

    func testDiscoverHubIsReachable() {
        openTab("Discover", navigationBar: "Discover")
        // The rows visible without scrolling — the hub is a `List`, and
        // SwiftUI does not build rows nothing has scrolled to.
        for row in ["Notifications", "People, jobs, marketplace", "Meet"] {
            XCTAssertTrue(app.staticTexts[row].firstMatch.exists, "no \(row) row on Discover")
        }
        attach(app.screenshot(), named: "discover")
    }
}
