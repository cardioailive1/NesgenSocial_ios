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
                       waitingRoomEnabled: Bool,
                       muteOnEntry: Bool) async throws -> Meeting {
        try await APIClient.shared.post(APIEndpoints.Meetings.root,
                                        body: ["title": title,
                                               "waitingRoomEnabled": waitingRoomEnabled,
                                               "muteOnEntry": muteOnEntry],
                                        as: MeetingResponse.self).meeting
    }

    static func join(_ meetingId: String) async throws -> MeetingJoinResponse {
        try await APIClient.shared.post(APIEndpoints.Meetings.join(meetingId),
                                        as: MeetingJoinResponse.self)
    }

    static func myStatus(in meetingId: String) async throws -> MeetingStatusResponse {
        try await APIClient.shared.get(APIEndpoints.Meetings.myStatus(meetingId),
                                       as: MeetingStatusResponse.self)
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
}
