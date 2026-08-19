import SwiftUI

/// NexgenMeet: list your meetings, create one, or join with a code.
struct MeetView: View {
    @StateObject private var model = MeetViewModel()
    @State private var showingCreate = false

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    TextField("Join code", text: $model.joinCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .fieldStyle()
                    Button("Join") { Task { await model.joinByCode() } }
                        .disabled(model.joinCode.isEmpty)
                        .tint(Theme.cyan400)
                }
                .padding(12)

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.danger)
                        .padding(.horizontal, 12)
                }

                if model.meetings.isEmpty && !model.isLoading {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("No meetings yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Start one, or enter a code you were given.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                    }
                    Spacer()
                } else {
                    List(model.meetings) { meeting in
                        Button {
                            model.activeMeeting = meeting
                        } label: {
                            MeetingRow(meeting: meeting)
                        }
                        .listRowBackground(Theme.navy900)
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable { await model.load() }
                }
            }
        }
        .navigationTitle("Meet")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .tint(Theme.cyan400)
        .task { await model.load() }
        .sheet(isPresented: $showingCreate) {
            NewMeetingView { created in
                await model.load()
                model.activeMeeting = created
            }
        }
        .fullScreenCover(item: $model.activeMeeting) { meeting in
            MeetingRoomView(meeting: meeting)
        }

    }

}

struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(meeting.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
            }
            Spacer()
            if meeting.isLive {
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.navy950)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Theme.danger)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let host = meeting.host?.displayName { parts.append(host) }
        if let code = meeting.code { parts.append(code) }
        if let count = meeting.participantCount { parts.append("\(count) in room") }
        return parts.joined(separator: " · ")
    }
}

struct NewMeetingView: View {
    @Environment(\.dismiss) private var dismiss
    let onCreated: (Meeting) async -> Void

    @StateObject private var model = NewMeetingViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Meeting title", text: $model.title).fieldStyle()
                    Toggle("Waiting room", isOn: $model.waitingRoomEnabled)
                    Toggle("Mute on entry", isOn: $model.muteOnEntry)
                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                    }
                    Spacer()
                }
                .tint(Theme.cyan400)
                .foregroundStyle(.white)
                .padding(16)
            }
            .navigationTitle("New meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.isCreating ? "Creating…" : "Create") { Task { await create() } }
                        .tint(Theme.cyan400)
                        .disabled(model.title.isEmpty || model.isCreating)
                }
            }
        }
    }

    private func create() async {
        guard let meeting = await model.create() else { return }
        dismiss()
        await onCreated(meeting)
    }
}

/// In-meeting UI. Media rides the same mediasoup SFU as one-to-one calls,
/// on the `meet-<id>` room.
// ponytail: renders one remote track because WebRTCManager keeps a single
// `remoteVideoTrack`. Fine for two people; for a real grid, change the
// manager to hold [peerId: RTCVideoTrack] and lay them out here.
struct MeetingRoomView: View {
    let meeting: Meeting
    @ObservedObject private var webRTC = WebRTCManager.shared
    @StateObject private var model: MeetingRoomViewModel
    @Environment(\.dismiss) private var dismiss

    init(meeting: Meeting) {
        self.meeting = meeting
        _model = StateObject(wrappedValue: MeetingRoomViewModel(meeting: meeting))
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            if let remote = webRTC.remoteVideoTrack {
                VideoTrackView(track: remote).ignoresSafeArea()
            }

            VStack(spacing: 18) {
                Spacer()

                if webRTC.remoteVideoTrack == nil {
                    Text(meeting.title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(statusText)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.slate400)
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.danger)
                }

                // Joining the room can succeed while media fails; without
                // this the screen just sits on "Connecting…" forever.
                if let problem = webRTC.lastError {
                    MediaErrorNotice(message: problem)
                }

                Spacer()

                HStack(spacing: 26) {
                    CallButton(icon: model.isMuted ? "mic.slash.fill" : "mic.fill",
                               label: model.isMuted ? "Unmute" : "Mute",
                               background: Theme.navy800) {
                        model.isMuted.toggle()
                        webRTC.setMuted(model.isMuted)
                    }
                    CallButton(icon: model.isCameraOff ? "video.slash.fill" : "video.fill",
                               label: model.isCameraOff ? "Camera on" : "Camera off",
                               background: Theme.navy800) {
                        model.isCameraOff.toggle()
                        webRTC.setCameraEnabled(!model.isCameraOff)
                    }
                    CallButton(icon: "phone.down.fill",
                               label: meeting.isHost == true ? "End" : "Leave",
                               background: Theme.danger) {
                        Task { await model.leave(); dismiss() }
                    }
                }
                .padding(.bottom, 50)
            }

            if let local = webRTC.localVideoTrack, !model.isCameraOff {
                VStack {
                    HStack {
                        Spacer()
                        VideoTrackView(track: local)
                            .frame(width: 104, height: 156)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Theme.line, lineWidth: 1)
                            )
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }
                .padding(.top, 16)
            }
        }
        .task { await model.join() }
        .onDisappear { webRTC.disconnect() }
    }

    private var statusText: String {
        if model.isWaiting { return "Waiting for the host to let you in…" }
        return webRTC.isConnected ? "Connected" : "Connecting…"
    }

}
