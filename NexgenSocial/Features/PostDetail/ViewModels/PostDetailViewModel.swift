import Foundation

@MainActor
final class PostDetailViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var comments: [Comment] = []
    @Published private(set) var notes: [ContextNote] = []
    @Published var draft = ""
    @Published var noteDraft = ""
    @Published private(set) var isSending = false
    @Published var errorMessage: String?

    let post: Post

    init(post: Post) {
        self.post = post
    }

    /// Comments and notes are independent, so they're fetched together rather
    /// than one after the other.
    func load() async {
        // `async let` can't cross a closure boundary, so the pair is started
        // inside `attempt` rather than around it.
        await attempt { [post] in
            async let loadedComments = PostsService.comments(for: post.id)
            async let loadedNotes = PostsService.contextNotes(for: post.id)
            comments = try await loadedComments
            notes = try await loadedNotes
        }
    }

    func sendComment() async {
        guard !draft.isEmpty, !isSending else { return }
        isSending = true
        defer { isSending = false }
        let text = draft
        draft = ""
        do {
            try await PostsService.addComment(text, to: post.id)
            await load()
        } catch {
            draft = text  // restore so the comment isn't lost
            errorMessage = error.localizedDescription
        }
    }

    func addContextNote() async {
        let text = noteDraft
        guard !text.isEmpty else { return }
        noteDraft = ""
        do {
            try await PostsService.addContextNote(text, to: post.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func vote(_ note: ContextNote, value: Int) async {
        do {
            try await PostsService.voteContextNote(note.id, value: value)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
