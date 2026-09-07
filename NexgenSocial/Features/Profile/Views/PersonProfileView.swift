import SwiftUI

/// Somebody else's profile, laid out the way people expect from every other
/// social app: identity and counts, the relationship buttons, then their
/// posts as a grid.
///
/// It takes a username rather than a `User` because it is opened from a
/// follower row, a post author, a reel, a conversation header — each of which
/// carries a different and usually partial user. The username is the one
/// thing they all have, and the server fills in the rest.
struct PersonProfileView: View {
    let username: String

    @EnvironmentObject private var session: AuthSession
    @StateObject private var model = ProfileViewModel()

    @State private var tab: ProfileTab = .posts
    @State private var selectedPost: Post?
    @State private var playingReel: Reel?
    @State private var openingConversation = false
    @State private var conversation: Conversation?

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            if model.loadFailed {
                VStack(spacing: 6) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 30)).foregroundStyle(Theme.slate400)
                    Text("Profile unavailable")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Text(model.errorMessage ?? "This account may have been removed.")
                        .font(.system(size: 13)).foregroundStyle(Theme.slate400)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        header
                        ProfileTabStrip(selection: $tab)
                        content
                    }
                    .padding(.bottom, 24)
                }
                .pullToRefresh { await model.load(username: username) }
            }
        }
        .navigationTitle("@\(username)")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .navigationDestination(item: $selectedPost) { PostDetailView(post: $0) }
        .navigationDestination(item: $conversation) { ConversationView(conversation: $0) }
        .fullScreenCover(item: $playingReel) { reel in
            SingleReelView(reel: reel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .reelDeleted)) { note in
            if let id = note.object as? String { model.removeDeletedReel(id) }
        }
        .task { await model.load(username: username) }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 20) {
                AvatarView(url: model.user?.avatarUrl, seed: username, size: 88)

                HStack(spacing: 0) {
                    StatItem(value: model.postCount, label: "posts")
                    NavigationLink {
                        FollowListView(username: username, direction: .followers)
                    } label: {
                        StatItem(value: model.stats?.followerCount ?? 0, label: "followers")
                    }
                    NavigationLink {
                        FollowListView(username: username, direction: .following)
                    } label: {
                        StatItem(value: model.stats?.followingCount ?? 0, label: "following")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(model.user?.displayName ?? "")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                if let bio = model.user?.bio, !bio.isEmpty {
                    Text(bio).font(.system(size: 13.5)).foregroundStyle(Theme.slate300)
                }
                if let occupation = model.user?.occupation, !occupation.isEmpty {
                    Text(occupation).font(.system(size: 13)).foregroundStyle(Theme.slate400)
                }
            }

            buttons
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Button {
                Task { await model.toggleFollow(username: username) }
            } label: {
                buttonLabel(model.isFollowing ? "Following" : "Follow",
                            filled: !model.isFollowing)
            }

            Button {
                Task { await openConversation() }
            } label: {
                buttonLabel(openingConversation ? "Opening…" : "Message", filled: false)
            }
            .disabled(openingConversation)

            Button {
                Task { await model.sendFriendRequest(username: username) }
            } label: {
                buttonLabel(connectTitle, filled: false)
            }
            .disabled(model.friendStatus != "NONE")
        }
    }

    /// `friendStatus` is the server's own enum, plus "NONE" when there has
    /// never been a request either way.
    private var connectTitle: String {
        switch model.friendStatus {
        case "ACCEPTED": return "Friends"
        case "PENDING":  return "Requested"
        default:         return "Connect"
        }
    }

    private func buttonLabel(_ title: String, filled: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(filled ? Theme.navy950 : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(filled ? Theme.cyan400 : Theme.navy800,
                        in: RoundedRectangle(cornerRadius: 9))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .posts:
            if model.isLoading && model.posts.isEmpty {
                ProgressView().tint(Theme.cyan400).padding(.top, 40)
            } else if model.posts.isEmpty {
                EmptyTab(icon: "camera", title: "No posts yet",
                         detail: "Posts they share will show up here.")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(model.posts) { post in
                        PostCard(post: post, onOpen: { selectedPost = post }) {
                            await model.toggleLike(post)
                        }
                        .padding(.horizontal, 14)
                    }
                }
            }
        case .reels:
            if model.reels.isEmpty {
                EmptyTab(icon: "play.rectangle", title: "No reels yet",
                         detail: "Reels they post will show up here.")
            } else {
                ReelGrid(reels: model.reels) { playingReel = $0 }
            }
        }
    }

    private func openConversation() async {
        openingConversation = true
        defer { openingConversation = false }
        do {
            conversation = try await MessagesService.conversation(with: username)
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Shared pieces

enum ProfileTab: String, CaseIterable, Identifiable {
    case posts, reels
    var id: String { rawValue }

    var icon: String { self == .posts ? "square.grid.3x3" : "play.rectangle" }
}

/// The two-icon strip under a profile header, matching how every grid-based
/// profile switches between its tabs.
struct ProfileTabStrip: View {
    @Binding var selection: ProfileTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(selection == tab ? .white : Theme.slate400)
                        Rectangle()
                            .fill(selection == tab ? Color.white : .clear)
                            .frame(height: 1.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 4)
    }
}

struct StatItem: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.slate400)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EmptyTab: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 30)).foregroundStyle(Theme.slate400)
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Text(detail).font(.system(size: 13)).foregroundStyle(Theme.slate400)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal, 30)
    }
}

/// One reel, full screen, opened from a profile's reels grid. `ReelCell`
/// carries the whole player; it is `ReelsView` that is tied to the tab bar,
/// not the cell.
struct SingleReelView: View {
    let reel: Reel

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AuthSession
    @StateObject private var model = ReelsViewModel()
    @State private var commenting = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            ReelCell(reel: reel,
                     isActive: true,
                     onDelete: reel.author?.username == session.currentUser?.username
                        ? {
                            await model.delete(reel)
                            dismiss()
                        } : nil) {
                await model.toggleLike(reel)
            } onWatched: { seconds, completed in
                await model.reportView(reel, watchedSec: seconds, completed: completed)
            } onComment: {
                commenting = true
            }
            .ignoresSafeArea()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
            }
            .padding(.top, 8)
        }
        .sheet(isPresented: $commenting) {
            ReelCommentsSheet(reel: reel) { }
        }
    }
}
