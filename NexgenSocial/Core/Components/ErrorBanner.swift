import SwiftUI

/// One line of red text for a failed load or a failed tap, so "we couldn't
/// reach the server" stops looking like "there's nothing here".
///
/// Draws nothing when there's no message, so it can sit unconditionally in a
/// stack.
struct ErrorBanner: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                // The UI walks assert on this rather than on the message,
                // which is whatever the server said.
                .accessibilityIdentifier("error-banner")
        }
    }
}
