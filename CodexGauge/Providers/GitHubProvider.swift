import Foundation

struct GitHubProvider: Sendable {
    var token: String?

    func fetchWeeklyActivity(for username: String) async throws -> GitHubActivitySummary {
        let cleanUsername = LeaderboardPerson.normalizedGitHubUsername(from: username)
        guard !cleanUsername.isEmpty else {
            throw GitHubProviderError.missingUsername
        }

        guard let url = URL(string: "https://api.github.com/users/\(cleanUsername)/events/public?per_page=100") else {
            throw GitHubProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CodexGauge-BuildEfficiency", forHTTPHeaderField: "User-Agent")

        if let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubProviderError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 403:
            throw GitHubProviderError.rateLimited
        case 404:
            throw GitHubProviderError.userNotFound(cleanUsername)
        default:
            throw GitHubProviderError.requestFailed(httpResponse.statusCode)
        }

        let events = try JSONDecoder.github.decode([GitHubPublicEvent].self, from: data)
        return summarize(events: events, username: cleanUsername)
    }

    private func summarize(events: [GitHubPublicEvent], username: String) -> GitHubActivitySummary {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        var commitActivityCount = 0
        var pullRequestsOpened = 0
        var issuesOpened = 0
        var issuesClosed = 0
        var activeDays = Set<DateComponents>()

        for event in events where event.createdAt >= weekStart {
            activeDays.insert(calendar.dateComponents([.year, .month, .day], from: event.createdAt))

            switch event.type {
            case "PushEvent":
                commitActivityCount += max(event.payload.commits?.count ?? 0, 1)
            case "PullRequestEvent" where event.payload.action == "opened":
                pullRequestsOpened += 1
            case "IssuesEvent" where event.payload.action == "opened":
                issuesOpened += 1
            case "IssuesEvent" where event.payload.action == "closed":
                issuesClosed += 1
            default:
                continue
            }
        }

        return GitHubActivitySummary(
            username: username,
            commitActivityCount: commitActivityCount,
            pullRequestsOpened: pullRequestsOpened,
            issuesOpened: issuesOpened,
            issuesClosed: issuesClosed,
            activeContributionDays: activeDays.count,
            fetchedAt: now
        )
    }
}

enum GitHubProviderError: LocalizedError, Equatable {
    case missingUsername
    case invalidURL
    case invalidResponse
    case rateLimited
    case userNotFound(String)
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .missingUsername:
            return "Add a GitHub username first."
        case .invalidURL, .invalidResponse:
            return "GitHub did not send back activity in a shape Codex Gauge could read."
        case .rateLimited:
            return "GitHub's public API limit was hit. Take a breather, then try again."
        case .userNotFound(let username):
            return "GitHub user \(username) was not found."
        case .requestFailed(let statusCode):
            return "GitHub activity request failed with HTTP \(statusCode)."
        }
    }
}

private struct GitHubPublicEvent: Decodable {
    let type: String
    let createdAt: Date
    let payload: Payload

    enum CodingKeys: String, CodingKey {
        case type
        case createdAt = "created_at"
        case payload
    }

    struct Payload: Decodable {
        let action: String?
        let commits: [Commit]?
    }

    struct Commit: Decodable {}
}

private extension JSONDecoder {
    static var github: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
