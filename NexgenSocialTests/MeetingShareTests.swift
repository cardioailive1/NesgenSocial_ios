import XCTest
@testable import NexgenSocial

final class MeetingShareTests: XCTestCase {

    private func meeting(code: String? = "ABC-DEF-GHJ") -> Meeting {
        Meeting(id: "m1", title: "Standup", code: code)
    }

    func testShareLinkPointsAtTheWebMeetingRoute() {
        XCTAssertEqual(meeting().shareURL?.absoluteString,
                       "\(APIClient.webBaseURL)/meet/m1")
    }

    func testShareTextCarriesBothTheCodeAndTheLink() {
        let text = meeting().shareText
        XCTAssertTrue(text.contains("ABC-DEF-GHJ"), text)
        XCTAssertTrue(text.contains("/meet/m1"), text)
        XCTAssertTrue(text.contains("Standup"), text)
    }

    func testShareTextSurvivesAMeetingWithNoCodeYet() {
        let text = meeting(code: nil).shareText
        XCTAssertTrue(text.contains("/meet/m1"), text)
    }

    @MainActor
    func testOpeningAMeetingClearsAnyMinimisedState() {
        let session = MeetSession.shared
        session.isMinimized = true
        session.open(meeting())
        XCTAssertFalse(session.isMinimized)
        XCTAssertEqual(session.activeMeeting?.id, "m1")

        session.close()
        XCTAssertNil(session.activeMeeting)
    }
}
