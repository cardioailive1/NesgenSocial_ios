import XCTest

/// Walks to the ad manager so its rows can be looked at. This exists because
/// `AdRow` was rewritten from scratch during the Ads split and its layout had
/// never been seen on a screen.
///
/// Sign-in, the save-password sheet and Discover navigation all live in
/// `SignedInUITestCase`.
final class AdManagerScreenshotTests: SignedInUITestCase {

    func testCaptureAdManager() throws {
        openDiscoverRow("Ads")

        XCTAssertTrue(app.navigationBars["Ads"].waitForExistence(timeout: 20),
                      "the ad manager never opened")
        // Give the campaign list a moment to come back from the API, so the
        // screenshot shows rows rather than a spinner.
        Thread.sleep(forTimeInterval: 5)

        attach(app.screenshot(), named: "ad-manager")
    }
}
