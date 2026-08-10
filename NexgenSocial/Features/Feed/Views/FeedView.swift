import SwiftUI

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

                        ForEach(model.sponsored) { ad in
                            SponsoredCard(ad: ad)
                        }

                        ForEach(model.posts) { post in
                            NavigationLink {
                                PostDetailView(post: post)
                            } label: {
                                PostCard(post: post) { await model.toggleLike(post) }
                            }
                            .buttonStyle(.plain)
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
