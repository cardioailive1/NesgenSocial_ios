import SwiftUI
import PhotosUI

/// Political pages. Every page names the organization responsible for it —
/// that disclosure is enforced server-side, and shown here.
struct PoliticalView: View {
    @StateObject private var model = PoliticalViewModel()
    @State private var showCreate = false

    /// These strings are the server's PoliticalPageType enum. Anything not in
    /// it filters to nothing, so they stay spelled exactly as the schema has them.
    private let types = [("", "All"), ("CANDIDATE", "Candidate"), ("PARTY", "Party"),
                         ("ISSUE", "Issue"), ("CAMPAIGN", "Campaign"),
                         ("ORGANIZATION", "Organization")]

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    // Six types don't fit a segmented control at phone width,
                    // so they scroll as chips like the sports leagues do.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(types, id: \.0) { type in
                                Button { model.typeFilter = type.0 } label: {
                                    Text(type.1)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(model.typeFilter == type.0
                                                         ? Theme.navy950 : Theme.slate300)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(model.typeFilter == type.0
                                                    ? Theme.cyan400 : Theme.navy800)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                    }

                    ErrorBanner(message: model.errorMessage)

                    if model.pages.isEmpty {
                        Text("No pages here yet.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    }

                    ForEach(model.pages) { page in
                        NavigationLink { PoliticalPageView(page: page) } label: {
                            PoliticalPageCard(page: page)
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .pullToRefresh { await model.load() }
        }
        .navigationTitle("Political")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { PoliticalArchiveView() } label: {
                    Image(systemName: "archivebox")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .tint(Theme.cyan400)
        .task { await model.load() }
        .onChange(of: model.typeFilter) { _, _ in Task { await model.load() } }
        .sheet(isPresented: $showCreate) {
            CreatePoliticalPageView { await model.load() }
        }
    }
}

/// Every political ad ever run, including ended ones. Search hits the
/// headline, body and who paid for it.
struct PoliticalArchiveView: View {
    @StateObject private var model = PoliticalArchiveViewModel()

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    TextField("Search ads, or who paid for them", text: $model.query)
                        .autocorrectionDisabled()
                        .fieldStyle()
                        .padding(.horizontal, 14)
                        .onSubmit { Task { await model.load() } }

                    ErrorBanner(message: model.errorMessage)

                    if model.ads.isEmpty {
                        Text("No ads in the archive match that.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    }

                    ForEach(model.ads) { ad in
                        PoliticalAdCard(ad: ad).padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .pullToRefresh { await model.load() }
        }
        .navigationTitle("Ad archive")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .task { await model.load() }
    }
}

struct PoliticalAdCard: View {
    let ad: PoliticalAd

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(ad.active == true ? "RUNNING" : "ENDED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.navy950)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(ad.active == true ? Theme.cyan400 : Theme.slate400)
                    .clipShape(Capsule())
                Text(ad.page?.name ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
            }
            if let headline = ad.headline {
                Text(headline)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            if let body = ad.body {
                Text(body)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.slate300)
            }
            // The disclosure line: who paid, how much, where it ran.
            Text("Paid for by \(ad.paidForBy ?? "undisclosed")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.slate300)
            Text(details)
                .font(.system(size: 11))
                .foregroundStyle(Theme.slate400)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .card()
    }

    private var details: String {
        var parts: [String] = []
        if let cents = ad.spendCents {
            parts.append(String(format: "$%.2f spent", Double(cents) / 100))
        }
        if let region = ad.region, !region.isEmpty { parts.append(region) }
        if let impressions = ad.impressions { parts.append("\(impressions) impressions") }
        if let clicks = ad.clicks { parts.append("\(clicks) clicks") }
        if let started = ad.startedAt { parts.append("from \(started.prefix(10))") }
        if let ended = ad.endedAt { parts.append("to \(ended.prefix(10))") }
        return parts.joined(separator: " · ")
    }
}

struct CreatePoliticalPageView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = CreatePoliticalPageViewModel()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [PhotosPickerItem] = []
    let onCreated: () async -> Void

    private let types = ["CANDIDATE", "PARTY", "ISSUE", "CAMPAIGN", "ORGANIZATION"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Political pages must name the organization responsible for them. That disclosure is shown on every page and ad.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.slate400)

                        Picker("Type", selection: $model.type) {
                            ForEach(types, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.cyan300)

                        TextField("Page name", text: $model.name).fieldStyle()
                        TextField("Responsible organization", text: $model.organization).fieldStyle()
                        TextField("What this page is about", text: $model.pageDescription, axis: .vertical)
                            .lineLimit(2...5)
                            .fieldStyle()
                        TextField("Website (optional)", text: $model.websiteUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .fieldStyle()
                        TextField("Region (optional)", text: $model.region).fieldStyle()

                        AttachmentStrip(attachments: $model.avatar, thumbnailSize: 56)
                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 1, matching: .images) {
                            Text("Choose a page picture")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.cyan300)
                        }

                        AttachmentStrip(attachments: $model.media, thumbnailSize: 56)
                        PhotosPicker(selection: $mediaItems, maxSelectionCount: 10,
                                     matching: .any(of: [.images, .videos])) {
                            Text("Add page photos or videos")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.cyan300)
                        }

                        ErrorBanner(message: model.errorMessage)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Create page")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.cyan400)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.isSaving ? "Creating…" : "Create") { Task { await save() } }
                        .disabled(model.isSaving || !model.canSave)
                }
            }
            .onChange(of: selectedItems) { _, items in
                Task {
                    model.avatar = await AttachmentLoader.load(items)
                    selectedItems = []
                }
            }
            .onChange(of: mediaItems) { _, items in
                Task {
                    model.media += await AttachmentLoader.load(items)
                    mediaItems = []
                }
            }
        }
    }

    private func save() async {
        guard await model.save() else { return }
        dismiss()
        await onCreated()
    }
}

struct PoliticalPageCard: View {
    let page: PoliticalPage

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: page.avatarUrl, seed: page.id, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(page.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    if page.verified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.cyan400)
                    }
                }
                // The responsible organization is the whole point of the
                // disclosure, so it is never truncated away.
                Text("Paid for / run by \(page.organization ?? "undisclosed")")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
                Text("\(page.followerCount ?? 0) followers · \(page.postCount ?? 0) posts · \(page.media?.count ?? 0) media")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.slate400)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .card()
    }
}

struct PoliticalPageView: View {
    let page: PoliticalPage

    @EnvironmentObject private var session: AuthSession
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var runningAd = false
    @StateObject private var model: PoliticalPageViewModel

    init(page: PoliticalPage) {
        self.page = page
        _model = StateObject(wrappedValue: PoliticalPageViewModel(page: page))
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Run by \(page.organization ?? "undisclosed")")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.slate300)
                            if let region = page.region {
                                Text(region)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.slate400)
                            }
                        }
                        Spacer(minLength: 0)
                        Button(model.isFollowing ? "Following" : "Follow") {
                            Task { await model.toggleFollow() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(model.isFollowing ? Theme.navy800 : Theme.cyan400)
                        .font(.system(size: 13))
                    }
                    .padding(.horizontal, 14)

                    if let media = page.media, !media.isEmpty {
                        MediaCarousel(items: media)
                            .padding(.horizontal, 14)
                    }

                    if let url = page.websiteUrl, let link = URL(string: url) {
                        Link("Website", destination: link)
                            .font(.system(size: 13))
                            .padding(.horizontal, 14)
                    }

                    // Only the page's owner can post to it, and the server
                    // enforces that too — showing the composer to anyone else
                    // would just be a 403 waiting to happen.
                    if page.owner?.username == session.currentUser?.username {
                        composer.padding(.horizontal, 14)

                        Button("Run an ad from this page") { runningAd = true }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.cyan300)
                            .padding(.horizontal, 14)
                    }

                    SectionHeader("Posts")
                    if model.errorMessage != nil {
                        ErrorBanner(message: model.errorMessage)
                    } else if model.posts.isEmpty {
                        Text("No posts yet.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    }
                    ForEach(model.posts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(post.body)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.slate300)
                            if let media = post.media, !media.isEmpty {
                                MediaCarousel(items: media)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .card()
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .pullToRefresh { await model.load() }
        }
        .navigationTitle(page.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .sheet(isPresented: $runningAd) {
            RunPoliticalAdView(page: page)
        }
        .task { await model.load() }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Post to this page…", text: $model.draft, axis: .vertical)
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


/// Submitting a political ad to the archive, from a page you own. Every field
/// the server requires is required here, "Paid for by" included: it is the
/// disclosure the archive exists to preserve.
struct RunPoliticalAdView: View {
    let page: PoliticalPage

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = RunPoliticalAdViewModel()
    @State private var pickedMedia: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("This ad is filed in the public archive under \(page.organization ?? page.name), and stays there after it stops running.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.slate400)

                        TextField("Headline", text: $model.headline).fieldStyle()
                        TextField("Ad text", text: $model.body, axis: .vertical)
                            .lineLimit(3...8)
                            .fieldStyle()
                        TextField("Paid for by (required)", text: $model.paidForBy).fieldStyle()
                        TextField("Link (optional)", text: $model.targetUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .fieldStyle()
                        TextField("Budget, e.g. 250", text: $model.spend)
                            .keyboardType(.decimalPad)
                            .fieldStyle()
                        TextField("Region (optional)", text: $model.region).fieldStyle()

                        AttachmentStrip(attachments: $model.media, thumbnailSize: 56)
                        PhotosPicker(selection: $pickedMedia, maxSelectionCount: 1,
                                     matching: .any(of: [.images, .videos])) {
                            Text("Add an image or video")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.cyan300)
                        }

                        ErrorBanner(message: model.errorMessage)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Run an ad")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.cyan400)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.isSaving ? "Submitting…" : "Submit") {
                        Task { if await model.save(pageId: page.id) { dismiss() } }
                    }
                    .disabled(model.isSaving || !model.canSave)
                }
            }
            .onChange(of: pickedMedia) { _, items in
                Task {
                    model.media = await AttachmentLoader.load(items)
                    pickedMedia = []
                }
            }
        }
    }
}
