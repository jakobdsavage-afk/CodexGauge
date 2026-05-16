import AppKit
import SwiftUI

struct WidgetControlsView: View {
    @EnvironmentObject private var preferences: UserPreferences
    @EnvironmentObject private var refreshService: UsageRefreshService

    var body: some View {
        let palette = NotebookTheme.palette(for: preferences.theme)

        HStack(spacing: 7) {
            Menu {
                ForEach(GaugePinMode.allCases) { mode in
                    Button {
                        preferences.pinMode = mode
                    } label: {
                        Label(mode.title, systemImage: preferences.pinMode == mode ? "checkmark" : mode.iconName)
                    }
                }
            } label: {
                Image(systemName: preferences.pinMode.iconName)
            }
            .help("Pin mode")

            Button {
                Task { await refreshService.refreshNow() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh now")

            Menu {
                Section("Theme") {
                    ForEach(GaugeTheme.allCases) { theme in
                        Button {
                            preferences.theme = theme
                        } label: {
                            Label(theme.title, systemImage: preferences.theme == theme ? "checkmark" : "circle")
                        }
                    }
                }

                Section("Size") {
                    ForEach(GaugeWidgetSizeMode.allCases) { mode in
                        Button {
                            preferences.widgetSizeMode = mode
                        } label: {
                            Label(mode.title, systemImage: preferences.widgetSizeMode == mode ? "checkmark" : "rectangle")
                        }
                    }
                }

                Section("Text") {
                    Button {
                        preferences.useHandwrittenFont.toggle()
                    } label: {
                        Label(preferences.useHandwrittenFont ? "Handwritten" : "Clean", systemImage: preferences.useHandwrittenFont ? "scribble" : "textformat")
                    }

                    Button {
                        preferences.hasSeenIntro = false
                    } label: {
                        Label("About Data Source", systemImage: "info.circle")
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .help("Appearance")

            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.dimInk)

            SketchOpacityControl(value: $preferences.panelOpacity, palette: palette)
                .help("Transparency")
        }
        .buttonStyle(SketchIconButtonStyle())
    }
}

struct SketchOpacityControl: View {
    @Binding var value: Double
    let palette: NotebookPalette

    private let range = 0.45...1.0

    var body: some View {
        SketchOpacitySlider(value: $value, range: range, palette: palette)
        .frame(width: 52, height: 12)
    }
}

private struct SketchOpacitySlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let palette: NotebookPalette

    func makeNSView(context: Context) -> SketchOpacitySliderNSView {
        let view = SketchOpacitySliderNSView()
        view.onValueChanged = { value = $0 }
        view.range = range
        view.value = value
        view.palette = palette
        return view
    }

    func updateNSView(_ nsView: SketchOpacitySliderNSView, context: Context) {
        nsView.onValueChanged = { value = $0 }
        nsView.range = range
        nsView.value = value
        nsView.palette = palette
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
    var palette: NotebookPalette = NotebookTheme.palette(for: .notebookGreen) {
        didSet { needsDisplay = true }
    }

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

        NSColor(palette.ink.opacity(0.28)).setStroke()
        let outline = NSBezierPath(roundedRect: trackRect, xRadius: trackRect.height / 2, yRadius: trackRect.height / 2)
        outline.lineWidth = 1
        outline.stroke()

        NSColor(palette.ink.opacity(0.42)).setFill()
        let fillRect = NSRect(x: trackRect.minX, y: trackRect.minY, width: fillWidth, height: trackRect.height)
        NSBezierPath(roundedRect: fillRect, xRadius: trackRect.height / 2, yRadius: trackRect.height / 2).fill()

        NSColor(palette.brightInk).setFill()
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
    @EnvironmentObject private var preferences: UserPreferences

    func makeBody(configuration: Configuration) -> some View {
        let palette = NotebookTheme.palette(for: preferences.theme)

        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(palette.ink.opacity(configuration.isPressed ? 0.62 : 0.92))
            .frame(width: 22, height: 20)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(palette.ink.opacity(configuration.isPressed ? 0.55 : 0.26), lineWidth: 0.9)
            }
            .contentShape(Rectangle())
    }
}

struct SketchTextButtonStyle: ButtonStyle {
    let palette: NotebookPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(palette.paperGroove)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(palette.brightInk.opacity(configuration.isPressed ? 0.68 : 0.88))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(palette.ink.opacity(0.65), lineWidth: 1)
                    }
            }
    }
}
