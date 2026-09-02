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
    var waitingRoomEnabled: Bool?
    var muteOnEntry: Bool?
    var allowParticipantScreenShare: Bool?
    var allowChat: Bool?
    var locked: Bool?

    var isLive: Bool { status == "LIVE" }

    /// The web app's meeting route — what gets shared and copied. Anyone who
    /// opens it lands on the same meeting the code would take them to.
    var shareURL: URL? { URL(string: "\(APIClient.webBaseURL)/meet/\(id)") }

    var shareText: String {
        var text = "Join \"\(title)\" on NexgenMeet"
        if let code { text += "\nCode: \(code)" }
        if let shareURL { text += "\n\(shareURL.absoluteString)" }
        return text
    }
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

/// `GET /:id` — the room's roster, host permissions and recordings.
struct MeetingDetailResponse: Codable {
    let meeting: Meeting
    let isHost: Bool
    let canManage: Bool
    let participants: [MeetingParticipant]
    var recordings: [MeetingRecording]?
}

struct MeetingParticipant: Codable, Identifiable, Hashable {
    let id: String
    let user: User
    var role: String?
    var admitted: Bool
    var mutedByHost: Bool?
    var joinedAt: String?

    var isHostSeat: Bool { role == "HOST" }
}

struct MeetingChatMessage: Codable, Identifiable, Hashable {
    let id: String
    let body: String
    let sender: User
    var createdAt: String?
}

struct MeetingChatResponse: Codable { let messages: [MeetingChatMessage] }
struct MeetingChatSendResponse: Codable { let message: MeetingChatMessage }

struct MeetingRecording: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    var visibility: String?
    var createdAt: String?

    var isPublic: Bool { visibility == "PUBLIC" }
}
