import SwiftUI
import PhotosUI

/// Fixtures and scores per league, plus a live-now strip across all
/// leagues. Data comes from TheSportsDB via the backend's cached proxy.
/// Below that, community talk: the SPORTS category of the normal post feed.
struct SportsView: View {
    @StateObject private var model = SportsViewModel()
    @State private var selectedPost: Post?
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !model.live.isEmpty {
                        SectionHeader("Live now")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(model.live) { event in
                                    EventCard(event: event)
                                        .frame(width: 240)
                                }
                            }
                            .padding(.horizontal, 14)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(model.leagues) { league in
                                Button {
                                    model.selectedLeague = league.key
                                } label: {
                                    Text(league.label)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(model.selectedLeague == league.key
                                                         ? Theme.navy950 : Theme.slate300)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(model.selectedLeague == league.key
                                                    ? Theme.cyan400 : Theme.navy800)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                    }

                    ErrorBanner(message: model.errorMessage)

                    if model.scores?.verified == false {
                        Text("This league's fixture id isn't verified against the provider, so an empty list may not mean the season is over.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    }

                    if model.scores?.noData == true {
                        Text("No fixtures right now.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    }

                    if let upcoming = model.scores?.upcoming, !upcoming.isEmpty {
                        SectionHeader("Upcoming")
                        ForEach(upcoming) { event in
                            EventCard(event: event).padding(.horizontal, 14)
                        }
                    }

                    if let recent = model.scores?.recent, !recent.isEmpty {
                        SectionHeader("Results")
                        ForEach(recent) { event in
                            EventCard(event: event, broadcastUrl: model.scores?.broadcastUrl)
                                .padding(.horizontal, 14)
                        }
                    }

                    SectionHeader("Community talk")
                    composer.padding(.horizontal, 14)

                    ForEach(model.posts) { post in
                        PostCard(post: post, onOpen: { selectedPost = post }) {
                            await model.toggleLike(post)
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .pullToRefresh {
                await model.loadScores()
                await model.loadPosts()
            }
        }
        .navigationDestination(item: $selectedPost) { PostDetailView(post: $0) }
        .navigationTitle("Sports")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .task {
            await model.loadAll()
            await model.loadPosts()
        }
        .onChange(of: model.selectedLeague) { _, _ in Task { await model.loadScores() } }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Talk sports…", text: $model.draft, axis: .vertical)
                .lineLimit(2...5)
                .fieldStyle()

            AttachmentStrip(attachments: $model.attachments, thumbnailSize: 56)

            HStack {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 10,
                             matching: .any(of: [.images, .videos])) {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundStyle(Theme.cyan400)
                }
                Spacer()
                Button(model.isPosting ? "Posting…" : "Post") { Task { await model.submit() } }
                    .disabled(model.isPosting || !model.canPost)
            }
        }
        .padding(14)
        .card()
        .onChange(of: selectedItems) { _, items in
            Task {
                model.attachments += await AttachmentLoader.load(items)
                selectedItems = []
            }
        }
    }
}

struct EventCard: View {
    let event: SportsEvent
    /// League-wide fallback: the provider only gives a broadcaster per league
    /// most of the time, not per fixture.
    var broadcastUrl: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.homeTeam ?? "—")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(event.scoreLine)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.cyan400)
            }
            Text(event.awayTeam ?? "—")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            HStack(spacing: 6) {
                if event.isLive == true {
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.navy950)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Theme.danger)
                        .clipShape(Capsule())
                }
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.slate400)
                    .lineLimit(1)
            }
            if let link = URL(string: event.broadcastUrl ?? broadcastUrl ?? "") {
                Link("Where to watch (official broadcaster)", destination: link)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.cyan300)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .card()
    }

    private var detail: String {
        var parts: [String] = []
        if let league = event.league { parts.append(league) }
        if let date = event.date { parts.append(date) }
        if let time = event.time { parts.append(time) }
        if let venue = event.venue, !venue.isEmpty { parts.append(venue) }
        return parts.joined(separator: " · ")
    }
}
