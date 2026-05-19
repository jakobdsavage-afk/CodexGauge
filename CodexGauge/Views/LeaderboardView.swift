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
    @State private var localIdentity = LocalDeveloperIdentity.current()

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
            LeaderboardSettingsView(
                person: sheet.person,
                title: sheet.title,
                localCodexBurnedPercent: refreshService.snapshot.weeklyUsagePercent,
                showsFuelControls: sheet.showsFuelControls
            ) { person in
                savePersonAndRefresh(person)
            }
            .environmentObject(preferences)
        }
        .task {
            localIdentity = LocalDeveloperIdentity.current()
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
                Text("Builder Board")
                    .notebookFont(size: 28, weight: .bold, handwritten: preferences.useHandwrittenFont)
                    .foregroundStyle(palette.brightInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("This Week")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.dimInk)
            }

            Spacer()

            Button {
                activeSheet = .myGitHub(localProfileDraft)
            } label: {
                Label(localProfile == nil ? "Set My GitHub" : "My GitHub", systemImage: "person.crop.circle")
            }
            .buttonStyle(SketchPlainTextButtonStyle(palette: palette))
            .help("Set the GitHub username for this Mac")

            Button {
                Task { await refreshScores() }
            } label: {
                Image(systemName: isRefreshing ? "hourglass" : "arrow.clockwise")
            }
            .buttonStyle(SketchIconButtonStyle())
            .help("Refresh Builder Board")

            Button {
                closeLeaderboardWindow()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(SketchIconButtonStyle())
            .help("Close Builder Board")
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

            Text("Set your GitHub username to join this Mac's Builder Board.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.ink.opacity(0.9))

            Text("Codex fuel is automatic from this Mac. GitHub activity stays public and approximate.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.dimInk)

            Button("Set My GitHub") {
                activeSheet = .myGitHub(localProfileDraft)
            }
            .buttonStyle(SketchPlainTextButtonStyle(palette: palette))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func scoreRow(_ score: BuildEfficiencyScore, rank: Int, palette: NotebookPalette) -> some View {
        let isWinner = rank == 1 && score.isScorable && score.activityPoints > 0

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

                    Text(scoreBadgeText(for: score, isWinner: isWinner))
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

            if score.codexBurnedPercent == nil {
                missingFuelNote(for: score, palette: palette)
            } else if fuelResolver.usesLocalFuel(for: score.person) {
                Text("Codex fuel is being read automatically from this Mac.")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.dimInk)
            }

            if score.isScorable && score.activityPoints == 0 {
                Text("No public GitHub output found in the last 7 days.")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.dimInk)
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

    private func missingFuelNote(for score: BuildEfficiencyScore, palette: NotebookPalette) -> some View {
        HStack(spacing: 8) {
            Text(missingFuelText(for: score))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(palette.dimInk)

            Spacer()

            if canUseThisMacFuel(for: score.person), refreshService.snapshot.weeklyUsagePercent != nil {
                Button("Use This Mac") {
                    savePersonAndRefresh(score.person.withCodexUsage(mode: .localGauge, manualPercent: nil))
                }
                .buttonStyle(SketchPlainTextButtonStyle(palette: palette))
                .help("Use this Mac's current weekly Codex burned percent")
            }

            if canUseThisMacFuel(for: score.person) {
                Button("Set Fuel") {
                    activeSheet = .edit(score.person.withCodexUsage(mode: .manual, manualPercent: nil))
                }
                .buttonStyle(SketchPlainTextButtonStyle(palette: palette))
            }
        }
        .padding(.top, 2)
    }

    private func scoreBadgeText(for score: BuildEfficiencyScore, isWinner: Bool) -> String {
        if isWinner {
            return "Weekly Winner"
        }

        if score.isScorable && score.activityPoints == 0 {
            return "No Public Output"
        }

        return "AI Fuel Score"
    }

    private func missingFuelText(for score: BuildEfficiencyScore) -> String {
        if canUseThisMacFuel(for: score.person) {
            return "No score yet. Use this Mac's Codex fuel."
        }

        return "Waiting on this builder's Mac for Codex fuel."
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
            return fuelResolver.matchesLocalIdentity(score.person) ? "Waiting" : "Fuel TBD"
        }

        let suffix = fuelResolver.usesLocalFuel(for: score.person) ? " auto" : ""
        return "\(Int(codexBurnedPercent.rounded()))%\(suffix)"
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

            Text("Builder Score = GitHub pts / Codex burned")
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

        localIdentity = LocalDeveloperIdentity.current()

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
        statusMessage = footerStatus(sharedLoadFailed: sharedLoadFailed)
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

    private func canUseThisMacFuel(for person: LeaderboardPerson) -> Bool {
        isLocalPerson(person) || fuelResolver.matchesLocalIdentity(person)
    }

    private func mergeKey(for person: LeaderboardPerson) -> String {
        let username = person.githubUsername.lowercased()
        if !username.isEmpty {
            return "github:\(username)"
        }

        return "id:\(person.id.uuidString)"
    }

    private func codexBurnedPercent(for person: LeaderboardPerson) -> Double? {
        fuelResolver.burnedPercent(for: person)
    }

    private var fuelResolver: LeaderboardFuelResolver {
        LeaderboardFuelResolver(snapshot: refreshService.snapshot, localIdentity: localIdentity)
    }

    private func footerStatus(sharedLoadFailed: Bool) -> String {
        if sharedLoadFailed {
            return "Using local Builder Board list. Shared list could not load."
        }

        if let profile = localProfile {
            return "Approximate score based on public GitHub activity. This Mac is set to @\(profile.githubUsername)."
        }

        if let username = localIdentity.githubUsername, !username.isEmpty {
            return "Approximate score based on public GitHub activity. Local Codex fuel matched to @\(username)."
        }

        return "Approximate score based on public GitHub activity. Set My GitHub to join from this Mac."
    }

    private func closeLeaderboardWindow() {
        if let window = NSApp.keyWindow, window.title == "Builder Board • This Week" {
            window.close()
            return
        }

        NSApp.windows
            .first { $0.title == "Builder Board • This Week" }?
            .close()
    }

    private var localProfile: LeaderboardPerson? {
        store.people.first { $0.codexUsageMode == .localGauge && $0.manualWeeklyCodexBurnedPercent == nil }
            ?? (store.people + sharedPeople).first { fuelResolver.matchesLocalIdentity($0) }
    }

    private var localProfileDraft: LeaderboardPerson {
        if let localProfile {
            return localProfile
        }

        let cleanDisplayName = localIdentity.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName = cleanDisplayName.isEmpty ? ProcessInfo.processInfo.userName : cleanDisplayName
        return LeaderboardPerson(
            displayName: displayName,
            githubProfile: localIdentity.githubUsername ?? "",
            codexUsageMode: .localGauge,
            manualWeeklyCodexBurnedPercent: nil
        )
    }
}

private enum LeaderboardSheet: Identifiable {
    case myGitHub(LeaderboardPerson)
    case edit(LeaderboardPerson)

    var id: String {
        switch self {
        case .myGitHub(let person):
            return "my-github-\(person.id.uuidString)"
        case .edit(let person):
            return "edit-\(person.id.uuidString)"
        }
    }

    var person: LeaderboardPerson? {
        switch self {
        case .myGitHub(let person), .edit(let person):
            return person
        }
    }

    var title: String {
        switch self {
        case .myGitHub:
            return "Set My GitHub"
        case .edit:
            return "Edit Builder"
        }
    }

    var showsFuelControls: Bool {
        switch self {
        case .myGitHub:
            return false
        case .edit:
            return true
        }
    }
}
