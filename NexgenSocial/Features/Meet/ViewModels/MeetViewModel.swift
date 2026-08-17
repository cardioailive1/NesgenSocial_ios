import Foundation

@MainActor
final class MeetViewModel: ObservableObject {
    @Published private(set) var meetings: [Meeting] = []
    @Published private(set) var isLoading = false
    @Published var joinCode = ""
    @Published var activeMeeting: Meeting?
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            meetings = try await MeetingsService.all()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinByCode() async {
        errorMessage = nil
        let code = joinCode.trimmingCharacters(in: .whitespaces).uppercased()
        do {
            let found = try await MeetingsService.meeting(code: code)
            joinCode = ""
            activeMeeting = found
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class NewMeetingViewModel: ObservableObject {
    @Published var title = ""
    @Published var waitingRoomEnabled = true
    @Published var muteOnEntry = true
    @Published private(set) var isCreating = false
    @Published var errorMessage: String?

    /// Returns the created meeting, or nil when creation failed.
    func create() async -> Meeting? {
        isCreating = true
        defer { isCreating = false }
        do {
            return try await MeetingsService.create(title: title,
                                                    waitingRoomEnabled: waitingRoomEnabled,
                                                    muteOnEntry: muteOnEntry)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

@MainActor
final class MeetingRoomViewModel: ObservableObject {
    @Published private(set) var isWaiting = false
    @Published var isMuted = false
    @Published var isCameraOff = false
    @Published var errorMessage: String?

    private var joined = false
    private let meeting: Meeting

    init(meeting: Meeting) { self.meeting = meeting }

    private var isHost: Bool { meeting.isHost == true }

    func join() async {
        do {
            isWaiting = try await MeetingsService.join(meeting.id).waiting

            // Host controls admission, so hold outside the SFU room until
            // admitted rather than joining and being muted.
            while isWaiting && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                let status = try await MeetingsService.myStatus(in: meeting.id)
                if status.removed {
                    errorMessage = "The host removed you from this meeting."
                    return
                }
                isWaiting = !status.admitted
            }
            guard !Task.isCancelled else { return }

            // Host arriving marks the meeting live for everyone else.
            // Bookkeeping for other participants' list view; failing it
            // shouldn't stop the host entering their own meeting.
            if isHost { try? await MeetingsService.start(meeting.id) }
            joined = true
            await WebRTCManager.shared.connectToMeeting(meetingId: meeting.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leave() async {
        WebRTCManager.shared.disconnect()
        // The screen is already going away, so there is nowhere to show a
        // failure; the transport is disconnected either way.
        if joined { try? await MeetingsService.exit(meeting.id, isHost: isHost) }
    }
}
