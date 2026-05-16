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
            let layout = WidgetLayout(mode: preferences.widgetSizeMode)
            let palette = NotebookTheme.palette(for: preferences.theme)

            ZStack {
                SketchBackground(phase: phase)
                    .shadow(color: NotebookTheme.shadow, radius: 20, x: 0, y: 13)
                    .shadow(color: palette.ink.opacity(0.08), radius: 9, x: 0, y: 0)

                VStack(alignment: .leading, spacing: layout.stackSpacing) {
                    header(snapshot: snapshot, layout: layout, palette: palette)

                    VStack(alignment: .leading, spacing: layout.rowSpacing) {
                        GaugeRow(
                            label: snapshot.primaryWindowLabel,
                            percent: snapshot.dailyRemainingPercent,
                            phase: phase,
                            labelSize: layout.rowLabelSize,
                            valueSize: layout.percentSize,
                            barHeight: layout.barHeight
                        )
                        GaugeRow(
                            label: snapshot.secondaryWindowLabel,
                            percent: snapshot.weeklyRemainingPercent,
                            phase: phase + 0.9,
                            labelSize: layout.rowLabelSize,
                            valueSize: layout.percentSize,
                            barHeight: layout.barHeight
                        )
                    }

                    Spacer(minLength: 0)

                    HStack(alignment: .center, spacing: 10) {
                        footer(snapshot: snapshot)

                        Spacer(minLength: 8)

                        WidgetControlsView()
                    }
                }
                .padding(.leading, layout.horizontalPadding)
                .padding(.trailing, layout.horizontalPadding)
                .padding(.top, layout.verticalPadding)
                .padding(.bottom, layout.verticalPadding)

                if !preferences.hasSeenIntro {
                    introOverlay(palette: palette)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .frame(width: layout.size.width, height: layout.size.height)
            .accessibilityLabel(accessibilityLabel(for: snapshot))
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: preferences.widgetSizeMode)
            .animation(.easeInOut(duration: 0.18), value: preferences.theme)
            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: preferences.hasSeenIntro)
        }
    }

    private func header(snapshot: UsageSnapshot, layout: WidgetLayout, palette: NotebookPalette) -> some View {
        HStack(alignment: .center) {
            Text("Codex Gauge")
                .notebookFont(size: layout.titleSize, weight: .bold, handwritten: preferences.useHandwrittenFont)
                .foregroundStyle(palette.brightInk)
                .shadow(color: palette.ink.opacity(0.18), radius: 7)
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            if !snapshot.hasUsageValues {
                Text("Unknown")
                    .notebookFont(size: 12, weight: .semibold, handwritten: preferences.useHandwrittenFont)
                    .foregroundStyle(palette.ink.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(palette.ink.opacity(0.35), lineWidth: 0.8)
                    }
                    .help(snapshot.providerStatus.message)
            }

            Spacer()

            LiveIndicator()
        }
    }

    private func footer(snapshot: UsageSnapshot) -> some View {
        let palette = NotebookTheme.palette(for: preferences.theme)

        return HStack(spacing: 4) {
            Text("Last Updated:")
                .notebookFont(size: 11, weight: .semibold, handwritten: preferences.useHandwrittenFont)
                .foregroundStyle(palette.dimInk)

            Text(timeFormatter.string(from: snapshot.lastUpdated))
                .notebookFont(size: 11, weight: .semibold, handwritten: preferences.useHandwrittenFont)
                .foregroundStyle(palette.ink.opacity(0.88))

            Text("•")
                .foregroundStyle(palette.dimInk.opacity(0.7))

            Text(snapshot.hasUsageValues ? "Real data" : "Unknown")
                .notebookFont(size: 11, weight: .semibold, handwritten: preferences.useHandwrittenFont)
                .foregroundStyle(palette.brightInk.opacity(0.9))
                .help(snapshot.providerStatus.message)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }

    private func introOverlay(palette: NotebookPalette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Codex Gauge")
                    .notebookFont(size: 23, weight: .bold, handwritten: preferences.useHandwrittenFont)
                    .foregroundStyle(palette.brightInk)

                Spacer()

                Button {
                    preferences.hasSeenIntro = true
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(SketchIconButtonStyle())
                .help("Close")
            }

            Text("Uses your local Codex sign-in to read the account usage API, then falls back to local Codex logs when needed.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.ink.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Label("Real data first", systemImage: "checkmark.seal")
                Label("No fake values", systemImage: "shield")
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.brightInk.opacity(0.9))

            Button {
                preferences.hasSeenIntro = true
            } label: {
                Text("Got it")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SketchTextButtonStyle(palette: palette))
        }
        .padding(18)
        .frame(maxWidth: 300)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(palette.paperLift.opacity(0.97))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(palette.ink.opacity(0.44), lineWidth: 1.2)
                }
                .shadow(color: Color.black.opacity(0.48), radius: 18, y: 10)
        }
    }

    private func accessibilityLabel(for snapshot: UsageSnapshot) -> String {
        let daily = snapshot.dailyRemainingPercent.map { "\(Int($0.rounded())) percent" } ?? "unknown"
        let weekly = snapshot.weeklyRemainingPercent.map { "\(Int($0.rounded())) percent" } ?? "unknown"
        return "Codex Gauge. \(snapshot.primaryWindowLabel) remaining \(daily). \(snapshot.secondaryWindowLabel) remaining \(weekly)."
    }
}

private struct WidgetLayout {
    let mode: GaugeWidgetSizeMode

    var size: CGSize { mode.size }

    var horizontalPadding: CGFloat {
        switch mode {
        case .tiny:
            return 24
        case .regular:
            return 28
        case .expanded:
            return 32
        }
    }

    var verticalPadding: CGFloat {
        switch mode {
        case .tiny:
            return 22
        case .regular:
            return 24
        case .expanded:
            return 29
        }
    }

    var stackSpacing: CGFloat {
        switch mode {
        case .tiny:
            return 8
        case .regular:
            return 12
        case .expanded:
            return 17
        }
    }

    var rowSpacing: CGFloat {
        switch mode {
        case .tiny:
            return 7
        case .regular:
            return 11
        case .expanded:
            return 16
        }
    }

    var titleSize: CGFloat {
        switch mode {
        case .tiny:
            return 22
        case .regular:
            return 25
        case .expanded:
            return 29
        }
    }

    var rowLabelSize: CGFloat {
        switch mode {
        case .tiny:
            return 18
        case .regular:
            return 20
        case .expanded:
            return 24
        }
    }

    var percentSize: CGFloat {
        switch mode {
        case .tiny:
            return 27
        case .regular:
            return 30
        case .expanded:
            return 36
        }
    }

    var barHeight: CGFloat {
        switch mode {
        case .tiny:
            return 15
        case .regular:
            return 18
        case .expanded:
            return 22
        }
    }
}
