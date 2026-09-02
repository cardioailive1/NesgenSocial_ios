import SwiftUI

extension View {
    /// Pull-to-refresh, with the response cache bypassed for the duration.
    ///
    /// Pulling a list down means "go and ask the server". Answering that from
    /// a cache -- which `refreshable` would, since it calls the same loader as
    /// everything else -- makes the gesture look broken: the spinner runs and
    /// nothing ever changes.
    func pullToRefresh(_ work: @escaping () async -> Void) -> some View {
        refreshable { await ResponseCache.bypassed(work) }
    }
}
