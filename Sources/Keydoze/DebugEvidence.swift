#if DEBUG
import AppKit

/// Opt-in development evidence. Lifecycle only: no characters, event payloads or raw input.
@MainActor enum DebugEvidence {
    static var directory: URL? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--evidence"), args.count > index + 1 else { return nil }
        return URL(fileURLWithPath: args[index + 1], isDirectory: true)
    }
    static func record(_ name: String, details: [String: String] = [:]) {
        guard let directory else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload = ["lifecycle": name, "time": String(SessionClock.now)].merging(details) { _, new in new }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let line = String(data: data, encoding: .utf8) else { return }
        let url = directory.appendingPathComponent("lifecycle.jsonl")
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        if let file = try? FileHandle(forWritingTo: url) {
            defer { try? file.close() }
            _ = try? file.seekToEnd()
            try? file.write(contentsOf: Data((line + "\n").utf8))
        }
    }
}
#endif
