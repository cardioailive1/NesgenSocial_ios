import SwiftUI
import AVKit
import PhotosUI

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await APIClient.shared.get("/api/posts/feed", as: FeedResponse.self).posts
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(_ post: Post) async {
        // Optimistic: the like animates immediately and reverts if the
        // request fails. Waiting on the network makes taps feel broken.
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let wasLiked = posts[index].likedByViewer ?? false
        posts[index].likedByViewer = !wasLiked
        posts[index].likeCount = (posts[index].likeCount ?? 0) + (wasLiked ? -1 : 1)

        do {
            if wasLiked {
                _ = try await APIClient.shared.delete("/api/posts/\(post.id)/like")
            } else {
                _ = try await APIClient.shared.post("/api/posts/\(post.id)/like", as: EmptyResponse.self)
            }
        } catch {
            posts[index].likedByViewer = wasLiked
            posts[index].likeCount = (posts[index].likeCount ?? 0) + (wasLiked ? 1 : -1)
        }
    }
}

struct FeedView: View {
    @StateObject private var model = FeedViewModel()
    @State private var showComposer = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let error = model.errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.danger)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .card()
                        }

                        ForEach(model.posts) { post in
                            PostCard(post: post) { await model.toggleLike(post) }
                        }

                        if model.posts.isEmpty && !model.isLoading {
                            VStack(spacing: 8) {
                                Text("Your feed is empty")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("Follow a few people, or post something yourself.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.slate400)
                            }
                            .padding(30)
                            .frame(maxWidth: .infinity)
                            .card()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .refreshable { await model.load() }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showComposer = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .tint(Theme.cyan400)
                }
            }
            .sheet(isPresented: $showComposer) {
                ComposerView { await model.load() }
            }
            .task { await model.load() }
        }
    }
}

struct PostCard: View {
    let post: Post
    let onLike: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AvatarView(url: post.author?.avatarUrl, seed: post.author?.username ?? "?", size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text(post.author?.displayName ?? "Unknown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("@\(post.author?.username ?? "")")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.slate400)
                }
                Spacer()
            }

            if let body = post.body, !body.isEmpty {
                Text(body)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.slate300)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !post.displayMedia.isEmpty {
                MediaCarousel(items: post.displayMedia)
            }

            HStack(spacing: 20) {
                Button {
                    Task { await onLike() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: (post.likedByViewer ?? false) ? "heart.fill" : "heart")
                        Text("\(post.likeCount ?? 0)")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle((post.likedByViewer ?? false) ? Theme.cyan400 : Theme.slate400)
                }

                HStack(spacing: 5) {
                    Image(systemName: "bubble.right")
                    Text("\(post.commentCount ?? 0)")
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.slate400)

                Spacer()

                if let reason = post.reason {
                    Text(reason)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.slate400)
                }
            }
        }
        .padding(14)
        .card()
    }
}

/// Swipeable media, handling photo and video in one control.
struct MediaCarousel: View {
    let items: [MediaItem]
    @State private var index = 0

    var body: some View {
        VStack(spacing: 6) {
            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    Group {
                        if item.kind == .video {
                            VideoPlayerView(url: APIClient.mediaURL(item.url))
                        } else {
                            AsyncImage(url: APIClient.mediaURL(item.url)) { phase in
                                switch phase {
                                case .success(let image):
                                    // .fit, not .fill: cropping a portrait
                                    // photo to a landscape box hides part
                                    // of the picture, which is exactly the
                                    // bug the web app had.
                                    image.resizable().aspectRatio(contentMode: .fit)
                                case .failure:
                                    Image(systemName: "photo")
                                        .foregroundStyle(Theme.slate400)
                                default:
                                    ProgressView().tint(Theme.cyan400)
                                }
                            }
                        }
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .automatic : .never))
            .frame(height: 300)
            .background(Theme.navy950)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct VideoPlayerView: View {
    let url: URL?
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
            }
        }
        .onAppear {
            guard let url else { return }
            player = AVPlayer(url: url)
        }
        .onDisappear {
            // Stop playback when scrolled away, otherwise several videos
            // play at once and audio overlaps.
            player?.pause()
            player = nil
        }
    }
}

struct AvatarView: View {
    let url: String?
    let seed: String
    var size: CGFloat = 40

    var body: some View {
        AsyncImage(url: APIClient.mediaURL(url)) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Theme.navy800
                    Text(String(seed.prefix(1)).uppercased())
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(Theme.cyan300)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.line, lineWidth: 1))
    }
}
