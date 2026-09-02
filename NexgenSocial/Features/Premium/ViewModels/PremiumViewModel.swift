import Foundation

@MainActor
final class PremiumViewModel: ObservableObject, LoadingViewModel {
    @Published private(set) var tier = "FREE"
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    var isPremium: Bool { tier == "PREMIUM" }

    func load() async {
        await attempt {
            tier = try await PremiumService.currentTier()
        }
    }

    func toggleTier() async {
        isWorking = true
        defer { isWorking = false }
        do {
            tier = try await PremiumService.setPremium(!isPremium)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
