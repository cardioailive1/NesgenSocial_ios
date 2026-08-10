import SwiftUI

/// One campaign in the manager list: headline, spend, and whether it is
/// actually running — an unpaid campaign looks identical otherwise, so the
/// status is always shown.
struct AdRow: View {
    let ad: Ad

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ad.headline)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(ad.active == true ? "LIVE" : (ad.paymentStatus ?? "DRAFT").uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ad.active == true ? Theme.navy950 : Theme.slate300)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(ad.active == true ? Theme.cyan400 : Theme.navy800)
                .clipShape(Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .card()
    }

    private var subtitle: String {
        var parts: [String] = []
        if let category = ad.category { parts.append(category.capitalized) }
        if let budget = ad.budgetCents { parts.append(money(budget)) }
        if let days = ad.durationDays { parts.append("\(days) days") }
        return parts.joined(separator: " · ")
    }
}
