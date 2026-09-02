import Foundation

enum MeetingsService {

    static func all() async throws -> [Meeting] {
        try await APIClient.shared.get(APIEndpoints.Meetings.root, as: MeetingsResponse.self).meetings
    }

    static func meeting(code: String) async throws -> Meeting {
        try await APIClient.shared
            .get(APIEndpoints.Meetings.byCode(code), as: MeetingResponse.self).meeting
    }

    static func create(title: String,
                       description: String,
                       scheduledFor: Date?,
                       waitingRoomEnabled: Bool,
                       muteOnEntry: Bool,
                       allowParticipantScreenShare: Bool,
                       allowChat: Bool,
                       inviteUserIds: [String],
                       inviteGroupIds: [String]) async throws -> Meeting {
        var body: [String: Any] = [
            "title": title,
            "waitingRoomEnabled": waitingRoomEnabled,
            "muteOnEntry": muteOnEntry,
            "allowParticipantScreenShare": allowParticipantScreenShare,
            "allowChat": allowChat,
            "inviteUserIds": inviteUserIds,
            "inviteGroupIds": inviteGroupIds,
        ]
        if !description.isEmpty { body["description"] = description }
        // The server takes whatever `new Date()` parses; ISO-8601 is the one
        // format that means the same thing on both ends.
        if let scheduledFor {
            body["scheduledFor"] = ISO8601DateFormatter().string(from: scheduledFor)
        }
        return try await APIClient.shared.post(APIEndpoints.Meetings.root,
                                               body: body,
                                               as: MeetingResponse.self).meeting
    }

    /// Roster, host permissions and recordings. Polled from the room, so it
    /// must never come back from the cache.
    static func detail(_ meetingId: String) async throws -> MeetingDetailResponse {
        try await APIClient.shared.get(APIEndpoints.Meetings.detail(meetingId),
                                       as: MeetingDetailResponse.self, maxAge: 0)
    }

    static func join(_ meetingId: String) async throws -> MeetingJoinResponse {
        try await APIClient.shared.post(APIEndpoints.Meetings.join(meetingId),
                                        as: MeetingJoinResponse.self)
    }

    /// Polled while sitting in the waiting room: a cached "not admitted yet"
    /// would leave someone stuck outside a meeting they have been let into.
    static func myStatus(in meetingId: String) async throws -> MeetingStatusResponse {
        try await APIClient.shared.get(APIEndpoints.Meetings.myStatus(meetingId),
                                       as: MeetingStatusResponse.self, maxAge: 0)
    }

    static func start(_ meetingId: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Meetings.start(meetingId),
                                            as: MeetingResponse.self)
    }

    /// Hosts end the meeting for everyone; guests only leave it.
    static func exit(_ meetingId: String, isHost: Bool) async throws {
        if isHost {
            _ = try await APIClient.shared.post(APIEndpoints.Meetings.end(meetingId),
                                                as: MeetingResponse.self)
        } else {
            _ = try await APIClient.shared.post(APIEndpoints.Meetings.leave(meetingId),
                                                as: EmptyResponse.self)
        }
    }

    // MARK: - Host controls

    static func updateSettings(_ meetingId: String, _ changes: [String: Bool]) async throws -> Meeting {
        try await APIClient.shared.patch(APIEndpoints.Meetings.settings(meetingId),
                                         body: changes,
                                         as: MeetingResponse.self).meeting
    }

    static func admit(_ participantId: String, in meetingId: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Meetings.admit(meetingId, participantId),
                                            as: MeetingParticipantResponse.self)
    }

    static func setMuted(_ muted: Bool, participantId: String, in meetingId: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Meetings.mute(meetingId, participantId),
                                            body: ["muted": muted],
                                            as: MeetingParticipantResponse.self)
    }

    static func removeParticipant(_ participantId: String, in meetingId: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Meetings.remove(meetingId, participantId),
                                            as: MeetingParticipantResponse.self)
    }

    static func invite(userIds: [String], groupIds: [String], to meetingId: String) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Meetings.invite(meetingId),
                                            body: ["userIds": userIds, "groupIds": groupIds],
                                            as: EmptyResponse.self)
    }

    // MARK: - Chat

    static func chat(in meetingId: String) async throws -> [MeetingChatMessage] {
        try await APIClient.shared.get(APIEndpoints.Meetings.chat(meetingId),
                                       as: MeetingChatResponse.self, maxAge: 0).messages
    }

    static func send(_ body: String, to meetingId: String) async throws -> MeetingChatMessage {
        try await APIClient.shared.post(APIEndpoints.Meetings.chat(meetingId),
                                        body: ["body": body],
                                        as: MeetingChatSendResponse.self).message
    }
}

struct MeetingParticipantResponse: Codable { let participant: MeetingParticipant }
