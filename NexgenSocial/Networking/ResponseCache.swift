import Foundation
import CryptoKit

/// The last successful body of every GET, on disk and in memory.
///
/// Without it, every screen in the app starts from a spinner every time it is
/// opened, even one visited a moment ago, and every one of them is blank when
/// the phone has no signal. The bodies are small (JSON, already decoded once)
/// and the server has no useful cache headers to lean on -- `/api` sends an
/// `ETag` but no `Cache-Control`, so `URLCache` will not hold on to any of
/// this by itself.
///
/// Lives in `Caches/`, which iOS is free to purge under storage pressure --
/// exactly the right guarantee for something that is only ever an
/// optimisation.
enum ResponseCache {
    /// True for the duration of a pull-to-refresh, so those reads skip the
    /// cache. Task-local rather than a flag on the client: it applies to the
    /// one refresh in flight and cannot leak into whatever else is loading.
    @TaskLocal static var bypass = false

    /// Runs `work` with the cache bypassed.
    static func bypassed(_ work: () async -> Void) async {
        await $bypass.withValue(true) { await work() }
    }

    struct Entry {
        let data: Data
        let storedAt: Date

        var age: TimeInterval { Date().timeIntervalSince(storedAt) }
    }

    /// Serialises the memory layer and the file operations. The cache is
    /// touched from every screen at once, and it is not worth an actor: no
    /// call here awaits anything.
    private static let lock = NSLock()
    private static var memory: [String: Entry] = [:]
    /// Reads are answered from memory when possible; this only bounds how much
    /// stays resident, not how much is kept.
    private static let memoryLimit = 60
    private static var savesSincePrune = 0

    private static let directory: URL? = {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        else { return nil }
        let directory = caches.appendingPathComponent("api-responses", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    /// A path is not a legal filename (slashes, query strings), and hashing
    /// also keeps ids out of the filesystem.
    private static func filename(for path: String) -> String {
        SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func load(_ path: String) -> Entry? {
        lock.lock()
        if let hit = memory[path] {
            lock.unlock()
            return hit
        }
        lock.unlock()

        guard let directory else { return nil }
        let file = directory.appendingPathComponent(filename(for: path))
        guard let data = try? Data(contentsOf: file),
              let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey])
                  .contentModificationDate
        else { return nil }

        let entry = Entry(data: data, storedAt: modified)
        lock.lock()
        memory[path] = entry
        lock.unlock()
        return entry
    }

    static func save(_ data: Data, for path: String) {
        lock.lock()
        memory[path] = Entry(data: data, storedAt: Date())
        if memory.count > memoryLimit {
            // Oldest first. The disk copy survives, so this costs a file read
            // at worst, never a network request.
            let excess = memory.sorted { $0.value.storedAt < $1.value.storedAt }
                .prefix(memory.count - memoryLimit)
            for (key, _) in excess { memory.removeValue(forKey: key) }
        }
        savesSincePrune += 1
        let shouldPrune = savesSincePrune >= 50
        if shouldPrune { savesSincePrune = 0 }
        lock.unlock()

        guard let directory else { return }
        try? data.write(to: directory.appendingPathComponent(filename(for: path)), options: .atomic)
        if shouldPrune { pruneDisk() }
    }

    /// Everything, including the files. Called when the signed-in account
    /// changes -- one person's feed must never be handed to the next -- and
    /// after any mutation, because a stale list is worse than a spinner when
    /// it contradicts something the user just did.
    static func clear() {
        lock.lock()
        memory.removeAll()
        lock.unlock()

        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Keeps the newest 300 files. iOS purges this directory on its own when
    /// storage runs short; this only stops it growing without bound in the
    /// meantime.
    private static func pruneDisk() {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
        else { return }
        guard files.count > 300 else { return }

        let dated = files.map { url -> (URL, Date) in
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            return (url, modified)
        }
        for (url, _) in dated.sorted(by: { $0.1 < $1.1 }).prefix(files.count - 300) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
