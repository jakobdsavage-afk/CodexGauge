import SwiftUI

struct GaugeWidgetView: View {
    @EnvironmentObject private var refreshService: UsageRefreshService
    @EnvironmentObject private var preferences: UserPreferences

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let snapshot = refreshService.snapshot

            ZStack {
                SketchBackground(phase: phase)
                    .shadow(color: NotebookTheme.shadow, radius: 20, x: 0, y: 13)
                    .shadow(color: NotebookTheme.ink.opacity(0.08), radius: 9, x: 0, y: 0)

                VStack(alignment: .leading, spacing: 12) {
                    header(snapshot: snapshot)

                    VStack(alignment: .leading, spacing: 11) {
                        GaugeRow(label: snapshot.primaryWindowLabel, percent: snapshot.dailyRemainingPercent, phase: phase)
                        GaugeRow(label: snapshot.secondaryWindowLabel, percent: snapshot.weeklyRemainingPercent, phase: phase + 0.9)
                    }

                    Spacer(minLength: 0)

                    HStack(alignment: .center, spacing: 10) {
                        footer(snapshot: snapshot)

                        Spacer(minLength: 8)

                        WidgetControlsView()
                    }
                }
                .padding(.leading, 28)
                .padding(.trailing, 27)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .frame(width: 372, height: 248)
            .accessibilityLabel(accessibilityLabel(for: snapshot))
        }
    }

    private func header(snapshot: UsageSnapshot) -> some View {
        HStack(alignment: .center) {
            Text("Codex Calculator")
                .notebookFont(size: 25, weight: .bold)
                .foregroundStyle(NotebookTheme.brightInk)
                .shadow(color: NotebookTheme.ink.opacity(0.18), radius: 7)
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            if !snapshot.hasUsageValues {
                Text("Unknown")
                    .notebookFont(size: 12, weight: .semibold)
                    .foregroundStyle(NotebookTheme.ink.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(NotebookTheme.ink.opacity(0.35), lineWidth: 0.8)
                    }
                    .help(snapshot.providerStatus.message)
            }

            Spacer()

            LiveIndicator(isRefreshing: refreshService.isRefreshing)
        }
    }

    private func footer(snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 4) {
            Text("Last Updated:")
                .notebookFont(size: 11, weight: .semibold)
                .foregroundStyle(NotebookTheme.dimInk)

            Text(timeFormatter.string(from: snapshot.lastUpdated))
                .notebookFont(size: 11, weight: .semibold)
                .foregroundStyle(NotebookTheme.ink.opacity(0.88))

            Text("•")
                .foregroundStyle(NotebookTheme.dimInk.opacity(0.7))

            Text(snapshot.hasUsageValues ? "Real data" : "Unknown")
                .notebookFont(size: 11, weight: .semibold)
                .foregroundStyle(NotebookTheme.brightInk.opacity(0.9))
                .help(snapshot.providerStatus.message)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }

    private func accessibilityLabel(for snapshot: UsageSnapshot) -> String {
        let daily = snapshot.dailyRemainingPercent.map { "\(Int($0.rounded())) percent" } ?? "unknown"
        let weekly = snapshot.weeklyRemainingPercent.map { "\(Int($0.rounded())) percent" } ?? "unknown"
        return "Codex Calculator. \(snapshot.primaryWindowLabel) remaining \(daily). \(snapshot.secondaryWindowLabel) remaining \(weekly)."
    }
}
