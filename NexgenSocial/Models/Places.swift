import Foundation

struct VisitedPlace: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var note: String?
    var visitedAt: String?
    var isPublic: Bool?
}

/// One geocoder hit. The server returns no identifier, so coordinates plus
/// name stand in for one — good enough to key a list that's never persisted.
struct GeocodeResult: Codable, Identifiable, Hashable {
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double

    var id: String { "\(latitude),\(longitude),\(name)" }
}

struct PlacesResponse: Codable { let places: [VisitedPlace] }
struct GeocodeResponse: Codable {
    let results: [GeocodeResult]
    var cached: Bool?
}
