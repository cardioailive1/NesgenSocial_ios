import Foundation

@MainActor
final class ConnectionsViewModel: ObservableObject {
    @Published private(set) var accounts: [SocialAccount] = []
    @Published private(set) var working: String?
    @Published var namingProvider: String?
    @Published var displayName = ""
    @Published var errorMessage: String?

    func account(for provider: String) -> SocialAccount? {
        accounts.first { $0.provider == provider }
    }

    func load() async {
        do {
            accounts = try await SocialAccountsService.accounts()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connect(_ provider: String) async {
        working = provider
        defer { working = nil }
        namingProvider = nil
        do {
            try await SocialAccountsService.connect(provider, displayName: displayName)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnect(_ provider: String) async {
        working = provider
        defer { working = nil }
        do {
            try await SocialAccountsService.disconnect(provider)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
