import Foundation

struct LeaderboardPerson: Identifiable, Codable, Equatable {
    var id: UUID
    var displayName: String
    var githubProfile: String
    var codexUsageMode: LeaderboardCodexUsageMode
    var manualWeeklyCodexBurnedPercent: Double?

    init(
        id: UUID = UUID(),
        displayName: String,
        githubProfile: String,
        codexUsageMode: LeaderboardCodexUsageMode = .manual,
        manualWeeklyCodexBurnedPercent: Double? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.githubProfile = githubProfile
        self.codexUsageMode = codexUsageMode
        self.manualWeeklyCodexBurnedPercent = manualWeeklyCodexBurnedPercent
    }

    var githubUsername: String {
        Self.normalizedGitHubUsername(from: githubProfile)
    }

    var canFetchGitHubActivity: Bool {
        !githubUsername.isEmpty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.githubProfile = try container.decode(String.self, forKey: .githubProfile)
        self.codexUsageMode = try container.decodeIfPresent(LeaderboardCodexUsageMode.self, forKey: .codexUsageMode) ?? .manual
        self.manualWeeklyCodexBurnedPercent = try container.decodeIfPresent(Double.self, forKey: .manualWeeklyCodexBurnedPercent)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id)
            ?? Self.stableID(displayName: displayName, githubProfile: githubProfile)
    }

    static func normalizedGitHubUsername(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        if let url = URL(string: trimmed), let host = url.host, host.contains("github.com") {
            return url.pathComponents
                .dropFirst()
                .first?
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                ?? ""
        }

        let stripped = trimmed
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: "http://github.com/", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "@/ "))

        if stripped.hasPrefix("github.com/") {
            return stripped
                .replacingOccurrences(of: "github.com/", with: "")
                .split(separator: "/")
                .first
                .map(String.init) ?? ""
        }

        return stripped
            .split(separator: "/")
            .first
            .map(String.init) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case githubProfile
        case codexUsageMode
        case manualWeeklyCodexBurnedPercent
    }

    private static func stableID(displayName: String, githubProfile: String) -> UUID {
        let key = normalizedGitHubUsername(from: githubProfile).isEmpty
            ? displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            : normalizedGitHubUsername(from: githubProfile).lowercased()
        let first = fnv1a64("codex-gauge-a:\(key)")
        let second = fnv1a64("codex-gauge-b:\(key)")
        let bytes = Array(first.bigEndianBytes + second.bigEndianBytes)

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func fnv1a64(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

private extension UInt64 {
    var bigEndianBytes: [UInt8] {
        withUnsafeBytes(of: bigEndian) { Array($0) }
    }
}

enum LeaderboardCodexUsageMode: String, Codable, CaseIterable, Identifiable {
    case localGauge
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localGauge:
            return "Use This Mac"
        case .manual:
            return "Manual %"
        }
    }
}
