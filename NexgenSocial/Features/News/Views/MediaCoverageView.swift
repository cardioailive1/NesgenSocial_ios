import SwiftUI
import PhotosUI

/// Media Coverage — newsrooms publishing here, in the same three sections the
/// web page uses: the stories, the newsrooms themselves, and the publishing
/// tools for the ones you own. Headlines from outside outlets stay in
/// Breaking news.
struct MediaCoverageView: View {
    @StateObject private var model = MediaCoverageViewModel()
    @EnvironmentObject private var session: AuthSession
    @State private var section: Section = .coverage

    private enum Section: String, CaseIterable, Identifiable {
        case coverage = "Coverage"
        case newsrooms = "Newsrooms"
        case publish = "Publish"
        var id: String { rawValue }
    }

    private var myNewsrooms: [Newsroom] { model.mine(username: session.currentUser?.username) }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Text("Newsrooms publishing here, plus their live broadcasts. For headlines from outside outlets, see Breaking news.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.slate400)
                        .padding(.horizontal, 14)

                    Picker("Section", selection: $section) {
                        ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 14)

                    ErrorBanner(message: model.errorMessage)

                    switch section {
                    case .coverage: coverage
                    case .newsrooms: newsrooms
                    case .publish: PublishSection(model: model, myNewsrooms: myNewsrooms)
                    }
                }
                .padding(.vertical, 12)
            }
            .pullToRefresh { await model.load() }

            if model.isLoading && model.articles.isEmpty && model.newsrooms.isEmpty {
                ProgressView().tint(Theme.cyan400)
            }
        }
        .navigationTitle("Media Coverage")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    @ViewBuilder
    private var coverage: some View {
        if model.articles.isEmpty && !model.isLoading {
            EmptyNotice("No stories published yet. Create a newsroom to start publishing.")
        }
        ForEach(model.articles) { article in
            ArticleCard(article: article)
                .padding(.horizontal, 14)
        }
    }

    @ViewBuilder
    private var newsrooms: some View {
        if model.newsrooms.isEmpty && !model.isLoading {
            EmptyNotice("No newsrooms yet.")
        }
        ForEach(model.newsrooms) { newsroom in
            HStack(spacing: 10) {
                NavigationLink { NewsroomDetailView(slug: newsroom.slug) } label: {
                    NewsroomCard(newsroom: newsroom)
                }
                Button(newsroom.followedByViewer == true ? "Following" : "Follow") {
                    Task { await model.toggleFollow(newsroom) }
                }
                .buttonStyle(.borderedProminent)
                .tint(newsroom.followedByViewer == true ? Theme.navy800 : Theme.cyan400)
                .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 14)
        }
    }
}

/// Create a newsroom, publish a story from one, or take one live.
private struct PublishSection: View {
    @ObservedObject var model: MediaCoverageViewModel
    let myNewsrooms: [Newsroom]

    @State private var showingNewsroomForm = false
    @State private var showingArticleForm = false
    @State private var liveStream: Livestream?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showingNewsroomForm = true
            } label: {
                Label("Create a newsroom", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.cyan400)
            .foregroundStyle(Theme.navy950)

            if myNewsrooms.isEmpty {
                Text("Create a newsroom to publish stories and broadcast live under its name.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.slate400)
            } else {
                SectionHeader("Your newsrooms")
                ForEach(myNewsrooms) { newsroom in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(newsroom.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(newsroom.articleCount ?? 0) stories")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.slate400)
                        }
                        Spacer()
                        Button("Go live") {
                            Task { liveStream = await model.goLive(as: newsroom) }
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.danger)
                        .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(12)
                    .card()
                }

                Button {
                    showingArticleForm = true
                } label: {
                    Label("Publish a story", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.cyan400)
                .foregroundStyle(Theme.navy950)
            }
        }
        .padding(.horizontal, 14)
        .sheet(isPresented: $showingNewsroomForm) {
            NewNewsroomView { await model.load() }
        }
        .sheet(isPresented: $showingArticleForm) {
            PublishArticleView(newsrooms: myNewsrooms) { await model.load() }
        }
        .fullScreenCover(item: $liveStream) { stream in
            LivestreamRoomView(stream: stream, onEnded: { await model.load() }) { problem in
                model.errorMessage = problem
            }
        }
    }
}

struct NewNewsroomView: View {
    @Environment(\.dismiss) private var dismiss
    let onCreated: () async -> Void

    @StateObject private var model = NewNewsroomViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                Form {
                    SwiftUI.Section {
                        TextField("Newsroom name", text: $model.name)
                        TextField("Responsible organization (shown publicly)", text: $model.organization)
                        TextField("What does this newsroom cover?", text: $model.details, axis: .vertical)
                            .lineLimit(2...4)
                        TextField("Beat (e.g. Politics)", text: $model.beat)
                        TextField("Region", text: $model.region)
                        TextField("Website (optional)", text: $model.websiteUrl)
                            .textInputAutocapitalization(.never)
                    } footer: {
                        Text("Both a name and the organization behind it are required — a newsroom readers can't attribute is one they can't evaluate.")
                    }
                    .listRowBackground(Theme.navy900)

                    MediaField(title: "Newsroom logo", limit: 1, attachments: $model.logo)
                    MediaField(title: "Cover image", limit: 1, attachments: $model.cover)
                    MediaField(title: "Photos & videos for this newsroom", limit: 10, attachments: $model.media)

                    if model.errorMessage != nil {
                        ErrorBanner(message: model.errorMessage)
                            .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .tint(Theme.cyan400)
            }
            .navigationTitle("New newsroom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.isSaving ? "Creating…" : "Create") {
                        Task {
                            guard await model.create() != nil else { return }
                            dismiss()
                            await onCreated()
                        }
                    }
                    .disabled(!model.canSubmit)
                    .tint(Theme.cyan400)
                }
            }
        }
    }
}

struct PublishArticleView: View {
    @Environment(\.dismiss) private var dismiss
    let newsrooms: [Newsroom]
    let onPublished: () async -> Void

    @StateObject private var model = PublishArticleViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                Form {
                    SwiftUI.Section {
                        Picker("Publish from", selection: $model.newsroomId) {
                            Text("Choose…").tag("")
                            ForEach(newsrooms) { Text($0.name).tag($0.id) }
                        }
                        TextField("Headline", text: $model.headline)
                        TextField("Standfirst / summary (optional)", text: $model.standfirst)
                        TextField("Story body", text: $model.body, axis: .vertical)
                            .lineLimit(6...14)
                        TextField("Byline (optional)", text: $model.byline)
                        Toggle("Mark as breaking", isOn: $model.isBreaking)
                    }
                    .listRowBackground(Theme.navy900)

                    MediaField(title: "Photos & video for this story", limit: 10,
                               attachments: $model.media)

                    if model.errorMessage != nil {
                        ErrorBanner(message: model.errorMessage)
                            .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .tint(Theme.cyan400)
            }
            .navigationTitle("Publish a story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.isPublishing ? "Publishing…" : "Publish") {
                        Task {
                            guard await model.publish() else { return }
                            dismiss()
                            await onPublished()
                        }
                    }
                    .disabled(!model.canSubmit)
                    .tint(Theme.cyan400)
                }
            }
            .onAppear {
                if model.newsroomId.isEmpty, newsrooms.count == 1 {
                    model.newsroomId = newsrooms[0].id
                }
            }
        }
    }
}

/// A labelled photo/video picker row, used by both publishing forms.
private struct MediaField: View {
    let title: String
    let limit: Int
    @Binding var attachments: [PickedAttachment]

    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        SwiftUI.Section(title) {
            if !attachments.isEmpty {
                AttachmentStrip(attachments: $attachments)
            }
            PhotosPicker(selection: $picked, maxSelectionCount: limit,
                         matching: .any(of: [.images, .videos])) {
                Label(attachments.isEmpty ? "Choose" : "Replace", systemImage: "photo.on.rectangle")
            }
            .onChange(of: picked) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    attachments = Array(await AttachmentLoader.load(items).prefix(limit))
                    picked = []
                }
            }
        }
        .listRowBackground(Theme.navy900)
    }
}

private struct EmptyNotice: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.slate400)
            .frame(maxWidth: .infinity)
            .padding(24)
            .card()
            .padding(.horizontal, 14)
    }
}
