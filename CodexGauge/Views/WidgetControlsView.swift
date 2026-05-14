import SwiftUI

struct WidgetControlsView: View {
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var refreshService: UsageRefreshService

    var body: some View {
        HStack(spacing: 9) {
            Button {
                preferences.alwaysOnTop.toggle()
            } label: {
                Image(systemName: preferences.alwaysOnTop ? "pin.fill" : "pin")
            }
            .help(preferences.alwaysOnTop ? "Disable always on top" : "Keep always on top")

            Button {
                Task { await refreshService.refreshNow() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh now")

            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotebookTheme.dimInk)

            Slider(value: $preferences.panelOpacity, in: 0.45...1)
                .controlSize(.small)
                .tint(NotebookTheme.ink)
                .help("Transparency")
        }
        .buttonStyle(SketchIconButtonStyle())
    }
}

struct SketchIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(NotebookTheme.ink.opacity(configuration.isPressed ? 0.62 : 0.92))
            .frame(width: 22, height: 20)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(NotebookTheme.ink.opacity(configuration.isPressed ? 0.55 : 0.26), lineWidth: 0.9)
            }
            .contentShape(Rectangle())
    }
}
