import Foundation

@MainActor
final class PremiumViewModel: ObservableObject {
    @Published private(set) var tier = "FREE"
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    var isPremium: Bool { tier == "PREMIUM" }

    func load() async {
        do {
            tier = try await PremiumService.currentTier()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
