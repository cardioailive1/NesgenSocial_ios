import SwiftUI

struct ExploreView: View {
    @StateObject private var model = ExploreViewModel()

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            VStack(spacing: 0) {
                Picker("Section", selection: $model.section) {
                    ForEach(ExploreViewModel.Section.allCases, id: \.self) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

                ErrorBanner(message: model.errorMessage)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        switch model.section {
                        case .people: ForEach(model.users) { PeopleRow(user: $0, model: model) }
                        case .jobs:   ForEach(model.jobs) { JobRow(job: $0) }
                        case .market: ForEach(model.listings) { ListingRow(listing: $0) }
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
        }
        .navigationTitle("Explore")
        .searchable(text: $model.searchText, prompt: "Search")
        .onChange(of: model.searchText) { _, _ in Task { await model.load() } }
        .onChange(of: model.section) { _, _ in Task { await model.load() } }
        .task { await model.load() }
    }
}

struct PeopleRow: View {
    let user: User
    @ObservedObject var model: ExploreViewModel
    @State private var isFollowing = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatarUrl, seed: user.username, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text("@\(user.username)")
                    .font(.system(size: 12)).foregroundStyle(Theme.slate400)
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio).font(.system(size: 12)).foregroundStyle(Theme.slate300).lineLimit(1)
                }
            }
            Spacer()
            Button(isFollowing ? "Following" : "Follow") {
                Task { await toggleFollow() }
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(12)
        .card()
    }

    /// Flips first and puts it back if the call fails, like the like button.
    private func toggleFollow() async {
        isFollowing.toggle()
        do {
            try await DiscoveryService.setFollowing(isFollowing, username: user.username)
        } catch {
            isFollowing.toggle()
            model.errorMessage = error.localizedDescription
        }
    }
}

struct JobRow: View {
    let job: JobPosting

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(job.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Text(job.companyName).font(.system(size: 13)).foregroundStyle(Theme.slate300)
            HStack(spacing: 8) {
                if let location = job.location { Text(location) }
                if let arrangement = job.arrangement { Text("· \(arrangement.capitalized)") }
            }
            .font(.system(size: 12)).foregroundStyle(Theme.slate400)

            if let salary = job.salaryText {
                Text(salary).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.cyan300)
            } else {
                Text("Salary not disclosed").font(.system(size: 11)).foregroundStyle(Theme.slate400)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card()
    }
}

struct ListingRow: View {
    let listing: MarketListing

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let media = listing.media, !media.isEmpty {
                MediaCarousel(items: media)
            }
            HStack {
                Text(listing.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text(listing.priceText).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.cyan300)
            }
            Text(listing.description)
                .font(.system(size: 12)).foregroundStyle(Theme.slate400).lineLimit(2)
        }
        .padding(12)
        .card()
    }
}
