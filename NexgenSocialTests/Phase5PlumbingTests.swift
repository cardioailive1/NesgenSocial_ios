import XCTest
@testable import NexgenSocial

/// Phase 5 of the parity backlog: the plumbing the earlier phases left
/// behind. Each test covers one row of that table.
@MainActor
final class Phase5PlumbingTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    // MARK: - Unread count

    func testUnreadCountHitsItsOwnRoute() async throws {
        let box = RequestBox()
        StubAPI.install { request in
            box.record(request)
            return (200, Data(#"{"unreadCount":7}"#.utf8))
        }

        let count = try await MessagesService.unreadCount()

        XCTAssertEqual(box.path, "/api/messages/unread-count")
        XCTAssertEqual(box.method, "GET")
        XCTAssertEqual(count, 7)
    }

    /// The badge used to sum the conversation list, so it was only as fresh as
    /// the last full fetch. It now takes the server's own total.
    func testRefreshingTheBadgeTakesTheServerTotal() async {
        StubAPI.install(json: #"{"unreadCount":4}"#)

        await UnreadBadge.shared.refresh()

        XCTAssertEqual(UnreadBadge.shared.count, 4)
    }

    /// A failed request must leave the last known number alone rather than
    /// blanking the badge.
    func testAFailedRefreshKeepsTheLastCount() async {
        StubAPI.install(json: #"{"unreadCount":4}"#)
        await UnreadBadge.shared.refresh()

        StubAPI.install(json: #"{"error":"nope"}"#, status: 500)
        await UnreadBadge.shared.refresh()

        XCTAssertEqual(UnreadBadge.shared.count, 4)
    }

    // MARK: - Marketplace photo removal

    func testRemovingAPhotoHitsTheNestedMediaRoute() async throws {
        let box = RequestBox()
        StubAPI.install { request in
            box.record(request)
            return (204, Data())
        }

        try await MarketplaceService.removeMedia("m9", from: "l1")

        XCTAssertEqual(box.path, "/api/marketplace/l1/media/m9")
        XCTAssertEqual(box.method, "DELETE")
    }

    /// The route answers 204 with no listing, so the card's media, its counts
    /// and its cover are all corrected locally.
    func testRemovingAPhotoUpdatesTheCardInPlace() async {
        StubAPI.install(json: #"""
        {"listings":[{"id":"l1","title":"Bike","description":"d","priceCents":100,
          "photoCount":2,"videoCount":0,"coverUrl":"a.jpg",
          "media":[{"id":"m1","url":"a.jpg","kind":"PHOTO"},
                   {"id":"m2","url":"b.jpg","kind":"PHOTO"}]}]}
        """#)
        let model = MarketplaceViewModel()
        await model.load()

        StubAPI.install(json: "", status: 204)
        let first = model.listings[0].media![0]
        await model.removePhoto(first, from: model.listings[0])

        XCTAssertEqual(model.listings[0].media?.map(\.id), ["m2"])
        XCTAssertEqual(model.listings[0].photoCount, 1)
        XCTAssertEqual(model.listings[0].coverUrl, "b.jpg")
        XCTAssertNil(model.errorMessage)
    }

    /// A refused removal must leave the photo on the card rather than hiding
    /// media the server still has.
    func testARefusedRemovalKeepsThePhoto() async {
        StubAPI.install(json: #"""
        {"listings":[{"id":"l1","title":"Bike","description":"d","priceCents":100,
          "media":[{"id":"m1","url":"a.jpg","kind":"PHOTO"}]}]}
        """#)
        let model = MarketplaceViewModel()
        await model.load()

        StubAPI.install(json: #"{"error":"Media not found."}"#, status: 404)
        await model.removePhoto(model.listings[0].media![0], from: model.listings[0])

        XCTAssertEqual(model.listings[0].media?.map(\.id), ["m1"])
        XCTAssertNotNil(model.errorMessage)
    }

    // MARK: - Newsroom gallery

    func testAddingGalleryMediaHitsTheNewsroomMediaRoute() async throws {
        let box = RequestBox()
        StubAPI.install { request in
            box.record(request)
            return (201, Data(#"{"media":[{"id":"g1","url":"a.jpg","kind":"PHOTO"}]}"#.utf8))
        }

        let media = try await NewsService.addNewsroomMedia(
            [PickedAttachment(data: Data([1]), filename: "a.jpg",
                              mimeType: "image/jpeg", isVideo: false)],
            to: "n1")

        XCTAssertEqual(box.path, "/api/newsrooms/n1/media")
        XCTAssertEqual(box.method, "POST")
        XCTAssertEqual(media.map(\.id), ["g1"])
    }

    // MARK: - Political page refresh

    /// The page arrives by value from the list, so a screen left open used to
    /// keep the counts it was opened with.
    func testLoadingAPageReplacesTheSeededCounts() async {
        StubAPI.install { request in
            if request.url?.path == "/api/political/pages/p1" {
                return (200, Data(#"{"page":{"id":"p1","name":"Seed","type":"CANDIDATE","followerCount":42,"postCount":3}}"#.utf8))
            }
            return (200, Data(#"{"posts":[]}"#.utf8))
        }

        let model = PoliticalPageViewModel(page: PoliticalPage(id: "p1", name: "Seed", type: "CANDIDATE"))
        XCTAssertEqual(model.page.followerCount, nil)

        await model.load()

        XCTAssertEqual(model.page.followerCount, 42)
        XCTAssertEqual(model.page.postCount, 3)
    }

    // MARK: - Marketplace listing edit

    func testEditingAListingSendsEveryFieldAsAPatch() async {
        StubAPI.install(json: #"{"listings":[{"id":"l1","title":"Bike","description":"d","priceCents":5000}]}"#)
        let model = MarketplaceViewModel()
        await model.load()

        let box = RequestBox()
        StubAPI.install { request in
            box.record(request)
            return (200, Data(#"{"listing":{"id":"l1","title":"Road bike","description":"new","priceCents":4250,"condition":"Used","location":"Columbus, OH"}}"#.utf8))
        }

        let saved = await model.saveEdits(to: model.listings[0],
                                          title: "Road bike",
                                          description: "new",
                                          price: "42.50",
                                          condition: "Used",
                                          location: "Columbus, OH")

        XCTAssertTrue(saved)
        XCTAssertEqual(box.path, "/api/marketplace/l1")
        XCTAssertEqual(box.method, "PATCH")
        XCTAssertEqual(box.body["title"] as? String, "Road bike")
        XCTAssertEqual(box.body["priceCents"] as? Int, 4250)
        XCTAssertEqual(box.body["location"] as? String, "Columbus, OH")
        XCTAssertEqual(model.listings[0].title, "Road bike")
        XCTAssertEqual(model.listings[0].priceCents, 4250)
    }

    /// A price that is not a number must not be sent as one, and the sheet
    /// must stay open.
    func testEditingRefusesAnUnparseablePrice() async {
        StubAPI.install(json: #"{"listings":[{"id":"l1","title":"Bike","description":"d","priceCents":5000}]}"#)
        let model = MarketplaceViewModel()
        await model.load()

        let saved = await model.saveEdits(to: model.listings[0],
                                          title: "Bike",
                                          description: "d",
                                          price: "free",
                                          condition: "",
                                          location: "")

        XCTAssertFalse(saved)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.listings[0].priceCents, 5000)
    }

    /// Same shape as the box in `Phase4ProfileTests`, plus the body: several
    /// Phase 5 rows are PATCHes whose fields are the point.
    private final class RequestBox: @unchecked Sendable {
        var path: String?
        var method: String?
        var body: [String: Any] = [:]

        static func drain(_ stream: InputStream) -> Data {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            return data
        }

        func record(_ request: URLRequest) {
            path = request.url?.path
            method = request.httpMethod
            // URLSession hands `URLProtocol` the body as a stream, not as
            // `httpBody`, so a PATCH body has to be read back off the stream.
            if let data = request.httpBody ?? request.httpBodyStream.map(Self.drain),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                body = json
            }
        }
    }
}
