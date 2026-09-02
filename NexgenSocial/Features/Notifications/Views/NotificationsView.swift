import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @StateObject private var model = NotificationsViewModel()

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            List {
                if !model.permissionGranted {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notifications are off")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Turn them on to hear about messages, calls and friend requests while the app is closed.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.slate400)
                            Button("Turn on") { Task { await model.requestPermission() } }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.cyan400)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Theme.navy900)
                    }
                }

                if model.items.isEmpty {
                    Text("Nothing new.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.slate400)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                        .listRowBackground(Theme.navy950)
                } else {
                    ForEach(model.items, id: \.request.identifier) { note in
                        Button { model.open(note) } label: { row(note) }
                            .listRowBackground(Theme.navy900)
                            .swipeActions {
                                Button("Delete", role: .destructive) { model.remove(note) }
                            }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Notifications")
        .toolbar {
            if !model.items.isEmpty {
                Button("Clear") { model.clearAll() }
                    .tint(Theme.cyan400)
            }
        }
        .task { await model.load() }
        .pullToRefresh { await model.load() }
    }

    private func row(_ note: UNNotification) -> some View {
        let content = note.request.content
        return VStack(alignment: .leading, spacing: 4) {
            Text(content.title.isEmpty ? "Nexgen" : content.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            if !content.body.isEmpty {
                Text(content.body)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
            }
            Text(note.date, format: .relative(presentation: .named))
                .font(.system(size: 11))
                .foregroundStyle(Theme.slate400)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
