import Foundation

/// The load-and-surface-the-error shape every view model in the app was
/// writing out by hand, roughly two dozen times:
///
/// ```swift
/// do   { posts = try await PostsService.feed(); errorMessage = nil }
/// catch { errorMessage = error.localizedDescription }
/// ```
///
/// Deliberately a protocol with one default method rather than a base class:
/// the view models share this one behaviour and nothing else, and a shared
/// superclass would start collecting things that only half of them want.
@MainActor
protocol LoadingViewModel: AnyObject {
    var errorMessage: String? { get set }
}

extension LoadingViewModel {
    /// Runs `work`, clearing the error on success and publishing it on
    /// failure. The result says whether it worked, for the callers that
    /// dismiss a sheet or navigate on success.
    @discardableResult
    func attempt(_ work: () async throws -> Void) async -> Bool {
        do {
            try await work()
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
