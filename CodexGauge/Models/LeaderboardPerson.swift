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

        return trimmed
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: "http://github.com/", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "@/ "))
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
