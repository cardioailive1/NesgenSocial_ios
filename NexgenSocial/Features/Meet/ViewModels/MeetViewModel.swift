import Foundation

@MainActor
final class MeetViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var meetings: [Meeting] = []
    @Published private(set) var isLoading = false
    @Published var joinCode = ""
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        await attempt {
            meetings = try await MeetingsService.all()
        }
    }

    func joinByCode() async {
        errorMessage = nil
        let code = joinCode.trimmingCharacters(in: .whitespaces).uppercased()
        do {
            let found = try await MeetingsService.meeting(code: code)
            joinCode = ""
            MeetSession.shared.open(found)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class NewMeetingViewModel: ObservableObject, LoadingViewModel {
    @Published var title = ""
    @Published var details = ""
    @Published var scheduleIt = false
    @Published var scheduledFor = Date().addingTimeInterval(3600)
    @Published var waitingRoomEnabled = true
    @Published var muteOnEntry = true
    @Published var allowParticipantScreenShare = true
    @Published var allowChat = true
    @Published var inviteUserIds: Set<String> = []
    @Published var inviteGroupIds: Set<String> = []
    @Published private(set) var friends: [User] = []
    @Published private(set) var groups: [SocialGroup] = []
    @Published private(set) var isCreating = false
    @Published var errorMessage: String?

    /// Invite pickers are a nicety: a meeting can be created and shared by
    /// link without them, so a failure here is not shown.
    func loadInvitees() async {
        async let friendList = try? FriendsService.friends()
        async let groupList = try? GroupsService.mine()
        friends = await friendList ?? []
        groups = await groupList ?? []
    }

    func toggleFriend(_ id: String) {
        inviteUserIds.formSymmetricDifference([id])
    }

    func toggleGroup(_ id: String) {
        inviteGroupIds.formSymmetricDifference([id])
    }

    /// Returns the created meeting, or nil when creation failed.
    func create() async -> Meeting? {
        isCreating = true
        defer { isCreating = false }
        do {
            return try await MeetingsService.create(
                title: title,
                description: details,
                scheduledFor: scheduleIt ? scheduledFor : nil,
                waitingRoomEnabled: waitingRoomEnabled,
                muteOnEntry: muteOnEntry,
                allowParticipantScreenShare: allowParticipantScreenShare,
                allowChat: allowChat,
                inviteUserIds: Array(inviteUserIds),
                inviteGroupIds: Array(inviteGroupIds)
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

@MainActor
final class MeetingRoomViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var isWaiting = false
    @Published private(set) var meeting: Meeting
    @Published private(set) var participants: [MeetingParticipant] = []
    @Published private(set) var canManage = false
    @Published private(set) var isHostSeat = false
    @Published var chat: [MeetingChatMessage] = []
    @Published var draft = ""
    @Published var errorMessage: String?

    private var joined = false
    private var refresh: Task<Void, Never>?

    init(meeting: Meeting) {
        self.meeting = meeting
        isHostSeat = meeting.isHost == true
    }

    var waitingList: [MeetingParticipant] { participants.filter { !$0.admitted } }
    var admitted: [MeetingParticipant] { participants.filter(\.admitted) }

    func join() async {
        do {
            isWaiting = try await MeetingsService.join(meeting.id).waiting
            await loadDetail()

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
            if isHostSeat { try? await MeetingsService.start(meeting.id) }
            joined = true
            startRefreshing()
            await WebRTCManager.shared.connectToMeeting(meetingId: meeting.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Roster and chat, the same 5-second refresh the web room uses. There is
    /// no server push for either, so this is how a raised hand in the waiting
    /// room or a new message shows up.
    private func startRefreshing() {
        refresh?.cancel()
        refresh = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.loadDetail()
                await self?.loadChat()
                await self?.checkStillWelcome()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func loadDetail() async {
        guard let detail = try? await MeetingsService.detail(meeting.id) else { return }
        meeting = detail.meeting
        participants = detail.participants
        canManage = detail.canManage
        isHostSeat = detail.isHost
    }

    /// Being removed or having the meeting ended under you has to actually
    /// eject you, not leave you looking at a room nobody else is in.
    private func checkStillWelcome() async {
        guard let status = try? await MeetingsService.myStatus(in: meeting.id) else { return }
        if status.removed {
            // Media stops immediately, but the screen stays up: dismissing
            // here would take the reason away with it.
            errorMessage = "The host removed you from this meeting."
            refresh?.cancel()
            refresh = nil
            joined = false
            WebRTCManager.shared.disconnect()
            return
        }
        // A host muting you has to actually mute the mic, not just show a
        // badge next to your name in their roster.
        if status.mutedByHost == true, !WebRTCManager.shared.isMuted {
            WebRTCManager.shared.setMuted(true)
        }
    }

    func loadChat() async {
        guard meeting.allowChat != false else { return }
        if let messages = try? await MeetingsService.chat(in: meeting.id) { chat = messages }
    }

    func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        draft = ""
        do {
            chat.append(try await MeetingsService.send(body, to: meeting.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Host actions

    func admit(_ participant: MeetingParticipant) async {
        await hostAction { try await MeetingsService.admit(participant.id, in: meeting.id) }
    }

    func toggleMute(_ participant: MeetingParticipant) async {
        let muted = !(participant.mutedByHost ?? false)
        await hostAction {
            try await MeetingsService.setMuted(muted, participantId: participant.id, in: meeting.id)
        }
    }

    func remove(_ participant: MeetingParticipant) async {
        await hostAction { try await MeetingsService.removeParticipant(participant.id, in: meeting.id) }
    }

    func setSetting(_ key: String, _ value: Bool) async {
        await hostAction { _ = try await MeetingsService.updateSettings(meeting.id, [key: value]) }
    }

    private func hostAction(_ work: () async throws -> Void) async {
        do {
            try await work()
            await loadDetail()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leave() async {
        refresh?.cancel()
        refresh = nil
        WebRTCManager.shared.disconnect()
        // The screen is already going away, so there is nowhere to show a
        // failure; the transport is disconnected either way.
        if joined { try? await MeetingsService.exit(meeting.id, isHost: isHostSeat) }
        MeetSession.shared.close()
    }
}
