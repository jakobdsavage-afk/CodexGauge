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
                    .shadow(color: NotebookTheme.shadow, radius: 18, x: 0, y: 12)

                VStack(alignment: .leading, spacing: 10) {
                    header(snapshot: snapshot)

                    VStack(alignment: .leading, spacing: 8) {
                        GaugeRow(label: "Daily", percent: snapshot.dailyRemainingPercent, phase: phase)
                        GaugeRow(label: "Weekly", percent: snapshot.weeklyRemainingPercent, phase: phase + 0.9)
                    }

                    footer(snapshot: snapshot)

                    WidgetControlsView()
                        .padding(.top, 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .frame(width: 268, height: 224)
            .accessibilityLabel(accessibilityLabel(for: snapshot))
        }
    }

    private func header(snapshot: UsageSnapshot) -> some View {
        HStack(alignment: .center) {
            Text("Codex")
                .notebookFont(size: 33, weight: .bold)
                .foregroundStyle(NotebookTheme.ink)
                .shadow(color: NotebookTheme.ink.opacity(0.16), radius: 7)

            if snapshot.isEstimated {
                Text("Estimated")
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
                .notebookFont(size: 13, weight: .semibold)
                .foregroundStyle(NotebookTheme.dimInk)

            Text(timeFormatter.string(from: snapshot.lastUpdated))
                .notebookFont(size: 13, weight: .semibold)
                .foregroundStyle(NotebookTheme.ink.opacity(0.88))

            Text("•")
                .foregroundStyle(NotebookTheme.dimInk.opacity(0.7))

            Text(snapshot.isEstimated ? "Measured-ish" : "Live")
                .notebookFont(size: 13, weight: .semibold)
                .foregroundStyle(NotebookTheme.ink.opacity(0.86))
                .help(snapshot.providerStatus.message)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }

    private func accessibilityLabel(for snapshot: UsageSnapshot) -> String {
        "Codex Gauge. Daily remaining \(Int(snapshot.dailyRemainingPercent.rounded())) percent. Weekly remaining \(Int(snapshot.weeklyRemainingPercent.rounded())) percent."
    }
}
