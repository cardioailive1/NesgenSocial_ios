import SwiftUI

struct FeedView: View {
    @StateObject private var model = FeedViewModel()
    @State private var showComposer = false
    @State private var selectedPost: Post?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ErrorBanner(message: model.errorMessage)

                        ForEach(model.sponsored) { ad in
                            SponsoredCard(ad: ad) { await model.trackAd($0, ad: ad) }
                        }

                        // Not wrapped in a `NavigationLink`: that made the
                        // whole card one button, so swiping between a post's
                        // photos fought the link, tapping a photo navigated
                        // away, and VoiceOver read the entire card as a
                        // single control. The card decides what opens it.
                        ForEach(model.posts) { post in
                            PostCard(post: post, onOpen: { selectedPost = post }) {
                                await model.toggleLike(post)
                            }
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
                .pullToRefresh { await model.load() }
            }
            .navigationDestination(item: $selectedPost) { PostDetailView(post: $0) }
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
