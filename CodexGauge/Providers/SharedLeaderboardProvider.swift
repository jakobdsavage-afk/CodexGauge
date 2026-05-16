import Foundation

struct SharedLeaderboardProvider: Sendable {
    var url: URL = URL(string: "https://api.github.com/repos/jakobdsavage-afk/CodexGauge/contents/leaderboard.json?ref=main")!

    func fetchPeople() async throws -> [LeaderboardPerson] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CodexGauge-SharedLeaderboard", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw SharedLeaderboardError.unavailable
        }

        let responseFile = try JSONDecoder().decode(GitHubContentsFile.self, from: data)
        let base64Content = responseFile.content
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let fileData = Data(base64Encoded: base64Content) else {
            throw SharedLeaderboardError.unavailable
        }

        return try JSONDecoder().decode(SharedLeaderboardFile.self, from: fileData).people
    }
}

enum SharedLeaderboardError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Could not load the shared Builder Board list right now."
    }
}

private struct SharedLeaderboardFile: Decodable {
    let people: [LeaderboardPerson]
}

private struct GitHubContentsFile: Decodable {
    let content: String
}
