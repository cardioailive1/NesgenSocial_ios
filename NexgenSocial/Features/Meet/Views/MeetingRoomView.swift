import SwiftUI
import WebRTC

/// In-meeting UI. Media rides the same mediasoup SFU as one-to-one calls,
/// on the `meet-<id>` room, and every participant publishes.
///
/// ponytail: no screen share and no recording. Both are browser APIs on the
/// web (`getDisplayMedia`, `MediaRecorder`); on iOS screen share needs a
/// ReplayKit broadcast upload extension and recording needs the tracks
/// composited locally. Add the extension target when either is wanted.
struct MeetingRoomView: View {
    let meeting: Meeting
    @ObservedObject private var webRTC = WebRTCManager.shared
    @ObservedObject private var session = MeetSession.shared
    @StateObject private var model: MeetingRoomViewModel
    @State private var panel: Panel?

    private enum Panel: String, Identifiable {
        case people, chat
        var id: String { rawValue }
    }

    init(meeting: Meeting) {
        self.meeting = meeting
        _model = StateObject(wrappedValue: MeetingRoomViewModel(meeting: meeting))
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            if model.isWaiting {
                waitingRoom
            } else {
                VStack(spacing: 0) {
                    header
                    videoGrid
                    ErrorBanner(message: model.errorMessage)
                    // Joining the room can succeed while media fails; without
                    // this the screen just sits on "Connecting…" forever.
                    if let problem = webRTC.lastError {
                        MediaErrorNotice(message: problem)
                    }
                    controls
                }
            }
        }
        .task { await model.join() }
        .sheet(item: $panel) { which in
            switch which {
            case .people: PeoplePanel(model: model)
            case .chat: ChatPanel(model: model)
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                // Minimise, don't leave: the meeting keeps running behind
                // the rest of the app, as a video call does.
                session.isMinimized = true
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Minimise meeting")

            VStack(alignment: .leading, spacing: 2) {
                Text(model.meeting.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.slate400)
            }
            Spacer()
            MeetingShareButtons(meeting: model.meeting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var videoGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                MeetTile(track: webRTC.isCameraEnabled ? webRTC.localVideoTrack : nil,
                         label: "You",
                         muted: webRTC.isMuted,
                         highlighted: true)
                ForEach(webRTC.remoteTracks.keys.sorted(), id: \.self) { peerId in
                    MeetTile(track: webRTC.remoteTracks[peerId],
                             label: "Participant",
                             muted: false,
                             highlighted: false)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private var controls: some View {
        HStack(spacing: 18) {
            // Mic and camera state is read off the manager, not kept here:
            // minimising destroys this screen, and local flags came back
            // wrong when it was rebuilt.
            CallButton(icon: webRTC.isMuted ? "mic.slash.fill" : "mic.fill",
                       label: webRTC.isMuted ? "Unmute" : "Mute",
                       background: Theme.navy800) {
                webRTC.setMuted(!webRTC.isMuted)
            }
            CallButton(icon: webRTC.isCameraEnabled ? "video.fill" : "video.slash.fill",
                       label: webRTC.isCameraEnabled ? "Camera off" : "Camera on",
                       background: Theme.navy800) {
                webRTC.setCameraEnabled(!webRTC.isCameraEnabled)
            }
            CallButton(icon: "person.2.fill",
                       label: "People (\(model.admitted.count))",
                       background: model.waitingList.isEmpty ? Theme.navy800 : Theme.cyan400) {
                panel = .people
            }
            if model.meeting.allowChat != false {
                CallButton(icon: "bubble.left.fill",
                           label: "Chat",
                           background: Theme.navy800) { panel = .chat }
            }
            CallButton(icon: "phone.down.fill",
                       label: model.isHostSeat ? "End" : "Leave",
                       background: Theme.danger) {
                Task { await model.leave() }
            }
        }
        .padding(.bottom, 34)
        .padding(.top, 10)
    }

    private var waitingRoom: some View {
        VStack(spacing: 12) {
            Text(model.meeting.title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            Text("Waiting for the host to let you in…")
                .font(.system(size: 13))
                .foregroundStyle(Theme.slate400)
            ErrorBanner(message: model.errorMessage)
            Button("Cancel") { Task { await model.leave() } }
                .tint(Theme.slate400)
                .padding(.top, 8)
        }
        .padding(24)
    }

    private var statusText: String {
        var parts: [String] = [webRTC.isReconnecting ? "Reconnecting…"
                               : webRTC.isConnected ? "Connected" : "Connecting…"]
        if let code = model.meeting.code { parts.append(code) }
        return parts.joined(separator: " · ")
    }
}

/// One video in the grid. Mounted whether or not a track has arrived, so the
/// person is on screen from the moment they join.
struct MeetTile: View {
    let track: RTCVideoTrack?
    let label: String
    let muted: Bool
    let highlighted: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let track {
                VideoTrackView(track: track)
            } else {
                Theme.navy800.overlay(
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.slate400)
                )
            }

            HStack(spacing: 4) {
                Text(label)
                if muted { Image(systemName: "mic.slash.fill") }
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Theme.navy950.opacity(0.8))
            .clipShape(Capsule())
            .padding(6)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(highlighted ? Theme.cyan400 : Theme.line, lineWidth: 1)
        )
    }
}

/// Roster, waiting room and the host's switches — the web room's People tab.
struct PeoplePanel: View {
    @ObservedObject var model: MeetingRoomViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                List {
                    if model.canManage && !model.waitingList.isEmpty {
                        Section("Waiting to join (\(model.waitingList.count))") {
                            ForEach(model.waitingList) { person in
                                HStack {
                                    PersonLabel(participant: person)
                                    Spacer()
                                    Button("Admit") { Task { await model.admit(person) } }
                                        .buttonStyle(.borderedProminent)
                                        .tint(Theme.cyan400)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                        }
                        .listRowBackground(Theme.navy900)
                    }

                    Section("In the meeting (\(model.admitted.count))") {
                        ForEach(model.admitted) { person in
                            HStack {
                                PersonLabel(participant: person)
                                Spacer()
                                if model.canManage && !person.isHostSeat {
                                    Button {
                                        Task { await model.toggleMute(person) }
                                    } label: {
                                        Image(systemName: person.mutedByHost == true
                                              ? "speaker.slash.fill" : "mic.fill")
                                    }
                                    Button(role: .destructive) {
                                        Task { await model.remove(person) }
                                    } label: {
                                        Image(systemName: "xmark")
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Theme.navy900)

                    if model.canManage {
                        Section("Host controls") {
                            settingToggle("Lock meeting", "locked", model.meeting.locked)
                            settingToggle("Waiting room", "waitingRoomEnabled", model.meeting.waitingRoomEnabled)
                            settingToggle("Allow screen share", "allowParticipantScreenShare",
                                          model.meeting.allowParticipantScreenShare)
                            settingToggle("Allow chat", "allowChat", model.meeting.allowChat)
                        }
                        .listRowBackground(Theme.navy900)
                    }
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .tint(Theme.cyan400)
            }
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Theme.cyan400)
                }
            }
        }
    }

    private func settingToggle(_ label: String, _ key: String, _ value: Bool?) -> some View {
        Toggle(label, isOn: Binding(
            get: { value ?? false },
            set: { new in Task { await model.setSetting(key, new) } }
        ))
    }
}

struct PersonLabel: View {
    let participant: MeetingParticipant

    var body: some View {
        HStack(spacing: 9) {
            AvatarView(url: participant.user.avatarUrl,
                       seed: participant.user.username, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(participant.user.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.slate400)
            }
        }
    }

    private var subtitle: String {
        var parts = [participant.role?.capitalized ?? "Participant"]
        if participant.mutedByHost == true { parts.append("muted") }
        return parts.joined(separator: " · ")
    }
}

struct ChatPanel: View {
    @ObservedObject var model: MeetingRoomViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(model.chat) { message in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(message.sender.displayName)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Theme.cyan400)
                                        Text(message.body)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white)
                                    }
                                    .id(message.id)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                        }
                        .onChange(of: model.chat.count) { _, _ in
                            withAnimation { proxy.scrollTo(model.chat.last?.id, anchor: .bottom) }
                        }
                    }

                    ErrorBanner(message: model.errorMessage)

                    HStack(spacing: 8) {
                        TextField("Message…", text: $model.draft).fieldStyle()
                        Button("Send") { Task { await model.send() } }
                            .disabled(model.draft.trimmingCharacters(in: .whitespaces).isEmpty)
                            .tint(Theme.cyan400)
                    }
                    .padding(12)
                }
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.loadChat() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Theme.cyan400)
                }
            }
        }
    }
}
