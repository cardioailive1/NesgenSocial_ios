import Foundation

/// Append-only diagnostic log for the push-notification flow.
///
/// Push fails silently by design: a wrong APNs environment, a stale token or
/// a 401 on registration all look identical from the device -- nothing
/// arrives, and there is nothing on screen to explain it. This records every
/// step (permission, token, subscribe call, incoming push) with the request
/// body and the raw server response, so a failure can be read after the fact
/// instead of reproduced under a debugger.
///
/// ponytail: one plain text file, appended on a serial queue. The ceiling is
/// that it only rotates when it passes `maxBytes` and keeps no history --
/// swap for a rolling two-file scheme if a longer window is ever needed.
enum PushLog {

    /// Flip to `false` to hide the export button in Settings and stop
    /// writing entirely. Left on so a tester can pull the file without a
    /// new build; turn it off before release.
    static let isEnabled = true

    /// Trimmed to the most recent half once it passes this, so a device left
    /// running for weeks can't fill its disk.
    private static let maxBytes = 512_000

    static let fileURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("push-log.txt")
    }()

    private static let queue = DispatchQueue(label: "com.nexgensocial.pushlog")

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    /// - Parameters:
    ///   - function: the calling function, so a line can be traced back to
    ///     the code that wrote it without repeating the name in every call.
    static func write(_ message: String, function: String = #function) {
        guard isEnabled else { return }
        let line = "[\(stamp.string(from: Date()))] \(function) — \(message)\n"
        queue.async {
            let handle = try? FileHandle(forWritingTo: fileURL)
            if let handle {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
            } else {
                try? Data(line.utf8).write(to: fileURL)
            }
            trimIfNeeded()
        }
    }

    /// A network call that succeeded or failed, with everything needed to
    /// tell which: the endpoint, what was sent, and what came back verbatim.
    static func request(_ endpoint: String, body: [String: Any], status: Int,
                        response: String, function: String = #function) {
        let outcome = (200..<300).contains(status) ? "SUCCESS" : "FAILED"
        write("""
              POST \(endpoint) → \(status) \(outcome)
                  request:  \(json(body))
                  response: \(response.isEmpty ? "<empty>" : response)
              """, function: function)
    }

    static func failure(_ endpoint: String, body: [String: Any], error: Error,
                        function: String = #function) {
        write("""
              POST \(endpoint) → FAILED (no response)
                  request: \(json(body))
                  error:   \(error.localizedDescription)
              """, function: function)
    }

    static func header() {
        write("""
              ===== push log opened =====
                  build:       \(AppEnvironment.isDebugBuild ? "DEBUG (APNs sandbox)" : "RELEASE (APNs production)")
                  bundleId:    \(Bundle.main.bundleIdentifier ?? "?")
                  version:     \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                  baseURL:     \(APIClient.baseURL)
              """)
    }

    static func clear() {
        queue.async { try? FileManager.default.removeItem(at: fileURL) }
    }

    /// Keeps the tail rather than the head: the most recent attempt is the
    /// one being debugged.
    private static func trimIfNeeded() {
        guard let data = try? Data(contentsOf: fileURL), data.count > maxBytes else { return }
        let tail = data.suffix(maxBytes / 2)
        try? Data("…earlier entries trimmed…\n".utf8 + tail).write(to: fileURL)
    }

    /// Tokens are logged in full on purpose -- a truncated one can't be
    /// checked against what the server stored, which is the usual reason a
    /// push doesn't arrive.
    private static func json(_ body: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: body, options: .sortedKeys),
              let string = String(data: data, encoding: .utf8) else { return "\(body)" }
        return string
    }
}
