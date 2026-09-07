import XCTest
@testable import NexgenSocial

/// Phase 3 of the parity backlog: editing and deleting a published article,
/// stopping a political ad, and the impression/click events behind the counts
/// the ad archive prints.
@MainActor
final class Phase3EditorialTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    // MARK: - Article edit / delete

    /// The route is flat — `/api/newsrooms/articles/:id`, not nested under the
    /// newsroom — which is the one thing easy to get wrong here.
    func testEditingAnArticleUsesTheFlatArticleRoute() async throws {
        let box = RequestBox()
        StubAPI.install { request in
            box.record(request)
            return (200, Data(#"{"article":{"id":"a1","headline":"Corrected","correctedAt":"2026-09-04"}}"#.utf8))
        }

        let article = try await NewsService.updateArticle("a1", fields: ["headline": "Corrected"])

        XCTAssertEqual(box.path, "/api/newsrooms/articles/a1")
        XCTAssertEqual(box.method, "PATCH")
        XCTAssertEqual(article.headline, "Corrected")
        XCTAssertNotNil(article.correctedAt)
    }

    func testDeletingAnArticleUsesTheSameFlatRoute() async throws {
        let box = RequestBox()
        StubAPI.install { request in
            box.record(request)
            return (200, Data("{}".utf8))
        }

        try await NewsService.deleteArticle("a1")

        XCTAssertEqual(box.path, "/api/newsrooms/articles/a1")
        XCTAssertEqual(box.method, "DELETE")
    }

    /// A failed edit must not report success: the card reloads on success only.
    func testAFailedEditThrows() async {
        StubAPI.install(json: #"{"error":"Article not found."}"#, status: 404)

        do {
            _ = try await NewsService.updateArticle("a1", fields: ["headline": "x"])
            XCTFail("a 404 should not be reported as a successful edit")
        } catch {}
    }

    /// The form seeds itself once, so returning to a sheet mid-edit doesn't
    /// throw away what's been typed.
    func testTheEditFormSeedsFromTheArticleOnlyOnce() {
        let model = EditArticleViewModel()
        let article = NewsArticle(id: "a1", headline: "Original", standfirst: nil,
                                  body: "Body", byline: nil, isBreaking: nil,
                                  publishedAt: nil, media: nil, newsroom: nil,
                                  correctedAt: nil)

        model.fill(from: article)
        model.headline = "Half-typed edit"
        model.fill(from: article)

        XCTAssertEqual(model.headline, "Half-typed edit")
        XCTAssertTrue(model.canSubmit)
    }

    func testTheEditFormRefusesAnEmptyHeadlineOrBody() {
        let model = EditArticleViewModel()
        model.headline = "   "
        model.body = "Body"
        XCTAssertFalse(model.canSubmit)

        model.headline = "Headline"
        model.body = " "
        XCTAssertFalse(model.canSubmit)
    }

    // MARK: - Political ads

    /// Stopping an ad flips it to ENDED. It stays in the archive — the whole
    /// point of the archive is that ended ads remain inspectable.
    func testStoppingAnAdEndsItRatherThanDeletingIt() async throws {
        let box = RequestBox()
        StubAPI.install { request in
            box.record(request)
            return (200, Data(#"{"ad":{"id":"ad1","active":false,"endedAt":"2026-09-04"}}"#.utf8))
        }

        let ad = try await PoliticalService.endAd("ad1")

        XCTAssertEqual(box.path, "/api/political/ads/ad1/end")
        XCTAssertEqual(box.method, "POST")
        XCTAssertEqual(ad.active, false)
        XCTAssertNotNil(ad.endedAt)
    }

    func testAnImpressionPostsItsTypeToTheAdsEventRoute() async throws {
        let box = RequestBox()
        StubAPI.install { request in
            box.record(request)
            return (201, Data("{}".utf8))
        }

        await PoliticalService.track("IMPRESSION", adId: "ad1")

        XCTAssertEqual(box.path, "/api/political/ads/ad1/event")
        XCTAssertEqual(box.method, "POST")
        let body = try XCTUnwrap(box.json)
        XCTAssertEqual(body["type"] as? String, "IMPRESSION")
    }

    /// Analytics must never surface as an error in the feed, so the tracker
    /// swallows failures instead of throwing into the view.
    func testAFailedEventIsSwallowed() async {
        StubAPI.install(json: #"{"error":"nope"}"#, status: 500)
        await PoliticalService.track("CLICK", adId: "ad1")
    }

    /// The owner's ad list has no route of its own, so it's the public
    /// archive narrowed to this page. Ads from other pages must not leak in.
    func testTheOwnerAdListIsTheArchiveNarrowedToThisPage() async {
        StubAPI.install(json: """
        {"ads":[{"id":"mine","page":{"id":"p1","name":"Mine"}},
                {"id":"theirs","page":{"id":"p2","name":"Theirs"}}]}
        """)

        let model = PoliticalPageViewModel(page: PoliticalPage(id: "p1", name: "Mine"))
        await model.loadAds()

        XCTAssertEqual(model.ads.map(\.id), ["mine"])
    }

    // MARK: -

    private final class RequestBox: @unchecked Sendable {
        var path: String?
        var method: String?
        var body: Data?

        func record(_ request: URLRequest) {
            path = request.url?.path
            method = request.httpMethod
            body = request.httpBody ?? request.httpBodyStream.map { stream in
                stream.open()
                defer { stream.close() }
                var data = Data()
                let size = 4096
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
                defer { buffer.deallocate() }
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: size)
                    if read <= 0 { break }
                    data.append(buffer, count: read)
                }
                return data
            }
        }

        var json: [String: Any]? {
            body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        }
    }
}
