import SwiftUI

/// Public groups to discover, plus the ones you're already in.
struct GroupsView: View {
    @StateObject private var model = GroupsViewModel()
    @State private var showingCreate = false

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if !model.mine.isEmpty {
                        SectionHeader("Your groups")
                        ForEach(model.mine) { group in
                            NavigationLink { GroupDetailView(group: group) } label: {
                                GroupCard(group: group)
                            }
                            .padding(.horizontal, 14)
                        }
                    }

                    SectionHeader("Discover")
                    ForEach(model.discover) { group in
                        NavigationLink { GroupDetailView(group: group) } label: {
                            GroupCard(group: group)
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingCreate) {
            NewGroupView { await model.load() }
        }
        .task { await model.load() }
    }
}

struct GroupCard: View {
    let group: SocialGroup

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if group.isPrivate == true {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
            }
        }
        .padding(12)
        .card()
    }

    private var subtitle: String {
        var parts: [String] = []
        if let count = group.memberCount { parts.append("\(count) members") }
        if let description = group.description, !description.isEmpty { parts.append(description) }
        return parts.joined(separator: " · ")
    }
}

struct GroupDetailView: View {
    let group: SocialGroup

    @StateObject private var model: GroupDetailViewModel

    init(group: SocialGroup) {
        self.group = group
        _model = StateObject(wrappedValue: GroupDetailViewModel(group: group))
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(group.description ?? "")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                        Spacer(minLength: 0)
                        Button(model.isMember ? "Leave" : "Join") {
                            Task { await model.toggleMembership() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(model.isMember ? Theme.navy800 : Theme.cyan400)
                        .font(.system(size: 13))
                    }
                    .padding(.horizontal, 14)

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, 14)
                    }

                    SectionHeader("Members")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(model.members) { member in
                                VStack(spacing: 4) {
                                    AvatarView(url: member.avatarUrl, seed: member.username, size: 44)
                                    Text(member.displayName)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Theme.slate400)
                                        .lineLimit(1)
                                }
                                .frame(width: 60)
                            }
                        }
                        .padding(.horizontal, 14)
                    }

                    SectionHeader("Posts")
                    if model.posts.isEmpty {
                        Text("Nothing posted in this group yet.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    }
                    ForEach(model.posts) { post in
                        NavigationLink { PostDetailView(post: post) } label: {
                            PostCard(post: post, onLike: {})
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

struct NewGroupView: View {
    @Environment(\.dismiss) private var dismiss
    let onCreated: () async -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var isPrivate = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Group name", text: $name).fieldStyle()
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                        .fieldStyle()
                    Toggle("Invite-only", isOn: $isPrivate)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                    }
                    Spacer()
                }
                .tint(Theme.cyan400)
                .foregroundStyle(.white)
                .padding(16)
            }
            .navigationTitle("New group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .tint(Theme.cyan400)
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func create() async {
        do {
            _ = try await GroupsService.create(name: name,
                                               description: description,
                                               isPrivate: isPrivate)
            dismiss()
            await onCreated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
