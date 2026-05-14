import Foundation

let home = FileManager.default.homeDirectoryForCurrentUser
let codexRoot = home.appendingPathComponent(".codex", isDirectory: true)
let sessionsRoot = codexRoot.appendingPathComponent("sessions", isDirectory: true)
let logsDatabase = codexRoot.appendingPathComponent("logs_2.sqlite")

print("Codex Gauge Probe")

let files = sessionFiles(in: sessionsRoot)

if let accountUsage = await latestAccountUsageObservation(codexRoot: codexRoot) {
    printObservation(accountUsage, status: "codex-account-usage-api")
} else {
    let observations = [
        latestLogObservation(database: logsDatabase).map { ($0, "real-websocket-log") },
        latestSessionObservation(files: files).map { ($0, "real-session-snapshot") }
    ].compactMap { $0 }

    if let newest = observations.max(by: { $0.0.date < $1.0.date }) {
        printObservation(newest.0, status: newest.1)
    } else {
        print("status: unavailable")
        print("session_files: \(files.count)")
        print("reason: no Codex rate-limit telemetry found; not estimating usage percentages")
    }
}

typealias Observation = (timestamp: String, date: Date, primary: Double, secondary: Double, primaryWindow: Int?, secondaryWindow: Int?)

private func latestAccountUsageObservation(codexRoot: URL) async -> Observation? {
    guard let accessToken = readAccessToken(codexRoot: codexRoot),
          let url = URL(string: "https://chatgpt.com/backend-api/wham/usage")
    else {
        return nil
    }

    var request = URLRequest(url: url)
    request.timeoutInterval = 5
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("CodexGaugeProbe", forHTTPHeaderField: "User-Agent")

    guard let (data, response) = try? await URLSession.shared.data(for: request),
          let httpResponse = response as? HTTPURLResponse,
          (200..<300).contains(httpResponse.statusCode),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let rateLimit = root["rate_limit"] as? [String: Any],
          let primary = rateLimit["primary_window"] as? [String: Any],
          let secondary = rateLimit["secondary_window"] as? [String: Any],
          let primaryUsed = number(primary["used_percent"]),
          let secondaryUsed = number(secondary["used_percent"])
    else {
        return nil
    }

    let now = Date()
    return (
        timestamp: ISO8601DateFormatter().string(from: now),
        date: now,
        primary: primaryUsed,
        secondary: secondaryUsed,
        primaryWindow: number(primary["limit_window_seconds"]).map { Int(($0 / 60).rounded()) },
        secondaryWindow: number(secondary["limit_window_seconds"]).map { Int(($0 / 60).rounded()) }
    )
}

private func readAccessToken(codexRoot: URL) -> String? {
    let authFile = codexRoot.appendingPathComponent("auth.json")
    guard let data = try? Data(contentsOf: authFile),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tokens = root["tokens"] as? [String: Any],
          let accessToken = tokens["access_token"] as? String,
          !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
        return nil
    }

    return accessToken
}

private func number(_ value: Any?) -> Double? {
    switch value {
    case let value as Double:
        return value
    case let value as Int:
        return Double(value)
    case let value as NSNumber:
        return value.doubleValue
    default:
        return nil
    }
}

private func latestLogObservation(database: URL) -> Observation? {
    guard FileManager.default.fileExists(atPath: database.path) else {
        return nil
    }

    let query = """
    select ts || '|' || replace(coalesce(feedback_log_body, ''), char(10), ' ')
    from logs
    where feedback_log_body like '%websocket event:%codex.rate_limits%'
    order by ts desc
    limit 40;
    """

    guard let output = runSQLite(database: database, query: query) else {
        return nil
    }

    for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
        let pieces = line.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard pieces.count == 2 else {
            continue
        }

        let timestamp = String(pieces[0])
        let date = TimeInterval(timestamp).map { Date(timeIntervalSince1970: $0) } ?? .distantPast
        let body = String(pieces[1])

        guard let eventRange = body.range(of: "websocket event:"),
              let jsonStart = body[eventRange.upperBound...].firstIndex(of: "{"),
              let parsed = parseRateLimitJSON(extractJSONObject(from: body, startingAt: jsonStart), timestamp: timestamp, date: date)
        else {
            continue
        }

        return parsed
    }

    return nil
}

private func latestSessionObservation(files: [URL]) -> Observation? {
    var latest: Observation?

    for file in files.prefix(30) {
        guard let text = try? readTail(of: file, maxBytes: 15_000_000) else {
            continue
        }

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard line.contains("\"rate_limits\""),
                  let parsed = parseSessionLine(String(line))
            else {
                continue
            }

            if latest == nil || parsed.date > latest!.date {
                latest = parsed
            }
        }
    }

    return latest
}

private func parseSessionLine(_ line: String) -> Observation? {
    guard let data = line.data(using: .utf8),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let timestamp = root["timestamp"] as? String,
          let payload = root["payload"] as? [String: Any],
          payload["type"] as? String == "token_count"
    else {
        return nil
    }

    let directLimits = payload["rate_limits"] as? [String: Any]
    let infoLimits = (payload["info"] as? [String: Any])?["rate_limits"] as? [String: Any]

    guard let rateLimits = directLimits ?? infoLimits else {
        return nil
    }

    let date = parseISODate(timestamp) ?? .distantPast
    return parseRateLimitDictionary(rateLimits, timestamp: timestamp, date: date)
}

private func parseRateLimitJSON(_ json: String, timestamp: String, date: Date) -> Observation? {
    guard let data = json.data(using: .utf8),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let rateLimits = root["rate_limits"] as? [String: Any]
    else {
        return nil
    }

    return parseRateLimitDictionary(rateLimits, timestamp: timestamp, date: date)
}

private func parseRateLimitDictionary(_ rateLimits: [String: Any], timestamp: String, date: Date) -> Observation? {
    guard let primary = rateLimits["primary"] as? [String: Any],
          let secondary = rateLimits["secondary"] as? [String: Any],
          let primaryUsed = primary["used_percent"] as? Double,
          let secondaryUsed = secondary["used_percent"] as? Double
    else {
        return nil
    }

    return (
        timestamp: timestamp,
        date: date,
        primary: primaryUsed,
        secondary: secondaryUsed,
        primaryWindow: primary["window_minutes"] as? Int,
        secondaryWindow: secondary["window_minutes"] as? Int
    )
}

private func sessionFiles(in root: URL) -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    return enumerator
        .compactMap { $0 as? URL }
        .filter { $0.pathExtension == "jsonl" }
        .sorted { left, right in
            let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return leftDate > rightDate
        }
}

private func printObservation(_ observation: Observation, status: String) {
    let primaryLabel = windowLabel(for: observation.primaryWindow, fallback: "primary")
    let secondaryLabel = windowLabel(for: observation.secondaryWindow, fallback: "secondary")

    print("status: \(status)")
    print("\(primaryLabel)_remaining: \(Int((100 - observation.primary).rounded()))%")
    print("\(secondaryLabel)_remaining: \(Int((100 - observation.secondary).rounded()))%")
    print("source_timestamp: \(observation.timestamp)")
    print("windows: \(observation.primaryWindow.map(String.init) ?? "?")m / \(observation.secondaryWindow.map(String.init) ?? "?")m")
}

private func windowLabel(for minutes: Int?, fallback: String) -> String {
    guard let minutes else {
        return fallback
    }

    switch minutes {
    case 300:
        return "5h"
    case 10_080:
        return "weekly"
    case let value where value >= 1_440 && value % 1_440 == 0:
        return "\(value / 1_440)d"
    case let value where value >= 60 && value % 60 == 0:
        return "\(value / 60)h"
    default:
        return "\(minutes)m"
    }
}

private func parseISODate(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]

    return fractional.date(from: value) ?? plain.date(from: value)
}

private func runSQLite(database: URL, query: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = ["-readonly", database.path, query]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return nil
    }

    guard process.terminationStatus == 0 else {
        return nil
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
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

private func extractJSONObject(from body: String, startingAt start: String.Index) -> String {
    var depth = 0
    var isEscaped = false
    var isInsideString = false
    var end = start

    for index in body[start...].indices {
        let character = body[index]
        end = index

        if isEscaped {
            isEscaped = false
            continue
        }

        if character == "\\" {
            isEscaped = true
            continue
        }

        if character == "\"" {
            isInsideString.toggle()
            continue
        }

        guard !isInsideString else {
            continue
        }

        if character == "{" {
            depth += 1
        } else if character == "}" {
            depth -= 1

            if depth == 0 {
                break
            }
        }
    }

    return String(body[start...end])
}
