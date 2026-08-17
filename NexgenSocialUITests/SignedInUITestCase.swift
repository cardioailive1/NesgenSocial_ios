import XCTest

/// Base class for every UI walk that needs a live session.
///
/// Credentials come from the environment, never from a file. Pass them with
/// the `TEST_RUNNER_` prefix, which xcodebuild strips before handing them to
/// the runner:
///
/// ```
/// TEST_RUNNER_NEXGEN_EMAIL=… TEST_RUNNER_NEXGEN_PASSWORD=… \
///   xcodebuild -project NexgenSocial.xcodeproj -scheme NexgenSocial \
///   -destination 'platform=iOS Simulator,name=iPhone 17' \
///   -only-testing:NexgenSocialUITests test
/// ```
///
/// With no credentials set every test skips rather than fails: these walk a
/// real backend, and CI should not go red because it has no account.
class SignedInUITestCase: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["NEXGEN_EMAIL"],
              let password = environment["NEXGEN_PASSWORD"] else {
            throw XCTSkip("Set TEST_RUNNER_NEXGEN_EMAIL and TEST_RUNNER_NEXGEN_PASSWORD to run this.")
        }

        app = XCUIApplication()
        app.launch()

        let emailField = app.textFields["Email or username"]
        if emailField.waitForExistence(timeout: 20) {
            type(email, into: emailField)
            type(password, into: app.secureTextFields["Password"])
            app.buttons["Sign in"].tap()
        }

        // The tab bar only exists once the session is live.
        let signedIn = app.tabBars.buttons["Discover"].waitForExistence(timeout: 30)
        if !signedIn { attach(app.screenshot(), named: "sign-in-stuck") }
        XCTAssertTrue(signedIn, "sign-in did not complete")

        // Only now, with the first screen up, does iOS offer to save the
        // password — so it has to be dismissed here rather than straight
        // after tapping Sign in.
        dismissSavePasswordPrompt()
    }

    // MARK: - Navigation

    /// Switches tabs and waits for that tab's navigation bar. The first tap
    /// can land while the password sheet is still going away, in which case it
    /// does nothing at all, so it is retried.
    ///
    /// Returns without asserting for tabs that have no navigation bar (Reels).
    @discardableResult
    func openTab(_ name: String, navigationBar: String? = nil) -> Bool {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "no \(name) tab")

        guard let navigationBar else {
            tab.tap()
            return true
        }

        let title = app.navigationBars[navigationBar]
        for _ in 0..<3 where !title.exists {
            tab.tap()
            _ = title.waitForExistence(timeout: 10)
        }
        XCTAssertTrue(title.exists, "never reached the \(name) tab")
        return true
    }

    /// Taps a row on the Discover hub. SwiftUI does not build `List` rows it
    /// has never scrolled to, so the row has to be scrolled into being rather
    /// than merely waited for.
    func openDiscoverRow(_ title: String) {
        openTab("Discover", navigationBar: "Discover")
        let row = app.staticTexts[title].firstMatch
        for _ in 0..<10 where !row.exists { app.swipeUp() }
        if !row.exists { attach(app.screenshot(), named: "discover-no-\(title)-row") }
        XCTAssertTrue(row.exists, "no \(title) row on Discover")
        row.tap()
    }

    // MARK: - Assertions

    /// Fails if the screen is showing the shared error UI. Every view that can
    /// report a failed load marks it with the `error-banner` identifier, so
    /// this catches "the list is empty because the request threw", which is
    /// otherwise indistinguishable from a genuinely empty account.
    func assertNoErrorBanner(on screen: String, file: StaticString = #filePath, line: UInt = #line) {
        let banner = app.descendants(matching: .any)["error-banner"].firstMatch
        if banner.exists {
            attach(app.screenshot(), named: "\(screen)-error")
            XCTFail("\(screen) reported an error: \(banner.label)", file: file, line: line)
        }
    }

    /// Whether an `@username` is on screen — the landmark for "a real user
    /// came back from the API".
    ///
    /// Scans the labels rather than running an `NSPredicate` query: XCTest
    /// rejects `label.length` as a key path, and a `BEGINSWITH` query over a
    /// screen with many elements times out in `getMatchingSnapshots` before it
    /// answers.
    func hasHandleOnScreen(within timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for text in app.staticTexts.allElementsBoundByIndex
            where text.label.hasPrefix("@") && text.label.count > 1 {
                return true
            }
            Thread.sleep(forTimeInterval: 1)
        } while Date() < deadline
        return false
    }

    /// Waits until one of `texts` is on screen. Used where either real content
    /// or a documented empty state is a pass, but a spinner that never ends is
    /// not.
    func waitForAny(of texts: [String], timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for text in texts where app.staticTexts[text].firstMatch.exists { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }

    // MARK: - Plumbing

    /// iOS offers to save the password in the keychain after a successful
    /// sign-in. The sheet belongs to SpringBoard, not to the app, so it sits
    /// over the first screen and swallows every tap until it is dealt with.
    func dismissSavePasswordPrompt() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<20 {
            for notNow in [springboard.buttons["Not Now"],
                           XCUIApplication().buttons["Not Now"]] where notNow.exists {
                notNow.tap()
                return
            }
            Thread.sleep(forTimeInterval: 1)
        }
    }

    /// Taps and waits for the field to actually take focus before typing.
    /// A `typeText` sent while the keyboard is still coming up is dropped
    /// with "neither element nor any descendant has keyboard focus", and the
    /// first tap does not always land, so it is retried.
    func type(_ text: String, into field: XCUIElement) {
        for _ in 0..<5 {
            if field.value(forKey: "hasKeyboardFocus") as? Bool == true { break }
            field.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        field.typeText(text)
    }

    func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
