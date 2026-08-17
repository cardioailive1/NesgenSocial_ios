import Foundation

@MainActor
final class CirclesViewModel: ObservableObject {
    @Published private(set) var circles: [AudienceCircle] = []
    @Published var errorMessage: String?

    func load() async {
        do {
            circles = try await CirclesService.all()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class CircleDetailViewModel: ObservableObject {
    @Published private(set) var members: [CircleMembership] = []
    @Published var newUsername = ""
    @Published var errorMessage: String?

    private let circle: AudienceCircle

    init(circle: AudienceCircle) {
        self.circle = circle
        members = circle.members ?? []
    }

    func add() async {
        let username = newUsername.trimmingCharacters(in: .whitespaces)
        newUsername = ""
        do {
            try await CirclesService.addMember(username, to: circle.id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ membership: CircleMembership) async {
        guard let userId = membership.user?.id else { return }
        do {
            try await CirclesService.removeMember(userId, from: circle.id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns whether the circle is gone, so the caller only pops the screen
    /// when it actually was deleted.
    @discardableResult
    func deleteCircle() async -> Bool {
        do {
            try await CirclesService.delete(circle.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// The API has no single-circle GET, so re-read the list and pick this
    /// one out rather than guessing at local state.
    private func refresh() async {
        do {
            let all = try await CirclesService.all()
            members = all.first { $0.id == circle.id }?.members ?? []
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
