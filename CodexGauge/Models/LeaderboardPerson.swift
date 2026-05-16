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
        codexUsageMode: LeaderboardCodexUsageMode = .localGauge,
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

    func withCodexUsage(mode: LeaderboardCodexUsageMode, manualPercent: Double?) -> LeaderboardPerson {
        LeaderboardPerson(
            id: id,
            displayName: displayName,
            githubProfile: githubProfile,
            codexUsageMode: mode,
            manualWeeklyCodexBurnedPercent: manualPercent
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.githubProfile = try container.decode(String.self, forKey: .githubProfile)
        self.codexUsageMode = try container.decodeIfPresent(LeaderboardCodexUsageMode.self, forKey: .codexUsageMode) ?? .localGauge
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

struct LocalDeveloperIdentity: Equatable {
    var githubUsername: String?
    var displayName: String?

    static func current(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> LocalDeveloperIdentity {
        let ghHosts = readText(at: homeDirectory.appendingPathComponent(".config/gh/hosts.yml"))
        let ghConfig = readText(at: homeDirectory.appendingPathComponent(".config/gh/config.yml"))
        let gitConfig = readText(at: homeDirectory.appendingPathComponent(".gitconfig"))

        return LocalDeveloperIdentity(
            githubUsername: githubUsername(fromGitHubHostsYAML: ghHosts)
                ?? githubUsername(fromGitHubConfigYAML: ghConfig)
                ?? githubUsername(fromGitConfig: gitConfig),
            displayName: displayName(fromGitConfig: gitConfig)
        )
    }

    static func githubUsername(fromGitHubHostsYAML text: String?) -> String? {
        guard let text else {
            return nil
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("user:") else {
                continue
            }

            let value = line
                .replacingOccurrences(of: "user:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !value.isEmpty {
                return LeaderboardPerson.normalizedGitHubUsername(from: value)
            }
        }

        return nil
    }

    static func githubUsername(fromGitHubConfigYAML text: String?) -> String? {
        guard let text else {
            return nil
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("user:") || line.hasPrefix("username:") else {
                continue
            }

            let value = line
                .components(separatedBy: ":")
                .dropFirst()
                .joined(separator: ":")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !value.isEmpty {
                return LeaderboardPerson.normalizedGitHubUsername(from: value)
            }
        }

        return nil
    }

    static func githubUsername(fromGitConfig text: String?) -> String? {
        value(named: "user", inSection: "github", fromGitConfig: text)
            ?? value(named: "username", inSection: "github", fromGitConfig: text)
    }

    static func displayName(fromGitConfig text: String?) -> String? {
        value(named: "name", inSection: "user", fromGitConfig: text)
    }

    private static func value(named key: String, inSection section: String, fromGitConfig text: String?) -> String? {
        guard let text else {
            return nil
        }

        var activeSection = ""
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if line.hasPrefix("[") && line.hasSuffix("]") {
                activeSection = line
                    .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    .split(separator: " ")
                    .first
                    .map(String.init) ?? ""
                continue
            }

            guard activeSection == section,
                  let separator = line.firstIndex(of: "=")
            else {
                continue
            }

            let name = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            guard name == key else {
                continue
            }

            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }

        return nil
    }

    private static func readText(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }
}

struct LeaderboardFuelResolver {
    let snapshot: UsageSnapshot
    let localIdentity: LocalDeveloperIdentity

    func burnedPercent(for person: LeaderboardPerson) -> Double? {
        if usesLocalFuel(for: person) {
            return snapshot.weeklyUsagePercent
        }

        return person.manualWeeklyCodexBurnedPercent
    }

    func usesLocalFuel(for person: LeaderboardPerson) -> Bool {
        if person.codexUsageMode == .localGauge {
            return true
        }

        guard person.manualWeeklyCodexBurnedPercent == nil else {
            return false
        }

        return matchesLocalIdentity(person)
    }

    func matchesLocalIdentity(_ person: LeaderboardPerson) -> Bool {
        let personUsername = person.githubUsername.lowercased()
        if let localUsername = localIdentity.githubUsername?.lowercased(),
           !localUsername.isEmpty,
           personUsername == localUsername {
            return true
        }

        if let localName = localIdentity.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !localName.isEmpty,
           person.displayName.caseInsensitiveCompare(localName) == .orderedSame {
            return true
        }

        return false
    }
}
