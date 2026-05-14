import Foundation

/// A tiny command-line probe for machines that only have Command Line Tools.
///
/// The real app uses `CodexProvider`; this probe mirrors the same local data
/// contract without launching AppKit so we can verify that the user's Codex
/// session directory contains readable usage signals.
let home = FileManager.default.homeDirectoryForCurrentUser
let sessionsRoot = home.appendingPathComponent(".codex/sessions", isDirectory: true)

guard let enumerator = FileManager.default.enumerator(
    at: sessionsRoot,
    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
    options: [.skipsHiddenFiles]
) else {
    print("Codex Gauge Probe")
    print("status: unavailable")
    print("reason: no ~/.codex/sessions directory")
    Foundation.exit(0)
}

let files = enumerator
    .compactMap { $0 as? URL }
    .filter { $0.pathExtension == "jsonl" }
    .sorted { left, right in
        let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        return leftDate > rightDate
    }

var latest: (timestamp: String, primary: Double, secondary: Double, primaryWindow: Int?, secondaryWindow: Int?)?

for file in files.prefix(30) {
    guard let text = try? readTail(of: file, maxBytes: 15_000_000) else {
        continue
    }

    for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
        guard line.contains("\"rate_limits\""),
              let observation = parseRateLimitLine(String(line))
        else {
            continue
        }

        if latest == nil || observation.timestamp > latest!.timestamp {
            latest = observation
        }
    }
}

print("Codex Gauge Probe")
print("session_files: \(files.count)")

if let latest {
    print("status: exact-local-snapshot")
    print("daily_remaining: \(Int((100 - latest.primary).rounded()))%")
    print("weekly_remaining: \(Int((100 - latest.secondary).rounded()))%")
    print("source_timestamp: \(latest.timestamp)")
    print("windows: \(latest.primaryWindow.map(String.init) ?? "?")m / \(latest.secondaryWindow.map(String.init) ?? "?")m")
} else {
    let estimate = estimateFromSessionFiles(files)
    print("status: estimated")
    print("daily_remaining: \(Int((100 - estimate.dailyUsed).rounded()))%")
    print("weekly_remaining: \(Int((100 - estimate.weeklyUsed).rounded()))%")
    print("reason: no local rate-limit snapshot found; estimated from session file activity")
}

private func parseRateLimitLine(_ line: String) -> (timestamp: String, primary: Double, secondary: Double, primaryWindow: Int?, secondaryWindow: Int?)? {
    guard let data = line.data(using: .utf8),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let timestamp = root["timestamp"] as? String,
          let payload = root["payload"] as? [String: Any],
          payload["type"] as? String == "token_count",
          let info = payload["info"] as? [String: Any],
          let rateLimits = info["rate_limits"] as? [String: Any],
          let primary = rateLimits["primary"] as? [String: Any],
          let secondary = rateLimits["secondary"] as? [String: Any],
          let primaryUsed = primary["used_percent"] as? Double,
          let secondaryUsed = secondary["used_percent"] as? Double
    else {
        return nil
    }

    return (
        timestamp: timestamp,
        primary: primaryUsed,
        secondary: secondaryUsed,
        primaryWindow: primary["window_minutes"] as? Int,
        secondaryWindow: secondary["window_minutes"] as? Int
    )
}

private func estimateFromSessionFiles(_ files: [URL]) -> (dailyUsed: Double, weeklyUsed: Double) {
    let now = Date()
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: now)
    let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
    var bytesToday: Int64 = 0
    var bytesThisWeek: Int64 = 0

    for file in files.prefix(80) {
        guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
              let modified = values.contentModificationDate
        else {
            continue
        }

        let size = Int64(values.fileSize ?? 0)

        if modified >= startOfDay {
            bytesToday += size
        }

        if modified >= weekAgo {
            bytesThisWeek += size
        }
    }

    return (
        dailyUsed: min(95, Double(bytesToday) / 8_000_000 * 100),
        weeklyUsed: min(95, Double(bytesThisWeek) / 42_000_000 * 100)
    )
}

private func readTail(of file: URL, maxBytes: UInt64) throws -> String {
    let handle = try FileHandle(forReadingFrom: file)
    defer { try? handle.close() }

    let size = try handle.seekToEnd()
    let offset = size > maxBytes ? size - maxBytes : 0
    try handle.seek(toOffset: offset)
    let data = try handle.readToEnd() ?? Data()

    return String(decoding: data, as: UTF8.self)
}
