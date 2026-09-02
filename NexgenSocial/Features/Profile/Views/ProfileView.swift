import SwiftUI
import PhotosUI
import UIKit

/// The signed-in person's own profile, laid out the way people expect from
/// every other social app: identity and counts up top, then their posts.
/// Settings moved behind the toolbar button so the first screen is about the
/// person, not about preferences.
struct ProfileView: View {
    @EnvironmentObject var session: AuthSession
    @StateObject private var model = ProfileViewModel()

    @State private var showSettings = false
    @State private var avatarItem: PhotosPickerItem?
    @State private var selectedPost: Post?

    private var user: User? { session.currentUser }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 14) {
                        header
                        content
                    }
                    .padding(.bottom, 24)
                }
                .pullToRefresh { await model.load(username: user?.username ?? "") }
            }
            .navigationDestination(item: $selectedPost) { PostDetailView(post: $0) }
            .navigationTitle(user?.username ?? "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "line.3.horizontal").foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { ProfileSettingsView().environmentObject(session) }
            .task { await model.load(username: user?.username ?? "") }
            .onChange(of: avatarItem) { _, item in
                guard let item else { return }
                Task { await uploadAvatar(item) }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 20) {
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarView(url: user?.avatarUrl, seed: user?.username ?? "?", size: 88)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.navy950)
                            .padding(6)
                            .background(Theme.cyan400, in: Circle())
                            .overlay(Circle().stroke(Theme.navy950, lineWidth: 2))
                    }
                }

                HStack(spacing: 0) {
                    StatItem(value: model.postCount, label: "posts")
                    StatItem(value: model.stats?.followerCount ?? 0, label: "followers")
                    StatItem(value: model.stats?.followingCount ?? 0, label: "following")
                    StatItem(value: model.stats?.friendCount ?? 0, label: "friends")
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(user?.displayName ?? "")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                if let bio = user?.bio, !bio.isEmpty {
                    Text(bio).font(.system(size: 13.5)).foregroundStyle(Theme.slate300)
                }
                if let occupation = user?.occupation, !occupation.isEmpty {
                    Text(occupation).font(.system(size: 13)).foregroundStyle(Theme.slate400)
                }
            }

            NavigationLink { ProfileSetupView() } label: {
                Text("Edit profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Theme.navy800, in: RoundedRectangle(cornerRadius: 9))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    // MARK: - Posts

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.posts.isEmpty {
            ProgressView().tint(Theme.cyan400).padding(.top, 40)
        } else if model.posts.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "camera").font(.system(size: 30)).foregroundStyle(Theme.slate400)
                Text("No posts yet").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(model.errorMessage ?? "Posts you share will show up here.")
                    .font(.system(size: 13)).foregroundStyle(Theme.slate400)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.horizontal, 30)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(model.posts) { post in
                    PostCard(post: post, onOpen: { selectedPost = post }, onLike: {})
                        .padding(.horizontal, 14)
                }
            }
        }
    }

    private func uploadAvatar(_ item: PhotosPickerItem) async {
        defer { avatarItem = nil }
        guard let picked = await AttachmentLoader.load([item]).first else { return }
        if let updated = try? await ProfileService.uploadAvatar(picked) {
            session.currentUser = updated
        }
    }
}

// MARK: - Pieces

private struct StatItem: View {
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
