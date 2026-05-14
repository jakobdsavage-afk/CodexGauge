import SwiftUI

struct LiveIndicator: View {
    let isRefreshing: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let pulse = (sin(timeline.date.timeIntervalSinceReferenceDate * 3.1) + 1) / 2

            HStack(spacing: 6) {
                Circle()
                    .fill(NotebookTheme.ink.opacity(isRefreshing ? 0.55 : 0.78))
                    .frame(width: 8, height: 8)
                    .shadow(color: NotebookTheme.ink.opacity(0.35 + pulse * 0.35), radius: 5 + pulse * 4)

                Text(isRefreshing ? "Scan" : "Live")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(NotebookTheme.ink.opacity(0.82))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(NotebookTheme.paperGroove.opacity(0.72))
                    .overlay {
                        Capsule()
                            .stroke(NotebookTheme.ink.opacity(0.22), lineWidth: 0.8)
                    }
            }
        }
    }
}
