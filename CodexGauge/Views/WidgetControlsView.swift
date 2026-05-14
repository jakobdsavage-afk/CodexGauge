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
        SketchOpacitySlider(value: $value, range: range)
        .frame(width: 52, height: 12)
    }
}

private struct SketchOpacitySlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>

    func makeNSView(context: Context) -> SketchOpacitySliderNSView {
        let view = SketchOpacitySliderNSView()
        view.onValueChanged = { value = $0 }
        view.range = range
        view.value = value
        return view
    }

    func updateNSView(_ nsView: SketchOpacitySliderNSView, context: Context) {
        nsView.onValueChanged = { value = $0 }
        nsView.range = range
        nsView.value = value
    }
}

private final class SketchOpacitySliderNSView: NSView {
    var range: ClosedRange<Double> = 0.45...1.0 {
        didSet { needsDisplay = true }
    }

    var value: Double = 1.0 {
        didSet { needsDisplay = true }
    }

    var onValueChanged: ((Double) -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        updateValue(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updateValue(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let normalized = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            .clamped(to: 0...1)
        let trackRect = bounds.insetBy(dx: 0.5, dy: 2.5)
        let fillWidth = max(7, trackRect.width * normalized)

        NSColor(NotebookTheme.ink.opacity(0.28)).setStroke()
        let outline = NSBezierPath(roundedRect: trackRect, xRadius: trackRect.height / 2, yRadius: trackRect.height / 2)
        outline.lineWidth = 1
        outline.stroke()

        NSColor(NotebookTheme.ink.opacity(0.42)).setFill()
        let fillRect = NSRect(x: trackRect.minX, y: trackRect.minY, width: fillWidth, height: trackRect.height)
        NSBezierPath(roundedRect: fillRect, xRadius: trackRect.height / 2, yRadius: trackRect.height / 2).fill()

        NSColor(NotebookTheme.brightInk).setFill()
        let knobX = max(trackRect.minX, min(trackRect.maxX - 8, trackRect.minX + trackRect.width * normalized - 8))
        NSBezierPath(ovalIn: NSRect(x: knobX, y: bounds.midY - 4, width: 8, height: 8)).fill()
    }

    private func updateValue(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let normalized = Double((location.x / max(bounds.width, 1)).clamped(to: 0...1))
        let nextValue = range.lowerBound + normalized * (range.upperBound - range.lowerBound)
        value = nextValue
        onValueChanged?(nextValue)
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
