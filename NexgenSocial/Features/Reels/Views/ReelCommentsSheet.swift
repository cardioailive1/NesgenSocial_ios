import SwiftUI

/// Comments on a reel. Deliberately thin: the rows are the same `CommentRow`
/// the post screen uses, and the list is short-lived enough that it holds its
/// own state instead of getting a view model of its own.
struct ReelCommentsSheet: View {
    let reel: Reel
    /// Lets the reel feed bump the count under the bubble without refetching.
    let onPosted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comments: [Comment] = []
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if comments.isEmpty {
                                Text("No comments yet.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.slate400)
                                    .padding(.horizontal, 14)
                            }
                            ForEach(comments) { comment in
                                CommentRow(comment: comment)
                                    .padding(.horizontal, 14)
                            }
                            ErrorBanner(message: errorMessage)
                        }
                        .padding(.vertical, 12)
                    }

                    HStack(spacing: 8) {
                        TextField("Add a comment…", text: $draft, axis: .vertical)
                            .lineLimit(1...4)
                            .fieldStyle()
                        Button {
                            Task { await send() }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(draft.isEmpty ? Theme.slate400 : Theme.cyan400)
                        }
                        .disabled(draft.isEmpty || isSending)
                    }
                    .padding(12)
                    .background(Theme.navy900)
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .tint(Theme.cyan400)
        }
        .task { await load() }
    }

    private func load() async {
        do {
            comments = try await ReelsService.comments(for: reel.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The posted comment comes back from the server, so it goes straight onto
    /// the end of the list rather than costing a second round trip.
    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        isSending = true
        defer { isSending = false }
        draft = ""
        do {
            comments.append(try await ReelsService.addComment(text, to: reel.id))
            onPosted()
            errorMessage = nil
        } catch {
            draft = text  // restore so the comment isn't lost
            errorMessage = error.localizedDescription
        }
    }
}
