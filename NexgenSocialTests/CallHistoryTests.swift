import XCTest
@testable import NexgenSocial

/// The call-history row labels. Every one of them depends on which side of the
/// call the viewer was on, which is the part worth pinning: the same record
/// reads "Outgoing" to one person and "Missed" to the other.
final class CallHistoryTests: XCTestCase {

    private let me = "me"
    private let them = "them"

    func testDirectionFollowsTheViewer() {
        let call = makeCall(callerId: me, calleeId: them)
        XCTAssertTrue(call.isOutgoing(forUserId: me))
        XCTAssertFalse(call.isOutgoing(forUserId: them))
    }

    func testOtherPartyIsNeverTheViewer() {
        let call = makeCall(callerId: me, calleeId: them)
        XCTAssertEqual(call.otherParty(forUserId: me)?.id, them)
        XCTAssertEqual(call.otherParty(forUserId: them)?.id, me)
    }

    /// Only the person who didn't pick up missed the call; the caller sees an
    /// unanswered outgoing call, not a missed one.
    func testMissedOnlyAppliesToTheCallee() {
        let call = makeCall(callerId: me, calleeId: them, status: "MISSED")
        XCTAssertFalse(call.wasMissed(forUserId: me))
        XCTAssertTrue(call.wasMissed(forUserId: them))
        XCTAssertEqual(call.summary(forUserId: them), "Missed · Voice")
        XCTAssertEqual(call.summary(forUserId: me), "Outgoing · Voice")
    }

    func testDeclinedReadsAsMissedForTheCallee() {
        let call = makeCall(callerId: me, calleeId: them, status: "DECLINED", kind: "VIDEO")
        XCTAssertEqual(call.summary(forUserId: them), "Missed · Video")
    }

    func testAnsweredCallShowsItsDuration() {
        let call = makeCall(callerId: me, calleeId: them, status: "ENDED",
                            answeredAt: "2026-08-17T09:00:00.000Z",
                            endedAt: "2026-08-17T09:02:14.000Z")
        XCTAssertEqual(call.summary(forUserId: me), "Outgoing · 2:14")
        XCTAssertEqual(call.summary(forUserId: them), "Incoming · 2:14")
    }

    /// Timestamps arrive with and without fractional seconds depending on the
    /// route; a parser that only handles one form silently drops the duration.
    func testDurationParsesBothTimestampForms() {
        XCTAssertEqual(ServerDate.duration(from: "2026-08-17T09:00:00Z",
                                           to: "2026-08-17T09:00:30.500Z"), "0:30")
    }

    func testUnansweredCallHasNoDuration() {
        let call = makeCall(callerId: me, calleeId: them, status: "ENDED",
                            endedAt: "2026-08-17T09:02:14.000Z")
        XCTAssertEqual(call.summary(forUserId: me), "Outgoing · Voice")
    }

    // MARK: - Fixtures

    private func makeCall(callerId: String,
                          calleeId: String,
                          status: String = "ENDED",
                          kind: String = "AUDIO",
                          answeredAt: String? = nil,
                          endedAt: String? = nil) -> Call {
        Call(id: "call-1",
             callerId: callerId,
             calleeId: calleeId,
             kind: kind,
             status: status,
             caller: User(id: callerId, username: callerId, displayName: callerId),
             callee: User(id: calleeId, username: calleeId, displayName: calleeId),
             startedAt: "2026-08-17T09:00:00.000Z",
             answeredAt: answeredAt,
             endedAt: endedAt)
    }
}
