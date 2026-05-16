import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var refreshService: UsageRefreshService
    @EnvironmentObject private var store: LeaderboardStore

    @State private var scores: [UUID: BuildEfficiencyScore] = [:]
    @State private var sharedPeople: [LeaderboardPerson] = []
    @State private var hasLoadedSharedPeople = false
    @State private var isRefreshing = false
    @State private var needsRefreshAfterCurrentRun = false
    @State private var activeSheet: LeaderboardSheet?
    @State private var statusMessage = "Approximate score based on public GitHub activity."

    private let githubProvider = GitHubProvider()
    private let sharedLeaderboardProvider = SharedLeaderboardProvider()

    var body: some View {
        let palette = NotebookTheme.palette(for: preferences.theme)

        ZStack {
            SketchBackground(phase: Date().timeIntervalSinceReferenceDate)

            VStack(alignment: .leading, spacing: 16) {
                header(palette: palette)

                if leaderboardPeople.isEmpty && !hasLoadedSharedPeople {
                    loadingState(palette: palette)
                } else if leaderboardPeople.isEmpty {
                    emptyState(palette: palette)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(rankedScores.enumerated()), id: \.element.id) { index, score in
                                scoreRow(score, rank: index + 1, palette: palette)
                            }
                        }
                        .padding(.trailing, 4)
                    }
                }

                footer(palette: palette)
            }
            .padding(28)
        }
        .frame(width: 560, height: 430)
        .sheet(item: $activeSheet) { sheet in
            LeaderboardSettingsView(person: sheet.person) { person in
                savePersonAndRefresh(person)
            }
            .environmentObject(preferences)
        }
        .task {
            await refreshScores()
        }
    }

    private var rankedScores: [BuildEfficiencyScore] {
        leaderboardPeople
            .map(score(for:))
            .sorted { left, right in
                switch (left.scoreValue, right.scoreValue) {
                case let (left?, right?):
                    return left > right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return left.person.displayName.localizedCaseInsensitiveCompare(right.person.displayName) == .orderedAscending
                }
            }
    }

    private func header(palette: NotebookPalette) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Build Efficiency Leaderboard")
                    .notebookFont(size: 28, weight: .bold, handwritten: preferences.useHandwrittenFont)
                    .foregroundStyle(palette.brightInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("Shipped vs Burned")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.dimInk)
            }

            Spacer()

            Button {
                activeSheet = .add
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(SketchPlainTextButtonStyle(palette: palette))

            Button {
                Task { await refreshScores() }
            } label: {
                Image(systemName: isRefreshing ? "hourglass" : "arrow.clockwise")
            }
            .buttonStyle(SketchIconButtonStyle())
            .help("Refresh leaderboard")
        }
    }

    private func loadingState(palette: NotebookPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(palette.brightInk)

            Text("Loading shared builders...")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.ink.opacity(0.9))

            Text("Pulling the friendly build duel list from GitHub.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.dimInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func emptyState(palette: NotebookPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "crown")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(palette.brightInk)

            Text("Add Jake, Dad, or whoever is in the weekly build duel.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.ink.opacity(0.9))

            Text("Shared builders come from leaderboard.json. Local additions stay on this Mac.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.dimInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func scoreRow(_ score: BuildEfficiencyScore, rank: Int, palette: NotebookPalette) -> some View {
        let isWinner = rank == 1 && score.isScorable

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: isWinner ? "crown.fill" : "\(rank).circle")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isWinner ? palette.brightInk : palette.dimInk)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(score.person.displayName)
                        .notebookFont(size: 20, weight: .bold, handwritten: preferences.useHandwrittenFont)
                        .foregroundStyle(palette.brightInk)

                    Text("@\(score.person.githubUsername)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.dimInk)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(score.roundedScore.map { "Score \($0)" } ?? "Score --")
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(palette.brightInk)

                    Text(isWinner ? "Weekly Winner" : "AI Fuel Score")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.dimInk)
                }
            }

            HStack(spacing: 13) {
                metric("GitHub", "\(score.activityPoints) pts", palette: palette)
                metric("Codex burned", codexBurnedText(for: score), palette: palette)

                if let activity = score.activity {
                    metric("PRs", "\(activity.pullRequestsOpened)", palette: palette)
                    metric("Closed", "\(activity.issuesClosed)", palette: palette)
                    metric("Days", "\(activity.activeContributionDays)", palette: palette)
                }
            }

            if let errorMessage = score.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.ink.opacity(0.70))
            }
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(palette.paperGroove.opacity(0.62))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(palette.ink.opacity(isWinner ? 0.50 : 0.22), lineWidth: isWinner ? 1.25 : 0.8)
                }
        }
        .contextMenu {
            Button("Edit") {
                activeSheet = .edit(score.person)
            }

            Button("Delete") {
                store.delete(score.person)
                scores[score.person.id] = nil
            }
            .disabled(!isLocalPerson(score.person))
        }
    }

    private func metric(_ label: String, _ value: String, palette: NotebookPalette) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(palette.dimInk)

            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(palette.ink.opacity(0.9))
        }
    }

    private func codexBurnedText(for score: BuildEfficiencyScore) -> String {
        guard let codexBurnedPercent = score.codexBurnedPercent else {
            return isLocalPerson(score.person) ? "Add %" : "Fuel TBD"
        }

        return "\(Int(codexBurnedPercent.rounded()))%"
    }

    private func footer(palette: NotebookPalette) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "info.circle")
                .foregroundStyle(palette.dimInk)

            Text(statusMessage)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.dimInk)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer()

            Text("Build Efficiency = GitHub pts / Codex burned")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(palette.ink.opacity(0.62))
                .lineLimit(1)
        }
    }

    private func refreshScores() async {
        guard !isRefreshing else {
            needsRefreshAfterCurrentRun = true
            return
        }

        isRefreshing = true
        defer {
            isRefreshing = false
            if needsRefreshAfterCurrentRun {
                needsRefreshAfterCurrentRun = false
                Task { await refreshScores() }
            }
        }

        if refreshService.snapshot.providerStatus == .loading {
            await refreshService.refreshNow()
        }

        var sharedLoadFailed = false
        do {
            sharedPeople = try await sharedLeaderboardProvider.fetchPeople()
        } catch {
            sharedLoadFailed = true
        }
        hasLoadedSharedPeople = true

        var nextScores: [UUID: BuildEfficiencyScore] = [:]

        for person in leaderboardPeople {
            guard person.canFetchGitHubActivity else {
                nextScores[person.id] = BuildEfficiencyScore(
                    person: person,
                    activity: nil,
                    codexBurnedPercent: codexBurnedPercent(for: person),
                    errorMessage: "Add a GitHub username to score this builder."
                )
                continue
            }

            do {
                let activity = try await githubProvider.fetchWeeklyActivity(for: person.githubUsername)
                nextScores[person.id] = BuildEfficiencyScore(
                    person: person,
                    activity: activity,
                    codexBurnedPercent: codexBurnedPercent(for: person),
                    errorMessage: nil
                )
            } catch {
                nextScores[person.id] = BuildEfficiencyScore(
                    person: person,
                    activity: nil,
                    codexBurnedPercent: codexBurnedPercent(for: person),
                    errorMessage: (error as? LocalizedError)?.errorDescription ?? "Could not read public GitHub activity."
                )
            }
        }

        scores = nextScores
        statusMessage = sharedLoadFailed
            ? "Using local leaderboard list. Shared list could not load."
            : "Approximate score based on public GitHub activity."
    }

    private func savePersonAndRefresh(_ person: LeaderboardPerson) {
        store.upsert(person)
        scores[person.id] = placeholderScore(for: person, message: "Fetching public GitHub activity...")
        Task { await refreshScores() }
    }

    private func score(for person: LeaderboardPerson) -> BuildEfficiencyScore {
        if let existing = scores[person.id] {
            return BuildEfficiencyScore(
                person: person,
                activity: existing.activity,
                codexBurnedPercent: codexBurnedPercent(for: person),
                errorMessage: existing.errorMessage
            )
        }

        return placeholderScore(for: person, message: nil)
    }

    private func placeholderScore(for person: LeaderboardPerson, message: String?) -> BuildEfficiencyScore {
        BuildEfficiencyScore(
            person: person,
            activity: nil,
            codexBurnedPercent: codexBurnedPercent(for: person),
            errorMessage: message
        )
    }

    private var leaderboardPeople: [LeaderboardPerson] {
        var merged: [LeaderboardPerson] = []
        var seenKeys = Set<String>()

        for person in store.people + sharedPeople {
            let key = mergeKey(for: person)
            guard !seenKeys.contains(key) else {
                continue
            }

            merged.append(person)
            seenKeys.insert(key)
        }

        return merged
    }

    private func isLocalPerson(_ person: LeaderboardPerson) -> Bool {
        store.people.contains { mergeKey(for: $0) == mergeKey(for: person) }
    }

    private func mergeKey(for person: LeaderboardPerson) -> String {
        let username = person.githubUsername.lowercased()
        if !username.isEmpty {
            return "github:\(username)"
        }

        return "id:\(person.id.uuidString)"
    }

    private func codexBurnedPercent(for person: LeaderboardPerson) -> Double? {
        switch person.codexUsageMode {
        case .localGauge:
            return refreshService.snapshot.weeklyUsagePercent
        case .manual:
            return person.manualWeeklyCodexBurnedPercent
        }
    }
}

private enum LeaderboardSheet: Identifiable {
    case add
    case edit(LeaderboardPerson)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let person):
            return "edit-\(person.id.uuidString)"
        }
    }

    var person: LeaderboardPerson? {
        switch self {
        case .add:
            return nil
        case .edit(let person):
            return person
        }
    }
}
