import AppKit
import SwiftUI

@MainActor
final class MainWindowCoordinator: NSObject, NSWindowDelegate {
    private let model: AppModel
    private lazy var window: NSWindow = makeWindow()

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        Task { await model.loadLibrary() }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_120, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clasp"
        window.contentView = NSHostingView(rootView: LibraryView(model: model))
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 900, height: 540)
        window.setFrameAutosaveName("ClaspMainWindow")
        window.center()
        return window
    }
}
