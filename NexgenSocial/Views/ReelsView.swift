import SwiftUI
import AVKit

@MainActor
final class ReelsViewModel: ObservableObject {
    @Published var reels: [Reel] = []
    @Published var isLoading = false

    func load() async {
        isLoading = true
        defer { isLoading = false }
        reels = (try? await APIClient.shared.get("/api/reels/discover", as: ReelsResponse.self).reels) ?? []
    }

    /// Watch time drives ranking on the server, so it's reported per reel
    /// rather than treating every appearance as a full view.
    func reportView(_ reel: Reel, watchedSec: Double, completed: Bool) async {
        _ = try? await APIClient.shared.post(
            "/api/reels/\(reel.id)/view",
            body: ["watchedSec": watchedSec, "completed": completed],
            as: EmptyResponse.self
        )
    }

    func toggleLike(_ reel: Reel) async {
        guard let index = reels.firstIndex(where: { $0.id == reel.id }) else { return }
        let wasLiked = reels[index].likedByViewer ?? false
        reels[index].likedByViewer = !wasLiked
        reels[index].likeCount = (reels[index].likeCount ?? 0) + (wasLiked ? -1 : 1)

        if wasLiked {
            _ = try? await APIClient.shared.delete("/api/reels/\(reel.id)/like")
        } else {
            _ = try? await APIClient.shared.post("/api/reels/\(reel.id)/like", as: EmptyResponse.self)
        }
    }
}

struct ReelsView: View {
    @StateObject private var model = ReelsViewModel()
    @State private var currentIndex = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if model.reels.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.slate400)
                        Text("No reels yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Record the first one — reels reach people who don't follow you yet.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    // Vertical paging, the standard short-form interaction.
                    TabView(selection: $currentIndex) {
                        ForEach(Array(model.reels.enumerated()), id: \.element.id) { i, reel in
                            ReelCell(reel: reel, isActive: i == currentIndex) {
                                await model.toggleLike(reel)
                            } onWatched: { seconds, completed in
                                await model.reportView(reel, watchedSec: seconds, completed: completed)
                            }
                            .rotationEffect(.degrees(-90))
                            .frame(width: geo.size.width, height: geo.size.height)
                            .tag(i)
                        }
                    }
                    .frame(width: geo.size.height, height: geo.size.width)
                    .rotationEffect(.degrees(90), anchor: .topLeading)
                    .offset(x: geo.size.width)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
        .ignoresSafeArea()
        .task { await model.load() }
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

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black

            if let player {
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
        guard let url = APIClient.mediaURL(reel.videoUrl) else { return }
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.actionAtItemEnd = .none

        // Loop. Replays are a genuine ranking signal, not just a nicety.
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { _ in
            Task { await onWatched(reel.durationSec ?? watchedSeconds, true) }
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
