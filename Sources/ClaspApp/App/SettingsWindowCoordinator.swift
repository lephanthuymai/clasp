import AppKit
import SwiftUI

@MainActor
final class SettingsWindowCoordinator: NSObject, NSWindowDelegate {
    private let model: AppModel
    private lazy var window: NSWindow = makeWindow()

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        model.recheckAccessibilityPermission()
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clasp Settings"
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("ClaspSettingsWindow")
        return window
    }
}
