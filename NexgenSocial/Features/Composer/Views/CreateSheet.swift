import SwiftUI

/// Everything you can create, in one sheet. The feed's `+` opens this and
/// then swaps the same sheet's content for whichever composer you picked --
/// dismissing one sheet to present another drops the second presentation.
enum CreateOption: String, Identifiable, CaseIterable {
    case reel, post, meet, live, group, circle, newsroom, ad

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reel: "Reel"
        case .post: "Post"
        case .meet: "Meet"
        case .live: "Live"
        case .group: "Group"
        case .circle: "Circle"
        case .newsroom: "Newsroom"
        case .ad: "Ad"
        }
    }

    var subtitle: String {
        switch self {
        case .reel: "Share a short video"
        case .post: "Share a photo or update"
        case .meet: "Start a video meeting"
        case .live: "Go live right now"
        case .group: "Build a space for members"
        case .circle: "Gather your close contacts"
        case .newsroom: "Publish news coverage"
        case .ad: "Promote to a wider audience"
        }
    }

    var icon: String {
        switch self {
        case .reel: "play.rectangle"
        case .post: "square.grid.3x3"
        case .meet: "video"
        case .live: "dot.radiowaves.left.and.right"
        case .group: "person.3"
        case .circle: "circle.hexagongrid"
        case .newsroom: "newspaper"
        case .ad: "megaphone"
        }
    }
}

struct CreateSheet: View {
    let onPick: (CreateOption) -> Void

    /// The sheet is only as tall as its rows: header, then one row each.
    static var height: CGFloat { 58 + CGFloat(CreateOption.allCases.count) * 68 + 24 }

    var body: some View {
        VStack(spacing: 0) {
            Text("Create")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(height: 58)

            ForEach(CreateOption.allCases) { option in
                Button { onPick(option) } label: {
                    HStack(spacing: 16) {
                        Image(systemName: option.icon)
                            .font(.system(size: 21, weight: .light))
                            .foregroundStyle(.white)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                            Text(option.subtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(height: 68)
                    .padding(.leading, 20)
                    .padding(.trailing, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    if option != CreateOption.allCases.last {
                        Rectangle()
                            .fill(Theme.line)
                            .frame(height: 0.5)
                            .padding(.leading, 64)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(Self.height)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.navy900)
    }
}
