import Foundation

@MainActor
final class InviteViewModel: ObservableObject {
    @Published private(set) var invites: [Invite] = []
    @Published private(set) var isCreating = false
    @Published var errorMessage: String?

    func load() async {
        do {
            invites = try await SocialAccountsService.invites()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns the new invite so the view can open the share sheet on it.
    func create() async -> Invite? {
        isCreating = true
        defer { isCreating = false }
        do {
            let invite = try await SocialAccountsService.createInvite()
            invites.insert(invite, at: 0)
            return invite
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
