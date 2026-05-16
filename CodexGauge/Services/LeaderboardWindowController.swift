import AppKit
import SwiftUI

@MainActor
final class LeaderboardWindowController: NSObject, NSWindowDelegate {
    private let preferences: UserPreferences
    private let refreshService: UsageRefreshService
    private let store: LeaderboardStore
    private var panel: NSPanel?

    init(preferences: UserPreferences, refreshService: UsageRefreshService, store: LeaderboardStore) {
        self.preferences = preferences
        self.refreshService = refreshService
        self.store = store
        super.init()
    }

    func show() {
        if panel == nil {
            panel = makePanel()
        }

        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        true
    }

    private func makePanel() -> NSPanel {
        let contentView = LeaderboardView()
            .environmentObject(preferences)
            .environmentObject(refreshService)
            .environmentObject(store)

        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = CGSize(width: 560, height: 430)
        let frame = CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Builder Board • This Week"
        panel.titlebarAppearsTransparent = false
        panel.titleVisibility = .visible
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = NSColor(calibratedWhite: 0.015, alpha: 0.96)
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: contentView)
        panel.contentMinSize = size
        panel.contentMaxSize = size
        return panel
    }
}
