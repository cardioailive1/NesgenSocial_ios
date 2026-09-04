import SwiftUI

struct PostCard: View {
    let post: Post
    /// Opens the post's detail screen. Deliberately not the whole card: the
    /// media carousel swipes and the like button taps, and wrapping all of it
    /// in one navigation button broke both. Nil where there is nowhere to go.
    var onOpen: (() -> Void)?
    let onLike: () async -> Void
    /// Set when the author deletes this post from its detail screen. Hiding
    /// here covers every list that renders a card, instead of teaching each
    /// one to prune its own array.
    // ponytail: the row's spacing stays behind until the list next reloads;
    // give the lists a real remove step if that gap becomes noticeable.
    @State private var isDeleted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    AvatarView(url: post.author?.avatarUrl, seed: post.author?.username ?? "?", size: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.author?.displayName ?? "Unknown")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        HStack(spacing: 4) {
                            Text("@\(post.author?.username ?? "")")
                            if post.editedAt != nil { Text("· edited") }
                        }
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
            }
            // The empty space beside the name is part of the target too,
            // rather than only the glyphs.
            .contentShape(Rectangle())
            .onTapGesture { onOpen?() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(onOpen == nil ? [] : .isButton)

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

                // Tapping the comment count opens the post, which is where
                // the comments are -- the one place a card should navigate.
                Button { onOpen?() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.right")
                        Text("\(post.commentCount ?? 0)")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.slate400)
                }
                .disabled(onOpen == nil)

                Spacer()

                if let reason = post.feedReason {
                    Text(reason)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.slate400)
                }
            }
        }
        .padding(14)
        .card()
        .opacity(isDeleted ? 0 : 1)
        .frame(maxHeight: isDeleted ? 0 : .infinity)
        .clipped()
        .onReceive(NotificationCenter.default.publisher(for: .postDeleted)) { note in
            if note.object as? String == post.id { isDeleted = true }
        }
    }
}
