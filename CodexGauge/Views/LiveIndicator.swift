import SwiftUI

struct LiveIndicator: View {
    let isRefreshing: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let pulse = (sin(timeline.date.timeIntervalSinceReferenceDate * 3.1) + 1) / 2

            HStack(spacing: 5) {
                Circle()
                    .fill(NotebookTheme.ink.opacity(isRefreshing ? 0.55 : 0.78))
                    .frame(width: 7, height: 7)
                    .shadow(color: NotebookTheme.ink.opacity(0.35 + pulse * 0.35), radius: 5 + pulse * 4)

                Text(isRefreshing ? "Scan" : "Live")
                    .notebookFont(size: 13, weight: .semibold)
                    .foregroundStyle(NotebookTheme.ink.opacity(0.82))
            }
        }
    }
}
