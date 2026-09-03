import Foundation

@MainActor
final class PostDetailViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var comments: [Comment] = []
    @Published private(set) var notes: [ContextNote] = []
    @Published var draft = ""
    @Published var noteDraft = ""
    @Published private(set) var isSending = false
    @Published var errorMessage: String?
    /// The body being edited, and the earlier versions once they're fetched.
    @Published var editDraft = ""
    @Published private(set) var revisions: [PostRevision]?

    /// Not `let`: an edit replaces it with what the server returns, so the
    /// card above the comments shows the new body without a reload.
    @Published private(set) var post: Post

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

    /// Sends the edit and adopts the server's copy of the post — it carries
    /// the `editedAt` stamp the "edited" marker and the history button read.
    func saveEdit() async -> Bool {
        let text = editDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != post.body else { return false }
        do {
            post = try await PostsService.edit(post.id, body: text)
            revisions = nil  // stale now: this edit added a version
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func loadHistory() async {
        do {
            revisions = try await PostsService.history(for: post.id)
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
