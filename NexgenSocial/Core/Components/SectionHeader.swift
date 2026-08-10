import SwiftUI

/// Small left-aligned heading used by the section screens.
struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.slate400)
            .textCase(.uppercase)
            .padding(.horizontal, 14)
            .padding(.top, 6)
    }
}
