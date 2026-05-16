import XCTest
@testable import CodexGauge

final class LeaderboardScoringTests: XCTestCase {
    func testBuildEfficiencyScoreMultipliesRatioByOneHundred() {
        let person = LeaderboardPerson(displayName: "Jake", githubProfile: "jake", manualWeeklyCodexBurnedPercent: 40)
        let activity = GitHubActivitySummary(
            username: "jake",
            commitActivityCount: 13,
            pullRequestsOpened: 2,
            issuesOpened: 1,
            issuesClosed: 0,
            activeContributionDays: 1,
            fetchedAt: Date()
        )

        let score = BuildEfficiencyScore(
            person: person,
            activity: activity,
            codexBurnedPercent: 40,
            errorMessage: nil
        )

        XCTAssertEqual(activity.activityPoints, 20)
        XCTAssertEqual(score.roundedScore, 50)
    }

    func testGitHubUsernameNormalizationSupportsProfileURLsAndHandles() {
        XCTAssertEqual(
            LeaderboardPerson.normalizedGitHubUsername(from: "https://github.com/jakobdsavage-afk"),
            "jakobdsavage-afk"
        )
        XCTAssertEqual(
            LeaderboardPerson.normalizedGitHubUsername(from: "github.com/jakobdsavage-afk"),
            "jakobdsavage-afk"
        )
        XCTAssertEqual(LeaderboardPerson.normalizedGitHubUsername(from: "@octocat"), "octocat")
        XCTAssertEqual(LeaderboardPerson.normalizedGitHubUsername(from: " octocat "), "octocat")
        XCTAssertEqual(LeaderboardPerson.normalizedGitHubUsername(from: "octocat/projects"), "octocat")
    }

    func testSharedLeaderboardPersonCanDecodeWithoutIdOrCodexBurnedPercent() throws {
        let data = """
        {
          "displayName": "Dad",
          "githubProfile": "github.com/octocat",
          "codexUsageMode": "manual"
        }
        """.data(using: .utf8)!

        let person = try JSONDecoder().decode(LeaderboardPerson.self, from: data)

        XCTAssertFalse(person.id.uuidString.isEmpty)
        XCTAssertEqual(person.displayName, "Dad")
        XCTAssertEqual(person.githubUsername, "octocat")
        XCTAssertNil(person.manualWeeklyCodexBurnedPercent)
    }

    func testSharedLeaderboardMissingIdDecodesStableIdentifier() throws {
        let data = """
        {
          "displayName": "Dad",
          "githubProfile": "github.com/octocat",
          "codexUsageMode": "manual"
        }
        """.data(using: .utf8)!

        let first = try JSONDecoder().decode(LeaderboardPerson.self, from: data)
        let second = try JSONDecoder().decode(LeaderboardPerson.self, from: data)

        XCTAssertEqual(first.id, second.id)
    }
}
