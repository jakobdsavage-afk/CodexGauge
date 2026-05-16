import Foundation

struct GitHubActivitySummary: Equatable {
    let username: String
    let commitActivityCount: Int
    let pullRequestsOpened: Int
    let issuesOpened: Int
    let issuesClosed: Int
    let activeContributionDays: Int
    let fetchedAt: Date

    var activityPoints: Int {
        commitActivityCount
            + pullRequestsOpened * 3
            + issuesClosed * 2
            + activeContributionDays
    }

    static func empty(username: String, fetchedAt: Date = Date()) -> GitHubActivitySummary {
        GitHubActivitySummary(
            username: username,
            commitActivityCount: 0,
            pullRequestsOpened: 0,
            issuesOpened: 0,
            issuesClosed: 0,
            activeContributionDays: 0,
            fetchedAt: fetchedAt
        )
    }
}
