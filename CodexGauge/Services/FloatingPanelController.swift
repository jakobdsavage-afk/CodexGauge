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

        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggleVisibility() {
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
            contentRect: preferences.loadFrame() ?? defaultFrame(),
            styleMask: [.titled, .fullSizeContentView, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        panel.title = "Codex Gauge"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
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
        applyFloatingLevel(to: panel)
        panel.alphaValue = preferences.panelOpacity

        return panel
    }

    private func bindPreferences() {
        preferences.$alwaysOnTop
            .sink { [weak self] _ in
                guard let self, let panel = self.panel else {
                    return
                }
                self.applyFloatingLevel(to: panel)
            }
            .store(in: &cancellables)

        preferences.$panelOpacity
            .sink { [weak self] opacity in
                self?.panel?.alphaValue = opacity
            }
            .store(in: &cancellables)
    }

    private func applyFloatingLevel(to panel: NSPanel) {
        panel.level = preferences.alwaysOnTop ? .floating : .normal
    }

    private func defaultFrame() -> CGRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = CGSize(width: 286, height: 252)
        return CGRect(
            x: screenFrame.maxX - size.width - 28,
            y: screenFrame.maxY - size.height - 32,
            width: size.width,
            height: size.height
        )
    }
}
