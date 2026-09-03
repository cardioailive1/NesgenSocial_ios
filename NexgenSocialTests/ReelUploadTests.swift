import XCTest
@testable import NexgenSocial

/// The reel upload is the one multipart request that does not use the shared
/// `media` field: the server reads `video` and `thumbnail` separately, and
/// silently 400s on anything else. These check the parts by name.
@MainActor
final class ReelUploadTests: XCTestCase {

    override func tearDown() {
        StubAPI.restore()
        super.tearDown()
    }

    func testUploadSendsVideoThumbnailAndCaptionAsSeparateParts() async throws {
        let body = try await captureBody {
            _ = try await ReelsService.create(caption: "morning run #trail",
                                              durationSec: 12.7,
                                              video: Data("video-bytes".utf8),
                                              thumbnail: Data("jpeg-bytes".utf8))
        }

        XCTAssertTrue(body.contains(#"name="video""#))
        XCTAssertTrue(body.contains(#"name="thumbnail""#))
        XCTAssertFalse(body.contains(#"name="media""#), "reels do not use the shared media field")
        XCTAssertTrue(body.contains("morning run #trail"))
        // The server does Number(durationSec); "12.7" would land as a float
        // in an integer column.
        XCTAssertTrue(body.contains("13"), "duration is rounded to whole seconds")
    }

    func testUploadWithoutAThumbnailOmitsThatPart() async throws {
        let body = try await captureBody {
            _ = try await ReelsService.create(caption: "",
                                              durationSec: 5,
                                              video: Data("video-bytes".utf8),
                                              thumbnail: nil)
        }

        XCTAssertTrue(body.contains(#"name="video""#))
        XCTAssertFalse(body.contains(#"name="thumbnail""#))
    }

    // MARK: -

    /// Runs `work` against the stub and returns the multipart body it sent, as
    /// text so the part headers can be read.
    private func captureBody(_ work: () async throws -> Void) async throws -> String {
        let box = BodyBox()
        StubAPI.install { request in
            box.data = request.httpBody ?? request.httpBodyStream.map { stream in
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
            return (200, Data(#"{"reel":{"id":"r1","videoUrl":"/uploads/r1.mov"}}"#.utf8))
        }
        try await work()

        let data = try XCTUnwrap(box.data, "no request was sent")
        return String(decoding: data, as: UTF8.self)
    }

    private final class BodyBox: @unchecked Sendable { var data: Data? }
}
