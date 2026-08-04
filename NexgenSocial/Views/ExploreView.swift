import SwiftUI

struct ExploreView: View {
    @State private var users: [User] = []
    @State private var jobs: [JobPosting] = []
    @State private var listings: [MarketListing] = []
    @State private var searchText = ""
    @State private var section = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("Section", selection: $section) {
                        Text("People").tag(0)
                        Text("Jobs").tag(1)
                        Text("Market").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            switch section {
                            case 0: ForEach(users) { PeopleRow(user: $0) }
                            case 1: ForEach(jobs) { JobRow(job: $0) }
                            default: ForEach(listings) { ListingRow(listing: $0) }
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                }
            }
            .navigationTitle("Explore")
            .searchable(text: $searchText, prompt: "Search")
            .onChange(of: searchText) { _, _ in Task { await load() } }
            .onChange(of: section) { _, _ in Task { await load() } }
            .task { await load() }
        }
    }

    private func load() async {
        let query = searchText.isEmpty ? "" : "?q=\(searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        switch section {
        case 0:
            users = (try? await APIClient.shared.get("/api/users\(query)", as: UsersResponse.self).users) ?? []
        case 1:
            jobs = (try? await APIClient.shared.get("/api/jobs\(query)", as: JobsResponse.self).jobs) ?? []
        default:
            listings = (try? await APIClient.shared.get("/api/marketplace\(query)", as: ListingsResponse.self).listings) ?? []
        }
    }
}

struct PeopleRow: View {
    let user: User
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
                Task {
                    if isFollowing {
                        _ = try? await APIClient.shared.delete("/api/follows/\(user.username)")
                    } else {
                        _ = try? await APIClient.shared.post("/api/follows/\(user.username)", as: EmptyResponse.self)
                    }
                    isFollowing.toggle()
                }
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(12)
        .card()
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
