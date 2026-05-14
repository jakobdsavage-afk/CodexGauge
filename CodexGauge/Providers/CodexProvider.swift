import Foundation

struct CodexProvider: UsageProvider, @unchecked Sendable {
    private let fileManager: FileManager
    private let homeDirectory: URL
    private let parser: CodexSessionRateLimitParser

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        parser: CodexSessionRateLimitParser = CodexSessionRateLimitParser()
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
        self.parser = parser
    }

    func fetchUsage() async -> UsageSnapshot {
        let codexRoot = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        let sessionsRoot = codexRoot.appendingPathComponent("sessions", isDirectory: true)

        guard fileManager.fileExists(atPath: codexRoot.path) else {
            return UsageSnapshot(
                dailyUsagePercent: nil,
                weeklyUsagePercent: nil,
                lastUpdated: Date(),
                providerStatus: .unavailable("No ~/.codex directory found.")
            )
        }

        let sessionFiles = recentSessionFiles(in: sessionsRoot)
        let exactSnapshots = [
            latestRateLimitSnapshotFromLogs(in: codexRoot),
            latestRateLimitSnapshot(from: sessionFiles)
        ].compactMap { $0 }

        if let exactSnapshot = exactSnapshots.max(by: { $0.lastUpdated < $1.lastUpdated }) {
            return exactSnapshot
        }

        return unavailableSnapshot(sessionCount: sessionFiles.count)
    }

    private func latestRateLimitSnapshotFromLogs(in codexRoot: URL) -> UsageSnapshot? {
        let database = codexRoot.appendingPathComponent("logs_2.sqlite")
        guard fileManager.fileExists(atPath: database.path) else {
            return nil
        }

        let query = """
        select ts || '|' || replace(coalesce(feedback_log_body, ''), char(10), ' ')
        from logs
        where feedback_log_body like '%websocket event: {"type":"codex.rate_limits"%'
        order by ts desc
        limit 40;
        """

        guard let output = runSQLite(database: database, query: query) else {
            return nil
        }

        var newest: CodexRateLimitObservation?

        output.enumerateLines { line, _ in
            let pieces = line.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard pieces.count == 2,
                  let timestampSeconds = TimeInterval(pieces[0])
            else {
                return
            }

            let timestamp = Date(timeIntervalSince1970: timestampSeconds)
            let body = String(pieces[1])
            guard let observation = parser.observation(fromLogBody: body, timestamp: timestamp) else {
                return
            }

            if newest == nil || observation.timestamp > newest!.timestamp {
                newest = observation
            }
        }

        guard let observation = newest else {
            return nil
        }

        return snapshot(from: observation, source: "Live Codex websocket rate-limit log")
    }

    private func latestRateLimitSnapshot(from files: [URL]) -> UsageSnapshot? {
        var newest: CodexRateLimitObservation?

        for file in files.prefix(30) {
            guard let tail = try? readTail(of: file, maxBytes: 15_000_000) else {
                continue
            }

            tail.enumerateLines { line, _ in
                guard let observation = parser.observation(fromJSONLine: line) else {
                    return
                }

                if newest == nil || observation.timestamp > newest!.timestamp {
                    newest = observation
                }
            }
        }

        guard let observation = newest else {
            return nil
        }

        return snapshot(from: observation, source: "Codex session rate-limit snapshot")
    }

    private func snapshot(from observation: CodexRateLimitObservation, source: String) -> UsageSnapshot {
        let primaryWindow = observation.primaryWindowMinutes.map { "\($0)m" } ?? "primary"
        let secondaryWindow = observation.secondaryWindowMinutes.map { "\($0)m" } ?? "secondary"
        let status = "\(source) (\(primaryWindow) / \(secondaryWindow))."

        return UsageSnapshot(
            dailyUsagePercent: UsageSnapshot.clampPercent(observation.primaryUsedPercent),
            weeklyUsagePercent: UsageSnapshot.clampPercent(observation.secondaryUsedPercent),
            lastUpdated: observation.timestamp,
            providerStatus: .exact(status)
        )
    }

    private func unavailableSnapshot(sessionCount: Int) -> UsageSnapshot {
        return UsageSnapshot(
            dailyUsagePercent: nil,
            weeklyUsagePercent: nil,
            lastUpdated: Date(),
            providerStatus: .unavailable("No Codex rate-limit telemetry found in logs or \(sessionCount) session file\(sessionCount == 1 ? "" : "s").")
        )
    }

    private func recentSessionFiles(in root: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let urls = enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "jsonl" }

        return urls.sorted { left, right in
            let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return leftDate > rightDate
        }
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
}
