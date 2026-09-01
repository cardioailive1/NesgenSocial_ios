import SwiftUI
import AVKit

struct ReelsView: View {
    @StateObject private var model = ReelsViewModel()
    /// Tracked by id rather than index: `scrollPosition` reports the item, and
    /// an index would go stale the moment the list reloads.
    @State private var currentID: String?
    /// TabView keeps this view alive when another tab is selected, so the cells
    /// never get an `onDisappear` and would keep playing audio off-screen.
    @State private var onScreen = false
    @Environment(\.scenePhase) private var scenePhase
    /// The tab's own selection, which is the signal `onAppear`/`onDisappear`
    /// don't reliably give inside a `TabView`.
    @Environment(\.isTabActive) private var isTabActive

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if model.reels.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: model.errorMessage == nil
                              ? "play.rectangle" : "wifi.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.slate400)
                        Text(model.errorMessage == nil ? "No reels yet" : "Couldn't load reels")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(model.errorMessage ?? "Record the first one — reels reach people who don't follow you yet.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    // Vertical paging, the standard short-form interaction.
                    //
                    // This used to rotate each cell -90 degrees and the
                    // container +90 to coerce a horizontal TabView into
                    // paging vertically. That arithmetic breaks once safe-area
                    // insets enter it -- the overlay ends up clipped off the
                    // edge -- and iOS 17 pages vertically on its own, so the
                    // rotation is gone.
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(model.reels) { reel in
                                ReelCell(reel: reel, isActive: onScreen && isTabActive && scenePhase == .active
                                                    && currentID == reel.id) {
                                    await model.toggleLike(reel)
                                } onWatched: { seconds, completed in
                                    await model.reportView(reel, watchedSec: seconds, completed: completed)
                                }
                                .frame(width: geo.size.width, height: geo.size.height)
                                .id(reel.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $currentID)
                    .scrollIndicators(.hidden)
                    .onAppear { currentID = currentID ?? model.reels.first?.id }
                    .onChange(of: model.reels.count) { _, _ in
                        if currentID == nil { currentID = model.reels.first?.id }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .task { await model.load() }
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
    }
}

struct ReelCell: View {
    let reel: Reel
    let isActive: Bool
    let onLike: () async -> Void
    let onWatched: (Double, Bool) async -> Void

    @State private var player: AVPlayer?
    @State private var watchedSeconds: Double = 0
    @State private var timeObserver: Any?

    private var url: URL? { APIClient.mediaURL(reel.videoUrl) }

    /// WebM can't go through AVPlayer, so those reels lose the periodic time
    /// observer and report watch time from the web view instead.
    private var needsWebKit: Bool {
        url?.pathExtension.lowercased() == "webm"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black

            if needsWebKit {
                if isActive {
                    WebVideoView(url: url!, loop: true, autoplay: true) { seconds in
                        watchedSeconds = max(watchedSeconds, seconds)
                    }
                    .allowsHitTesting(false)
                }
            } else if let player {
                VideoPlayer(player: player)
                    .allowsHitTesting(false)
            }

            // Overlaid metadata, weighted toward the bottom like every
            // short-form player.
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        AvatarView(url: reel.author?.avatarUrl, seed: reel.author?.username ?? "?", size: 32)
                        Text("@\(reel.author?.username ?? "")")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    if let caption = reel.caption {
                        Text(caption)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                    }
                    if let tags = reel.hashtags, !tags.isEmpty {
                        Text(tags.map { "#\($0)" }.joined(separator: " "))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.cyan300)
                    }
                }
                Spacer()

                VStack(spacing: 18) {
                    Button { Task { await onLike() } } label: {
                        VStack(spacing: 2) {
                            Image(systemName: (reel.likedByViewer ?? false) ? "heart.fill" : "heart")
                                .font(.system(size: 26))
                                .foregroundStyle((reel.likedByViewer ?? false) ? Theme.cyan400 : .white)
                            Text("\(reel.likeCount ?? 0)")
                                .font(.system(size: 11)).foregroundStyle(.white)
                        }
                    }
                    VStack(spacing: 2) {
                        Image(systemName: "eye").font(.system(size: 22)).foregroundStyle(.white)
                        Text("\(reel.viewCount ?? 0)").font(.system(size: 11)).foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
        }
        .onChange(of: isActive) { _, active in
            active ? start() : stop()
        }
        .onAppear { if isActive { start() } }
        .onDisappear { stop() }
    }

    private func start() {
        // The web view starts itself as soon as it appears.
        guard !needsWebKit, let url else { return }
        MediaAudio.activateForPlayback()
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.actionAtItemEnd = .none

        // Loop. Replays are a genuine ranking signal, not just a nicety.
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { _ in
            Task { @MainActor in await onWatched(reel.durationSec ?? watchedSeconds, true) }
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }

        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main
        ) { time in
            watchedSeconds = max(watchedSeconds, time.seconds)
        }

        player = newPlayer
        newPlayer.play()
    }

    private func stop() {
        if watchedSeconds > 0.5 {
            Task { await onWatched(watchedSeconds, false) }
        }
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
        player?.pause()
        player = nil
        watchedSeconds = 0
    }
}
