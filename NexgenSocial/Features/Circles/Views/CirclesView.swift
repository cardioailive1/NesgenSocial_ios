import SwiftUI

/// Private audience lists you own. Members are added by username.
struct CirclesView: View {
    @StateObject private var model = CirclesViewModel()
    @State private var showingCreate = false

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if model.circles.isEmpty {
                        Text("No circles yet. A circle is a private list you can share a post with.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(.horizontal, 14)
                    }

                    ErrorBanner(message: model.errorMessage)

                    ForEach(model.circles) { circle in
                        NavigationLink {
                            CircleDetailView(circle: circle, onChanged: { await model.load() })
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(circle.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("\(circle.members?.count ?? 0) members")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.slate400)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .card()
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 12)
            }
            .pullToRefresh { await model.load() }
        }
        .navigationTitle("Circles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingCreate) {
            NewCircleView { await model.load() }
        }
        .task { await model.load() }
    }
}

struct CircleDetailView: View {
    let circle: AudienceCircle
    let onChanged: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: CircleDetailViewModel

    init(circle: AudienceCircle, onChanged: @escaping () async -> Void) {
        self.circle = circle
        self.onChanged = onChanged
        _model = StateObject(wrappedValue: CircleDetailViewModel(circle: circle))
    }

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ErrorBanner(message: model.errorMessage)
                        ForEach(model.members) { membership in
                            FriendRow(user: membership.user,
                                      subtitle: "@\(membership.user?.username ?? "")") {
                                Button("Remove") {
                                    Task {
                                        await model.remove(membership)
                                        await onChanged()
                                    }
                                }
                                .font(.system(size: 12))
                                .tint(Theme.danger)
                            }
                            .padding(.horizontal, 14)
                        }
                    }
                    .padding(.vertical, 12)
                }

                HStack(spacing: 8) {
                    TextField("Add by username", text: $model.newUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .fieldStyle()
                    Button("Add") {
                        Task {
                            await model.add()
                            await onChanged()
                        }
                    }
                        .disabled(model.newUsername.isEmpty)
                        .tint(Theme.cyan400)
                }
                .padding(12)
                .background(Theme.navy900)
            }
        }
        .navigationTitle(circle.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", role: .destructive) {
                    Task {
                        guard await model.deleteCircle() else { return }
                        await onChanged()
                        dismiss()
                    }
                }
                    .font(.system(size: 13))
                    .tint(Theme.danger)
            }
        }
    }
}

struct NewCircleView: View {
    @Environment(\.dismiss) private var dismiss
    let onCreated: () async -> Void

    @State private var name = ""
    @State private var usernames = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Circle name", text: $name).fieldStyle()
                    TextField("Usernames, comma separated", text: $usernames, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...4)
                        .fieldStyle()
                    ErrorBanner(message: errorMessage)
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("New circle")
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
        let members = usernames
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        do {
            _ = try await CirclesService.create(name: name, memberUsernames: members)
            dismiss()
            await onCreated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
