import XCTest
@testable import NexgenSocial

/// Submitting a political ad. The "paid for by" disclosure is a legal
/// requirement the server enforces, so the form must refuse to submit without
/// it rather than let the request 400.
@MainActor
final class PoliticalAdTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    func testEndpointPath() {
        XCTAssertEqual(APIEndpoints.Political.ads, "/api/political/ads")
    }

    func testPaidForByIsRequiredBeforeSubmitting() {
        let model = RunPoliticalAdViewModel()
        model.headline = "Vote Tuesday"
        model.body = "Polls open at 7am."
        XCTAssertFalse(model.canSave)

        model.paidForBy = "   "
        XCTAssertFalse(model.canSave, "whitespace is not a disclosure")

        model.paidForBy = "Some Committee"
        XCTAssertTrue(model.canSave)
    }

    func testCreatedAdDecodes() async throws {
        StubAPI.install(json: """
        {"ad":{"id":"a1","headline":"Vote Tuesday","body":"Polls open at 7am.",
          "paidForBy":"Some Committee","spendCents":25000,"region":"Texas",
          "active":true,"startedAt":"2026-09-03T10:00:00.000Z","endedAt":null,
          "impressions":0,"clicks":0}}
        """)

        let model = RunPoliticalAdViewModel()
        model.headline = "Vote Tuesday"
        model.body = "Polls open at 7am."
        model.paidForBy = "Some Committee"
        model.spend = "250"
        let saved = await model.save(pageId: "p1")
        XCTAssertTrue(saved)
        XCTAssertNil(model.errorMessage)
    }
}
