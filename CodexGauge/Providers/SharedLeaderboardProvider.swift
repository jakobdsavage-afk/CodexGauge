import Foundation

struct SharedLeaderboardProvider: Sendable {
    var url: URL = URL(string: "https://raw.githubusercontent.com/jakobdsavage-afk/CodexGauge/main/leaderboard.json")!

    func fetchPeople() async throws -> [LeaderboardPerson] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CodexGauge-SharedLeaderboard", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw SharedLeaderboardError.unavailable
        }

        return try JSONDecoder().decode(SharedLeaderboardFile.self, from: data).people
    }
}

enum SharedLeaderboardError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Could not load the shared leaderboard list right now."
    }
}

private struct SharedLeaderboardFile: Decodable {
    let people: [LeaderboardPerson]
}
