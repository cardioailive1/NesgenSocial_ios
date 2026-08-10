import Foundation

// MARK: - Meetings (NexgenMeet)

struct Meeting: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    var description: String?
    var code: String?
    var status: String?
    var scheduledFor: String?
    var startedAt: String?
    var host: User?
    var participantCount: Int?
    var isHost: Bool?
    var allowChat: Bool?

    var isLive: Bool { status == "LIVE" }
}

struct MeetingsResponse: Codable { let meetings: [Meeting] }
struct MeetingResponse: Codable { let meeting: Meeting }

/// `POST /:id/join` — `waiting` is true while the waiting room holds you.
struct MeetingJoinResponse: Codable {
    let waiting: Bool
    let meeting: Meeting
}

/// `GET /:id/my-status` — polled from the waiting room.
struct MeetingStatusResponse: Codable {
    let admitted: Bool
    let removed: Bool
    var mutedByHost: Bool?
    let present: Bool
}
