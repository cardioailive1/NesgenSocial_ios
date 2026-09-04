import XCTest
@testable import NexgenSocial

/// The export route reads the bearer header and nothing else, so the old
/// "open it in Safari" link could only ever come back a 401. It has to go
/// through the API client, and land as a file the share sheet can hand on.
@MainActor
final class DataExportTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    func testTheExportIsFetchedWithTheAuthHeaderAndWrittenToAFile() async throws {
        await APIClient.shared.setToken("token-123")
        var authorization: String?
        var path: String?
        StubAPI.install { request in
            authorization = request.value(forHTTPHeaderField: "Authorization")
            path = request.url?.path
            return (200, Data(#"{"exportedAt":"2026-09-03T00:00:00.000Z","posts":[]}"#.utf8))
        }

        let file = try await ProfileService.exportData(username: "rishi")
        defer { try? FileManager.default.removeItem(at: file) }

        XCTAssertEqual(path, "/api/users/me/export")
        XCTAssertEqual(authorization, "Bearer token-123")
        XCTAssertEqual(file.lastPathComponent, "nexgensocial-export-rishi.json")
        let written = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(written.contains("exportedAt"), "the file holds the server's body; got \(written)")
    }

    func testARefusedExportThrowsInsteadOfWritingAFile() async {
        StubAPI.install(json: #"{"error":"Sign in required."}"#, status: 401)

        do {
            let file = try await ProfileService.exportData(username: "rishi")
            try? FileManager.default.removeItem(at: file)
            XCTFail("a 401 should not produce an export file")
        } catch {
            // Expected: the screen shows this rather than sharing an error page.
        }
    }
}
