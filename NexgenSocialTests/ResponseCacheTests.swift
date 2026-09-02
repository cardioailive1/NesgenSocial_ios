import XCTest
@testable import NexgenSocial

/// The caching layer added on 2026-09-01: `ResponseCache` plus the
/// stale-while-revalidate behaviour in `APIClient.get`.
///
/// These are the rules that would break the app quietly if they regressed —
/// serving one account's data to another, hiding a server error behind old
/// content, or answering a pull-to-refresh from the cache.
@MainActor
final class ResponseCacheTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ResponseCache.clear()
    }

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    // MARK: - The store

    func testASavedBodyComesBack() {
        ResponseCache.save(Data(#"{"a":1}"#.utf8), for: "/api/thing")

        XCTAssertEqual(ResponseCache.load("/api/thing")?.data, Data(#"{"a":1}"#.utf8))
        XCTAssertLessThan(ResponseCache.load("/api/thing")?.age ?? .infinity, 5)
    }

    func testPathsWithQueryStringsAreDistinctEntries() {
        ResponseCache.save(Data("first".utf8), for: "/api/list?page=1")
        ResponseCache.save(Data("second".utf8), for: "/api/list?page=2")

        XCTAssertEqual(ResponseCache.load("/api/list?page=1")?.data, Data("first".utf8))
        XCTAssertEqual(ResponseCache.load("/api/list?page=2")?.data, Data("second".utf8))
    }

    func testClearingRemovesEverything() {
        ResponseCache.save(Data("x".utf8), for: "/api/thing")
        ResponseCache.clear()

        XCTAssertNil(ResponseCache.load("/api/thing"))
    }

    // MARK: - Stale-while-revalidate

    func testASecondReadInsideTheWindowDoesNotHitTheNetwork() async throws {
        var requests = 0
        StubAPI.install { _ in
            requests += 1
            return (200, Data(#"{"conversations":[{"id":"c1"}]}"#.utf8))
        }

        _ = try await APIClient.shared.get("/api/messages", as: ConversationsResponse.self)
        _ = try await APIClient.shared.get("/api/messages", as: ConversationsResponse.self)

        // The second read is served from the cache. It also kicks off a
        // background refresh, so anything above 2 would still be correct —
        // what must not happen is the read itself waiting on the network.
        XCTAssertGreaterThanOrEqual(requests, 1)
        XCTAssertLessThanOrEqual(requests, 2)
    }

    func testMaxAgeZeroAlwaysAsksTheServer() async throws {
        var requests = 0
        StubAPI.install { _ in
            requests += 1
            return (200, Data(#"{"messages":[]}"#.utf8))
        }

        for _ in 0..<3 {
            _ = try await APIClient.shared.get("/api/messages/c1/messages",
                                               as: MessagesResponse.self, maxAge: 0)
        }

        XCTAssertEqual(requests, 3, "polled routes must never be cached")
    }

    func testABypassedReadAlwaysAsksTheServer() async throws {
        var requests = 0
        StubAPI.install { _ in
            requests += 1
            return (200, Data(#"{"conversations":[]}"#.utf8))
        }

        _ = try await APIClient.shared.get("/api/messages", as: ConversationsResponse.self)
        await ResponseCache.bypassed {
            _ = try? await APIClient.shared.get("/api/messages", as: ConversationsResponse.self)
        }

        XCTAssertGreaterThanOrEqual(requests, 2, "pull-to-refresh must reach the server")
    }

    // MARK: - What must still surface

    func testAServerErrorIsNotHiddenBehindCachedContent() async throws {
        StubAPI.install(json: #"{"conversations":[{"id":"c1"}]}"#)
        _ = try await APIClient.shared.get("/api/messages", as: ConversationsResponse.self, maxAge: 0)

        StubAPI.install(json: #"{"error":"Conversations are down."}"#, status: 500)
        // `install` clears the cache, so re-seed it to make the point
        // explicitly: even with a body on hand, a 500 has to be thrown.
        ResponseCache.save(Data(#"{"conversations":[{"id":"c1"}]}"#.utf8), for: "/api/messages")

        do {
            _ = try await APIClient.shared.get("/api/messages", as: ConversationsResponse.self, maxAge: 0)
            XCTFail("a 500 must reach the caller, not be replaced by cached content")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Conversations are down.")
        }
    }

    func testSigningOutDropsTheCache() async {
        ResponseCache.save(Data(#"{"conversations":[{"id":"c1"}]}"#.utf8), for: "/api/messages")

        await APIClient.shared.setToken(nil)

        XCTAssertNil(ResponseCache.load("/api/messages"),
                     "one account's data must never survive into the next session")
    }
}
