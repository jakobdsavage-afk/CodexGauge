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
                dailyUsagePercent: 0,
                weeklyUsagePercent: 0,
                lastUpdated: Date(),
                providerStatus: .unavailable("No ~/.codex directory found."),
                isEstimated: true
            )
        }

        let sessionFiles = recentSessionFiles(in: sessionsRoot)

        if let exactSnapshot = latestRateLimitSnapshot(from: sessionFiles) {
            return exactSnapshot
        }

        return estimatedSnapshot(from: sessionFiles)
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

        let primaryWindow = observation.primaryWindowMinutes.map { "\($0)m" } ?? "primary"
        let secondaryWindow = observation.secondaryWindowMinutes.map { "\($0)m" } ?? "secondary"
        let status = "Local Codex rate-limit snapshot (\(primaryWindow) / \(secondaryWindow))."

        return UsageSnapshot(
            dailyUsagePercent: UsageSnapshot.clampPercent(observation.primaryUsedPercent),
            weeklyUsagePercent: UsageSnapshot.clampPercent(observation.secondaryUsedPercent),
            lastUpdated: observation.timestamp,
            providerStatus: .exact(status),
            isEstimated: false
        )
    }

    private func estimatedSnapshot(from files: [URL]) -> UsageSnapshot {
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        var bytesToday: Int64 = 0
        var bytesThisWeek: Int64 = 0
        var newestDate: Date?

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

            if newestDate == nil || modified > newestDate! {
                newestDate = modified
            }
        }

        // Codex does not publish an official quota denominator in plain local
        // files. This fallback therefore estimates pressure from real local
        // session activity volume and labels the result as estimated.
        let dailyUsed = min(95, Double(bytesToday) / 8_000_000 * 100)
        let weeklyUsed = min(95, Double(bytesThisWeek) / 42_000_000 * 100)
        let fileCount = files.count

        return UsageSnapshot(
            dailyUsagePercent: UsageSnapshot.clampPercent(dailyUsed),
            weeklyUsagePercent: UsageSnapshot.clampPercent(weeklyUsed),
            lastUpdated: newestDate ?? now,
            providerStatus: .estimated("Estimated from \(fileCount) Codex session file\(fileCount == 1 ? "" : "s")."),
            isEstimated: true
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
}
