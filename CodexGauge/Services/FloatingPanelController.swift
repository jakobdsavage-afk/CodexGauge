import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let preferences: UserPreferences
    private let refreshService: UsageRefreshService
    private var cancellables: Set<AnyCancellable> = []
    private(set) var panel: NSPanel?

    init(preferences: UserPreferences, refreshService: UsageRefreshService) {
        self.preferences = preferences
        self.refreshService = refreshService
        super.init()
    }

    func show() {
        if panel == nil {
            panel = makePanel()
            bindPreferences()
        }

        guard preferences.pinMode != .menuBarOnly else {
            panel?.orderOut(nil)
            return
        }

        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggleVisibility() {
        if preferences.pinMode == .menuBarOnly {
            preferences.pinMode = .floating
            show()
            return
        }

        guard let panel else {
            show()
            return
        }

        panel.isVisible ? hide() : show()
    }

    func windowDidMove(_ notification: Notification) {
        guard let frame = panel?.frame else {
            return
        }
        preferences.saveFrame(frame)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    private func makePanel() -> NSPanel {
        let contentView = GaugeWidgetView()
            .environmentObject(preferences)
            .environmentObject(refreshService)

        let panel = NSPanel(
            contentRect: launchFrame(),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.title = "Codex Gauge"
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        // NSPanel defaults are tuned for transient utility panels. A desktop
        // widget should remain visible when the user clicks into another app.
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: contentView)
        panel.contentMinSize = widgetSize
        panel.contentMaxSize = widgetSize
        applyPinMode(to: panel)
        panel.alphaValue = preferences.panelOpacity

        return panel
    }

    private func bindPreferences() {
        preferences.$pinMode
            .sink { [weak self] pinMode in
                guard let self, let panel = self.panel else {
                    return
                }
                self.applyPinMode(to: panel)
                if pinMode == .menuBarOnly {
                    panel.orderOut(nil)
                } else if !panel.isVisible {
                    panel.makeKeyAndOrderFront(nil)
                }
            }
            .store(in: &cancellables)

        preferences.$panelOpacity
            .sink { [weak self] opacity in
                self?.panel?.alphaValue = opacity
            }
            .store(in: &cancellables)

        preferences.$widgetSizeMode
            .dropFirst()
            .sink { [weak self] _ in
                self?.resizePanelForCurrentMode()
            }
            .store(in: &cancellables)
    }

    private func applyPinMode(to panel: NSPanel) {
        switch preferences.pinMode {
        case .floating:
            panel.level = .floating
        case .desktop, .menuBarOnly:
            panel.level = .normal
        }
    }

    private func resizePanelForCurrentMode() {
        guard let panel else {
            return
        }

        let currentFrame = panel.frame
        let size = widgetSize
        var nextFrame = CGRect(
            x: currentFrame.maxX - size.width,
            y: currentFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        nextFrame = frameInsideVisibleScreen(nextFrame)

        panel.contentMinSize = size
        panel.contentMaxSize = size
        panel.setFrame(nextFrame, display: true, animate: true)
        preferences.saveFrame(nextFrame)
    }

    private func launchFrame() -> CGRect {
        guard var savedFrame = preferences.loadFrame() else {
            return defaultFrame()
        }

        savedFrame.size = widgetSize
        return frameInsideVisibleScreen(savedFrame)
    }

    private func defaultFrame() -> CGRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = widgetSize
        return CGRect(
            x: screenFrame.maxX - size.width - 28,
            y: screenFrame.maxY - size.height - 32,
            width: size.width,
            height: size.height
        )
    }

    private func frameInsideVisibleScreen(_ frame: CGRect) -> CGRect {
        let screens = NSScreen.screens.map(\.visibleFrame)
        let visibleFrame = screens.first(where: { $0.intersects(frame) })
            ?? NSScreen.main?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        var adjusted = frame
        adjusted.origin.x = min(max(adjusted.minX, visibleFrame.minX + 12), visibleFrame.maxX - adjusted.width - 12)
        adjusted.origin.y = min(max(adjusted.minY, visibleFrame.minY + 12), visibleFrame.maxY - adjusted.height - 12)

        return adjusted
    }

    private var widgetSize: CGSize {
        preferences.widgetSizeMode.size
    }
}
