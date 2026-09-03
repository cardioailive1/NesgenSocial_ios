import SwiftUI

/// Streams that are live right now, and the controls to start or end your
/// own. Media rides the same SFU as calls and meetings.
struct LivestreamsView: View {
    @StateObject private var model = LivestreamsViewModel()
    @State private var showingStart = false

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if model.streams.isEmpty {
                        Text("Nobody is live right now.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    }

                    ErrorBanner(message: model.errorMessage)

                    ForEach(model.streams) { stream in
                        Button {
                            model.watching = stream
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(url: stream.host?.avatarUrl,
                                           seed: stream.host?.username ?? "?", size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(stream.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(subtitle(for: stream))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.slate400)
                                }
                                Spacer(minLength: 0)
                                Text("LIVE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.navy950)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Theme.danger)
                                    .clipShape(Capsule())
                            }
                            .padding(12)
                            .card()
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .pullToRefresh { await model.load() }
        }
        .navigationTitle("Live")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Go live") { showingStart = true }
                    .font(.system(size: 13))
            }
        }
        .tint(Theme.cyan400)
        .alert("Start a stream", isPresented: $showingStart) {
            TextField("Title", text: $model.newTitle)
            Button("Start") { Task { await model.start() } }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(item: $model.watching) { stream in
            LivestreamRoomView(stream: stream,
                               onEnded: { await model.load() },
                               onEndFailed: { model.errorMessage = $0 })
        }
        .task { await model.load() }
    }

    private func subtitle(for stream: Livestream) -> String {
        var parts: [String] = []
        if let host = stream.host?.displayName { parts.append(host) }
        if let newsroom = stream.newsroom?.name { parts.append(newsroom) }
        return parts.joined(separator: " · ")
    }
}

/// Watching or hosting a stream. The SFU room id follows the same
/// convention as calls and meetings.
struct LivestreamRoomView: View {
    let stream: Livestream
    let onEnded: () async -> Void
    /// Ending the stream is reported back to the list, which owns the error
    /// line; this room is dismissed by the time it would be shown.
    let onEndFailed: (String) -> Void

    @ObservedObject private var webRTC = WebRTCManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: AuthSession
    @State private var hostEnded = false

    private var isHost: Bool { stream.host?.id == session.currentUser?.id }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            if let remote = webRTC.remoteVideoTrack {
                VideoTrackView(track: remote).ignoresSafeArea()
            } else if let local = webRTC.localVideoTrack, isHost {
                VideoTrackView(track: local).ignoresSafeArea()
            }

            VStack {
                HStack {
                    Text(stream.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button(isHost ? "End" : "Close") {
                        Task { await leave() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.danger)
                    .font(.system(size: 13))
                }
                .padding(16)
                Spacer()
                if let problem = webRTC.lastError {
                    MediaErrorNotice(message: problem)
                    Spacer()
                } else if hostEnded {
                    Text("This stream has ended.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.slate400)
                    Spacer()
                } else if webRTC.remoteVideoTrack == nil && !isHost {
                    Text("Connecting to the stream…")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.slate400)
                    Spacer()
                }
            }
        }
        .task { await webRTC.connectToLivestream(streamId: stream.id, asHost: isHost) }
        // A viewer gets no signal when the host ends: the SFU room just goes
        // quiet. The list only returns LIVE streams, so ask for this one.
        .task { await watchForEnd() }
        .onDisappear { webRTC.disconnect() }
    }

    private func watchForEnd() async {
        guard !isHost else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            guard let live = try? await LivestreamsService.detail(stream.id) else { continue }
            if live.status != "LIVE" {
                hostEnded = true
                webRTC.disconnect()
                return
            }
        }
    }

    private func leave() async {
        webRTC.disconnect()
        if isHost {
            do {
                try await LivestreamsService.end(stream.id)
            } catch {
                onEndFailed(error.localizedDescription)
            }
        }
        await onEnded()
        dismiss()
    }
}

/// Starting a stream from the Create sheet: title, start, then straight into
/// the room. The Live tab keeps its own inline alert for the same thing.
struct StartLiveView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = LivestreamsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                Form {
                    Section {
                        TextField("What are you streaming?", text: $model.newTitle)
                    }
                    .listRowBackground(Theme.navy900)

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                            .listRowBackground(Theme.navy900)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Go live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { Task { await model.start() } }
                        .disabled(model.newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .tint(Theme.cyan400)
        }
        .fullScreenCover(item: $model.watching) { stream in
            LivestreamRoomView(stream: stream,
                               onEnded: { dismiss() },
                               onEndFailed: { model.errorMessage = $0 })
        }
    }
}
