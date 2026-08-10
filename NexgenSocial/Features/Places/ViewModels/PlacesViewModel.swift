import Foundation

@MainActor
final class PlacesViewModel: ObservableObject {
    @Published private(set) var places: [VisitedPlace] = []
    @Published private(set) var results: [GeocodeResult] = []
    @Published private(set) var isSearching = false
    @Published var query = ""
    @Published var pendingPlace: GeocodeResult?
    @Published var errorMessage: String?

    func load() async {
        places = (try? await ProfileService.places()) ?? []
    }

    func search() async {
        isSearching = true
        defer { isSearching = false }
        errorMessage = nil
        do {
            results = try await ProfileService.geocode(query)
            if results.isEmpty { errorMessage = "No places matched that search." }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearSearch() {
        results = []
        query = ""
    }

    func remove(_ place: VisitedPlace) async {
        do {
            try await ProfileService.removePlace(place.id)
            places.removeAll { $0.id == place.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class AddPlaceViewModel: ObservableObject {
    @Published var note = ""
    @Published var isPublic = false
    @Published var visitedAt = Date()
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    /// True when the place was saved.
    func save(_ result: GeocodeResult) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await ProfileService.addPlace([
                "name": result.name,
                "address": result.address ?? "",
                "latitude": result.latitude,
                "longitude": result.longitude,
                "note": note,
                "isPublic": isPublic,
                "visitedAt": ISO8601DateFormatter().string(from: visitedAt),
            ])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
