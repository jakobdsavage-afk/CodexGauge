import AppKit
import SwiftUI

struct WidgetControlsView: View {
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var refreshService: UsageRefreshService

    var body: some View {
        HStack(spacing: 8) {
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

            SketchOpacityControl(value: $preferences.panelOpacity)
                .help("Transparency")
        }
        .buttonStyle(SketchIconButtonStyle())
    }
}

struct SketchOpacityControl: View {
    @Binding var value: Double

    private let range = 0.45...1.0

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let normalized = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                .clamped(to: 0...1)

            ZStack(alignment: .leading) {
                Capsule()
                    .stroke(NotebookTheme.ink.opacity(0.28), lineWidth: 1)

                Capsule()
                    .fill(NotebookTheme.ink.opacity(0.42))
                    .frame(width: max(7, width * normalized))

                Circle()
                    .fill(NotebookTheme.brightInk)
                    .frame(width: 8, height: 8)
                    .shadow(color: NotebookTheme.ink.opacity(0.36), radius: 4)
                    .offset(x: max(0, width * normalized - 8))
            }
            .contentShape(Rectangle())
            .background(NonDraggableHitArea())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let next = Double((gesture.location.x / width).clamped(to: 0...1))
                        value = range.lowerBound + next * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(width: 52, height: 12)
    }
}

private struct NonDraggableHitArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NonDraggableView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class NonDraggableView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        false
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
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
