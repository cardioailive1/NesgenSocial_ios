import SwiftUI

struct FeedView: View {
    @StateObject private var model = FeedViewModel()
    @State private var creating: CreateStep?
    @State private var selectedPost: Post?
    @State private var tuning = false

    /// What the create sheet is showing right now.
    enum CreateStep: Identifiable {
        case menu
        case composer(CreateOption)

        var id: String {
            switch self {
            case .menu: "menu"
            case .composer(let option): option.rawValue
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ErrorBanner(message: model.errorMessage)

                        ProfileSetupBanner()

                        ForEach(model.sponsored) { ad in
                            SponsoredCard(ad: ad) { await model.trackAd($0, ad: ad) }
                        }

                        // Not wrapped in a `NavigationLink`: that made the
                        // whole card one button, so swiping between a post's
                        // photos fought the link, tapping a photo navigated
                        // away, and VoiceOver read the entire card as a
                        // single control. The card decides what opens it.
                        ForEach(model.posts) { post in
                            PostCard(post: post, onOpen: { selectedPost = post }) {
                                await model.toggleLike(post)
                            }
                        }

                        if model.posts.isEmpty && !model.isLoading {
                            VStack(spacing: 8) {
                                Text("Your feed is empty")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("Follow a few people, or post something yourself.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.slate400)
                            }
                            .padding(30)
                            .frame(maxWidth: .infinity)
                            .card()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .pullToRefresh { await model.load() }
            }
            .navigationDestination(item: $selectedPost) { PostDetailView(post: $0) }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { tuning = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .tint(Theme.cyan400)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { creating = .menu } label: {
                        Image(systemName: "plus")
                    }
                    .tint(Theme.cyan400)
                }
            }
            // One sheet, swapped in place: picking an option from the menu
            // replaces this sheet's content instead of dismissing and
            // re-presenting, which SwiftUI drops.
            .sheet(item: $creating) { step in
                switch step {
                case .menu:
                    CreateSheet { creating = .composer($0) }
                case .composer(let option):
                    composer(for: option)
                }
            }
            .sheet(isPresented: $tuning) {
                FeedTuningView(weights: $model.weights) { await model.saveWeights() }
            }
            .task { await model.load() }
        }
    }

    @ViewBuilder
    private func composer(for option: CreateOption) -> some View {
        switch option {
        case .post:
            ComposerView { await model.load() }
        case .reel:
            // Reels live on their own tab, so the feed has nothing to
            // reload after one is published.
            ReelComposerView { }
        case .meet:
            NewMeetingView { await MeetSession.shared.open($0) }
        case .live:
            StartLiveView()
        case .group:
            NewGroupView { }
        case .circle:
            NewCircleView { }
        case .newsroom:
            NewNewsroomView { }
        case .ad:
            NewAdView { }
        }
    }
}

/// The same three knobs the web feed exposes. The server clamps to 0...1 and
/// re-ranks on the next feed fetch, so applying reloads.
struct FeedTuningView: View {
    @Binding var weights: FeedWeights
    let onApply: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    slider("Recency", value: $weights.recency)
                    slider("Engagement", value: $weights.engagement)
                    slider("Diversity", value: $weights.diversity)
                } footer: {
                    Text("Recency favors newer posts. Engagement favors more-liked and commented posts. Diversity spreads out posts from the same author instead of letting one voice dominate the top.")
                }
            }
            .navigationTitle("Tune my feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        saving = true
                        Task {
                            await onApply()
                            saving = false
                            dismiss()
                        }
                    }
                    .disabled(saving)
                }
            }
        }
    }

    private func slider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.system(size: 13))
            Slider(value: value, in: 0...1, step: 0.05)
                .tint(Theme.cyan400)
        }
    }
}


/// "Finish setting up your profile", the same prompt the web feed shows.
/// Dismissible for a week rather than forever: a half-finished profile is
/// worth mentioning again eventually, just not tomorrow.
struct ProfileSetupBanner: View {
    private static let snoozeKey = "profileBannerSnoozedUntil"

    @State private var status: ProfileStatus?

    var body: some View {
        Group {
            if let status, !status.isComplete, !status.missing.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Finish setting up your profile")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer(minLength: 8)
                        Text("\(status.completeness)% complete")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.cyan300)
                        Button {
                            snooze()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.slate400)
                        }
                        .accessibilityLabel("Remind me later")
                    }

                    ProgressView(value: Double(status.completeness), total: 100)
                        .tint(Theme.cyan400)

                    ForEach(status.missing.prefix(3)) { gap in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(gap.label)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(.white)
                            if let hint = gap.hint {
                                Text(hint)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Theme.slate400)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
                .card()
            }
        }
        .task { await load() }
    }

    private func load() async {
        let snoozedUntil = UserDefaults.standard.double(forKey: Self.snoozeKey)
        guard Date().timeIntervalSince1970 >= snoozedUntil else { return }
        status = try? await FriendsService.profileStatus()
    }

    private func snooze() {
        UserDefaults.standard.set(Date().addingTimeInterval(7 * 24 * 3600).timeIntervalSince1970,
                                  forKey: Self.snoozeKey)
        status = nil
    }
}
