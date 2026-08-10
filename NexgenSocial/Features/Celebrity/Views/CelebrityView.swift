import SwiftUI
import PhotosUI

/// Community celebrity talk. There's no licensed entertainment wire behind
/// this — that needs a paid data provider — so it's whatever people post,
/// and the screen says as much rather than implying a feed it doesn't have.
struct CelebrityView: View {
    @StateObject private var model = CelebrityViewModel()
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 12) {
                    Text("Community-posted, public and searchable. There's no licensed celebrity wire here.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.slate400)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    composer

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                    }

                    ForEach(model.posts) { post in
                        NavigationLink {
                            PostDetailView(post: post)
                        } label: {
                            PostCard(post: post) { await model.toggleLike(post) }
                        }
                        .buttonStyle(.plain)
                    }

                    if model.posts.isEmpty {
                        Text("No posts yet — be the first.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .card()
                    }
                }
                .padding(14)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle("Celebrity")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .task { await model.load() }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Share something…", text: $model.draft, axis: .vertical)
                .lineLimit(2...5)
                .fieldStyle()

            AttachmentStrip(attachments: $model.attachments, thumbnailSize: 56)

            HStack {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 10, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundStyle(Theme.cyan400)
                }
                Spacer()
                Button(model.isPosting ? "Posting…" : "Post") { Task { await model.submit() } }
                    .disabled(model.isPosting || !model.canPost)
            }
        }
        .padding(14)
        .card()
        .onChange(of: selectedItems) { _, items in
            Task {
                model.attachments += await AttachmentLoader.load(items)
                selectedItems = []
            }
        }
    }
}
