import Foundation

struct BuildEfficiencyScore: Identifiable, Equatable {
    let person: LeaderboardPerson
    let activity: GitHubActivitySummary?
    let codexBurnedPercent: Double?
    let errorMessage: String?

    var id: UUID { person.id }

    var activityPoints: Int {
        activity?.activityPoints ?? 0
    }

    var scoreValue: Double? {
        guard let codexBurnedPercent else {
            return nil
        }

        return Double(activityPoints) / max(codexBurnedPercent, 1) * 100
    }

    var roundedScore: Int? {
        scoreValue.map { Int($0.rounded()) }
    }

    var isScorable: Bool {
        roundedScore != nil && activity != nil
    }
}
