import SwiftUI

/// Places you've been. Search runs through the server's geocoder proxy
/// rather than Core Location, so it works even when location permission is
/// denied — and a denied permission is sticky, which makes search the only
/// path that always works.
struct PlacesView: View {
    @StateObject private var model = PlacesViewModel()

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    searchBar

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                    }

                    if !model.results.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader("Search results")
                            ForEach(model.results) { result in
                                Button { model.pendingPlace = result } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text(result.address ?? "")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.slate400)
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    }

                    SectionHeader("Saved places")
                    if model.places.isEmpty {
                        Text("Nothing saved yet. Search above to add somewhere.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .card()
                    }
                    ForEach(model.places) { place in
                        PlaceRow(place: place) { await model.remove(place) }
                    }
                }
                .padding(14)
            }
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .task { await model.load() }
        .sheet(item: $model.pendingPlace) { result in
            AddPlaceView(result: result) {
                await model.load()
                model.clearSearch()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("Search for a place", text: $model.query)
                .autocorrectionDisabled()
                .fieldStyle()
                .onSubmit { Task { await model.search() } }
            Button(model.isSearching ? "…" : "Search") { Task { await model.search() } }
                .disabled(model.query.count < 3 || model.isSearching)
        }
    }

}

struct PlaceRow: View {
    let place: VisitedPlace
    let onDelete: () async -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                if let address = place.address {
                    Text(address)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.slate400)
                        .lineLimit(2)
                }
                if let note = place.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.slate300)
                }
                if place.isPublic == true {
                    Text("Public")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.cyan300)
                }
            }
            Spacer()
            Button { Task { await onDelete() } } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.danger)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct AddPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    let result: GeocodeResult
    let onSaved: () async -> Void

    @StateObject private var model = AddPlaceViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(result.address ?? "")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.slate400)
                    }

                    TextField("Note (optional)", text: $model.note, axis: .vertical)
                        .lineLimit(2...4)
                        .fieldStyle()

                    DatePicker("Visited", selection: $model.visitedAt, displayedComponents: .date)
                        .foregroundStyle(.white)

                    Toggle("Visible to others", isOn: $model.isPublic)
                        .foregroundStyle(.white)
                    Text("Others also need your \"Show my places\" privacy setting turned on.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.slate400)

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                    }
                    Spacer()
                }
                .font(.system(size: 14))
                .padding(16)
            }
            .navigationTitle("Save place")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.cyan400)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(model.isSaving)
                }
            }
        }
    }

    private func save() async {
        guard await model.save(result) else { return }
        dismiss()
        await onSaved()
    }
}
