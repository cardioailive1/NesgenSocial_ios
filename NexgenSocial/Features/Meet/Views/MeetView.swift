import SwiftUI
import WebRTC

/// NexgenMeet: list your meetings, create one, or join with a code.
struct MeetView: View {
    @StateObject private var model = MeetViewModel()
    @ObservedObject private var session = MeetSession.shared
    @State private var showingCreate = false
    @State private var createdMeeting: Meeting?

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

                ErrorBanner(message: model.errorMessage)

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
                        MeetingRow(meeting: meeting) { session.open(meeting) }
                            .listRowBackground(Theme.navy900)
                    }
                    .scrollContentBackground(.hidden)
                    .pullToRefresh { await model.load() }
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
                createdMeeting = created
            }
        }
        // Sharing the link is the first thing you do with a new meeting, so
        // it is offered before the room opens rather than hidden inside it.
        .sheet(item: $createdMeeting) { meeting in
            MeetingCreatedView(meeting: meeting) { session.open(meeting) }
        }
    }
}

struct MeetingRow: View {
    let meeting: Meeting
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(meeting.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    if meeting.isHost == true {
                        Text("HOST")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.cyan400)
                    }
                    if meeting.isLive {
                        Text("LIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.navy950)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.danger)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
            }
            Spacer(minLength: 8)
            MeetingShareButtons(meeting: meeting)
            Button(meeting.isLive ? "Join" : "Open", action: onOpen)
                .buttonStyle(.borderedProminent)
                .tint(Theme.cyan400)
                .foregroundStyle(Theme.navy950)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.vertical, 4)
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let host = meeting.host?.displayName { parts.append(host) }
        if let code = meeting.code { parts.append(code) }
        if let count = meeting.participantCount { parts.append("\(count) in room") }
        return parts.joined(separator: " · ")
    }
}

/// Copy and share, side by side. Both hand over the same thing the web app
/// puts in the address bar, so a link opened anywhere lands in the meeting.
struct MeetingShareButtons: View {
    let meeting: Meeting
    @State private var copied = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                UIPasteboard.general.string = meeting.shareURL?.absoluteString ?? meeting.code
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundStyle(copied ? Theme.cyan400 : Theme.slate400)
            }
            .accessibilityLabel(copied ? "Link copied" : "Copy meeting link")

            if let url = meeting.shareURL {
                ShareLink(item: url, message: Text(meeting.shareText)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.slate400)
                }
                .accessibilityLabel("Share meeting link")
            }
        }
        .buttonStyle(.plain)
    }
}

/// Shown once, right after a meeting is created: the code, the link, and the
/// two things you want to do with them before anyone can join.
struct MeetingCreatedView: View {
    let meeting: Meeting
    let onOpen: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text(meeting.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)

                    if let code = meeting.code {
                        VStack(spacing: 4) {
                            Text("MEETING CODE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.slate400)
                            Text(code)
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.cyan400)
                                .textSelection(.enabled)
                        }
                    }

                    if let url = meeting.shareURL {
                        Text(url.absoluteString)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.slate400)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = meeting.shareURL?.absoluteString ?? meeting.code
                            copied = true
                        } label: {
                            Label(copied ? "Copied" : "Copy link", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        if let url = meeting.shareURL {
                            ShareLink(item: url, message: Text(meeting.shareText)) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Button("Start meeting") {
                        dismiss()
                        onOpen()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.cyan400)
                    .foregroundStyle(Theme.navy950)

                    Spacer()
                }
                .padding(20)
                .tint(Theme.cyan400)
            }
            .navigationTitle("Meeting ready")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }.tint(Theme.slate400)
                }
            }
        }
        .presentationDetents([.medium])
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
                Form {
                    Section {
                        TextField("Meeting title", text: $model.title)
                        TextField("What's it about? (optional)", text: $model.details, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    .listRowBackground(Theme.navy900)

                    Section {
                        Toggle("Schedule for later", isOn: $model.scheduleIt)
                        if model.scheduleIt {
                            DatePicker("Starts", selection: $model.scheduledFor)
                        }
                    } footer: {
                        Text("Leave off to start the meeting now.")
                    }
                    .listRowBackground(Theme.navy900)

                    Section("Host controls") {
                        Toggle("Waiting room", isOn: $model.waitingRoomEnabled)
                        Toggle("Mute on entry", isOn: $model.muteOnEntry)
                        Toggle("Allow screen share", isOn: $model.allowParticipantScreenShare)
                        Toggle("Allow chat", isOn: $model.allowChat)
                    }
                    .listRowBackground(Theme.navy900)

                    if !model.friends.isEmpty {
                        Section("Invite friends") {
                            ForEach(model.friends) { friend in
                                InviteRow(name: friend.displayName,
                                          avatar: friend.avatarUrl,
                                          seed: friend.username,
                                          selected: model.inviteUserIds.contains(friend.id)) {
                                    model.toggleFriend(friend.id)
                                }
                            }
                        }
                        .listRowBackground(Theme.navy900)
                    }

                    if !model.groups.isEmpty {
                        Section("Invite groups") {
                            ForEach(model.groups) { group in
                                InviteRow(name: group.name,
                                          avatar: nil,
                                          seed: group.name,
                                          selected: model.inviteGroupIds.contains(group.id)) {
                                    model.toggleGroup(group.id)
                                }
                            }
                        }
                        .listRowBackground(Theme.navy900)
                    }

                    if model.errorMessage != nil {
                        ErrorBanner(message: model.errorMessage)
                            .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .tint(Theme.cyan400)
                .foregroundStyle(.white)
            }
            .navigationTitle("New meeting")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.loadInvitees() }
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

struct InviteRow: View {
    let name: String
    let avatar: String?
    let seed: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AvatarView(url: avatar, seed: seed, size: 28)
                Text(name)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.cyan400 : Theme.slate400)
            }
        }
    }
}
