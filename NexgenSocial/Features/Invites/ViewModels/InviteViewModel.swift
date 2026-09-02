import Foundation

@MainActor
final class InviteViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var invites: [Invite] = []
    @Published private(set) var isCreating = false
    @Published var errorMessage: String?

    func load() async {
        await attempt {
            invites = try await SocialAccountsService.invites()
        }
    }

    /// One invite per address so each is tracked separately, then a mailto
    /// with everyone on BCC — the mail app sends it, we never touch the
    /// contacts. Returns the URL to open, nil if nothing valid was entered.
    func createEmailInvites(_ raw: String) async -> URL? {
        let addresses = raw.split(whereSeparator: { ",; \n\t".contains($0) })
            .map(String.init)
            .filter { $0.contains("@") && $0.contains(".") }
        guard !addresses.isEmpty else {
            errorMessage = "No valid email addresses found. Separate them with commas, spaces or new lines."
            return nil
        }
        isCreating = true
        defer { isCreating = false }
        var firstLink: String?
        do {
            for address in addresses {
                let invite = try await SocialAccountsService.createInvite(channel: "email", contact: address)
                invites.insert(invite, at: 0)
                firstLink = firstLink ?? "\(AppConfig.websiteURL)/signup?ref=\(invite.token)"
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
        var components = URLComponents(string: "mailto:")
        components?.queryItems = [
            URLQueryItem(name: "bcc", value: addresses.joined(separator: ",")),
            URLQueryItem(name: "subject", value: "Join me on NexgenSocial"),
            URLQueryItem(name: "body",
                         value: "Hi,\n\nI'm on NexgenSocial and thought you might like it.\n\n\(firstLink ?? "")\n\nSee you there!"),
        ]
        return components?.url
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
