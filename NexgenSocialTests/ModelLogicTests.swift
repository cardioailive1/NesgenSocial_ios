import XCTest
@testable import NexgenSocial

/// Covers the logic that lives on the models themselves: the derived values a
/// screen reads straight into a label, and the decoding of the two fields the
/// API is inconsistent about.
final class ModelLogicTests: XCTestCase {

    // MARK: - Post.displayMedia

    func testDisplayMediaPrefersTheMediaArray() {
        let post = decodePost("""
        {"id":"p1","body":"hi","mediaUrl":"https://h/old.jpg",
         "media":[{"id":"m1","url":"https://h/new.jpg","kind":"PHOTO"}]}
        """)
        XCTAssertEqual(post.displayMedia.map(\.url), ["https://h/new.jpg"])
    }

    func testDisplayMediaFallsBackToLegacyMediaUrl() {
        let post = decodePost("""
        {"id":"p1","body":"hi","mediaUrl":"https://h/photo.jpg"}
        """)
        XCTAssertEqual(post.displayMedia.count, 1)
        XCTAssertEqual(post.displayMedia.first?.kind, .photo)
        XCTAssertEqual(post.displayMedia.first?.id, "legacy-p1")
    }

    /// An empty array is not the same as a missing one: the fallback has to
    /// fire for it too, or a legacy post renders as a blank card.
    func testDisplayMediaFallsBackWhenMediaArrayIsEmpty() {
        let post = decodePost("""
        {"id":"p1","body":"hi","mediaUrl":"https://h/photo.jpg","media":[]}
        """)
        XCTAssertEqual(post.displayMedia.count, 1)
    }

    func testDisplayMediaInfersVideoFromExtensionAndFromType() {
        for url in ["https://h/clip.MP4", "https://h/clip.webm", "https://h/clip.mov"] {
            let post = decodePost("{\"id\":\"p1\",\"body\":null,\"mediaUrl\":\"\(url)\"}")
            XCTAssertEqual(post.displayMedia.first?.kind, .video, url)
        }
        // No usable extension, but the server said VIDEO.
        let typed = decodePost("""
        {"id":"p1","body":null,"type":"VIDEO","mediaUrl":"https://h/stream"}
        """)
        XCTAssertEqual(typed.displayMedia.first?.kind, .video)
    }

    func testDisplayMediaIsEmptyWithNoMediaAtAll() {
        XCTAssertTrue(decodePost("{\"id\":\"p1\",\"body\":\"text only\"}").displayMedia.isEmpty)
        XCTAssertTrue(decodePost("{\"id\":\"p1\",\"body\":null,\"mediaUrl\":\"\"}").displayMedia.isEmpty)
    }

    // MARK: - Likeable

    func testToggleLikeFlipsHeartAndCount() {
        var post = decodePost("{\"id\":\"p1\",\"body\":null,\"likeCount\":4,\"likedByViewer\":false}")
        post.toggleLikeLocally()
        XCTAssertTrue(post.isLiked)
        XCTAssertEqual(post.likeCount, 5)
    }

    /// The failure path calls it a second time to undo the first.
    func testToggleLikeTwiceRestoresTheOriginalState() {
        var post = decodePost("{\"id\":\"p1\",\"body\":null,\"likeCount\":4,\"likedByViewer\":true}")
        post.toggleLikeLocally()
        post.toggleLikeLocally()
        XCTAssertEqual(post.likedByViewer, true)
        XCTAssertEqual(post.likeCount, 4)
    }

    /// A stale count of 0 on a post the viewer has liked must not go negative.
    func testUnlikingNeverProducesANegativeCount() {
        var post = decodePost("{\"id\":\"p1\",\"body\":null,\"likeCount\":0,\"likedByViewer\":true}")
        post.toggleLikeLocally()
        XCTAssertEqual(post.likeCount, 0)
    }

    // MARK: - LooseString / scoreLine

    func testLooseStringDecodesStringsIntegersAndNull() throws {
        let event = try JSONDecoder().decode(SportsEvent.self, from: Data("""
        {"id":"e1","homeScore":"2","awayScore":1}
        """.utf8))
        XCTAssertEqual(event.scoreLine, "2 – 1")

        let unplayed = try JSONDecoder().decode(SportsEvent.self, from: Data("""
        {"id":"e2","homeScore":null,"awayScore":null}
        """.utf8))
        XCTAssertEqual(unplayed.scoreLine, "", "a fixture with no score shows nothing")
    }

    // MARK: - JobPosting.salaryText

    func testSalaryTextRangeSingleValueAndAbsence() {
        XCTAssertEqual(job(min: 90_000, max: 120_000, period: "YEAR"), "USD 90,000–120,000/yr")
        XCTAssertEqual(job(min: 50, max: nil, period: "HOUR"), "USD 50/hr")
        XCTAssertEqual(job(min: nil, max: 8_000, period: "MONTH"), "USD 8,000/mo")
        XCTAssertNil(job(min: nil, max: nil, period: "YEAR"),
                     "no salary at all means no line, not a zero")
    }

    /// An unknown period must not append a stray suffix, and a missing one
    /// falls back to the yearly default.
    func testSalaryTextHandlesUnknownAndMissingPeriods() {
        XCTAssertEqual(job(min: 100, max: nil, period: "WEEK"), "USD 100")
        XCTAssertEqual(job(min: 100, max: nil, period: nil), "USD 100/yr")
    }

    // MARK: - money()

    func testMoneyFormatsCentsAndTreatsNilAsZero() {
        XCTAssertEqual(money(2_500), Double(25).formatted(.currency(code: "USD")))
        XCTAssertEqual(money(nil), Double(0).formatted(.currency(code: "USD")))
    }

    // MARK: - Helpers

    private func decodePost(_ json: String) -> Post {
        try! JSONDecoder().decode(Post.self, from: Data(json.utf8))
    }

    private func job(min: Int?, max: Int?, period: String?) -> String? {
        var fields = ["\"id\":\"j1\"", "\"title\":\"t\"", "\"companyName\":\"c\""]
        if let min { fields.append("\"salaryMin\":\(min)") }
        if let max { fields.append("\"salaryMax\":\(max)") }
        if let period { fields.append("\"salaryPeriod\":\"\(period)\"") }
        let json = "{\(fields.joined(separator: ","))}"
        return try! JSONDecoder().decode(JobPosting.self, from: Data(json.utf8)).salaryText
    }
}
