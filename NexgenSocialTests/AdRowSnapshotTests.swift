import XCTest
import SwiftUI
@testable import NexgenSocial

/// Renders `AdRow` to a PNG so its layout can actually be looked at.
///
/// The ad manager on a real account shows "No campaigns yet" until someone
/// buys a campaign, so walking the app in the simulator never puts a row on
/// screen. `ImageRenderer` draws the same view with fixture data instead,
/// and costs nobody $50.
@MainActor
final class AdRowSnapshotTests: XCTestCase {

    func testRenderAdRowStates() throws {
        let states: [(String, Ad)] = [
            ("live", ad(headline: "Summer sale — 30% off everything",
                        category: "retail", budgetCents: 5_000, durationDays: 1, active: true)),
            ("awaiting-payment", ad(headline: "Hiring two backend engineers",
                                    category: "jobs", budgetCents: 12_500, durationDays: 7,
                                    active: false, paymentStatus: "pending")),
            ("draft-no-fields", ad(headline: "Untitled campaign")),
            ("long-headline", ad(headline: String(repeating: "A very long headline ", count: 5),
                                 category: "community", budgetCents: 999_999, durationDays: 30,
                                 active: true))
        ]

        let stack = VStack(spacing: 10) {
            ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                AdRow(ad: state.1)
            }
        }
        .padding(16)
        .background(Theme.navy950)
        .frame(width: 402)

        let renderer = ImageRenderer(content: stack)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, "ImageRenderer produced nothing")
        let png = try XCTUnwrap(image.pngData())

        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = "ad-row-states"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertGreaterThan(image.size.height, 0)
    }

    private func ad(headline: String,
                    category: String? = nil,
                    budgetCents: Int? = nil,
                    durationDays: Int? = nil,
                    active: Bool? = nil,
                    paymentStatus: String? = nil) -> Ad {
        var fields = ["\"id\":\"a1\"", "\"headline\":\(quoted(headline))"]
        if let category { fields.append("\"category\":\(quoted(category))") }
        if let budgetCents { fields.append("\"budgetCents\":\(budgetCents)") }
        if let durationDays { fields.append("\"durationDays\":\(durationDays)") }
        if let active { fields.append("\"active\":\(active)") }
        if let paymentStatus { fields.append("\"paymentStatus\":\(quoted(paymentStatus))") }
        let json = "{\(fields.joined(separator: ","))}"
        return try! JSONDecoder().decode(Ad.self, from: Data(json.utf8))
    }

    private func quoted(_ value: String) -> String {
        String(data: try! JSONEncoder().encode(value), encoding: .utf8)!
    }
}
