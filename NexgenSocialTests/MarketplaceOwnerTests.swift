import XCTest
@testable import NexgenSocial

/// A listing used to be write-once: it could be created and marked sold, and
/// nothing else. Deleting removes it from the list without a refetch, and
/// added photos come back on the server's updated listing.
@MainActor
final class MarketplaceOwnerTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    private let twoListings = #"{"listings":[{"id":"l1","title":"Bike","description":"good one","priceCents":5000},{"id":"l2","title":"Desk","description":"sturdy","priceCents":9000}]}"#

    /// The list is only settable from inside the view model, so it gets filled
    /// the way the screen fills it.
    private func loadedModel() async -> MarketplaceViewModel {
        StubAPI.install(json: twoListings)
        let model = MarketplaceViewModel()
        await model.load()
        return model
    }

    func testDeletingSendsADeleteAndDropsOnlyThatListing() async {
        let model = await loadedModel()
        var call: (String, String)?
        StubAPI.install { request in
            call = (request.httpMethod ?? "", request.url?.path ?? "")
            return (204, Data())
        }

        await model.delete(model.listings[0])

        XCTAssertEqual(call?.0, "DELETE")
        XCTAssertEqual(call?.1, "/api/marketplace/l1")
        XCTAssertEqual(model.listings.map(\.id), ["l2"])
    }

    /// A refused delete has to leave the listing on screen, or the seller
    /// thinks it's gone when the server still has it.
    func testAFailedDeleteKeepsTheListing() async {
        let model = await loadedModel()
        StubAPI.install(json: #"{"error":"Listing not found."}"#, status: 404)

        await model.delete(model.listings[0])

        XCTAssertEqual(model.listings.map(\.id), ["l1", "l2"])
        XCTAssertNotNil(model.errorMessage)
    }

    func testAddedPhotosPostToTheListingsMediaRoute() async throws {
        var call: (String, String)?
        StubAPI.install { request in
            call = (request.httpMethod ?? "", request.url?.path ?? "")
            return (200, Data(#"{"listing":{"id":"l1","title":"Bike","description":"good one","priceCents":5000,"photoCount":2}}"#.utf8))
        }

        let updated = try await MarketplaceService.addMedia(
            [PickedAttachment(data: Data([0xFF]), filename: "a.jpg", mimeType: "image/jpeg", isVideo: false)],
            to: "l1")

        XCTAssertEqual(call?.0, "POST")
        XCTAssertEqual(call?.1, "/api/marketplace/l1/media")
        XCTAssertEqual(updated.photoCount, 2)
    }
}
