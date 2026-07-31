import AppKit
import SwiftUI

@MainActor
final class MainWindowCoordinator: NSObject, NSWindowDelegate {
    private let model: AppModel
    private lazy var window: NSWindow = makeWindow()

    init(model: AppModel) {
        self.model = model
    }

    func show(mode: ClaspPresentationMode) {
        apply(mode)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in
            self?.scrollWideContentToLeadingEdge(in: self?.window.contentView)
        }
        Task { await model.loadLibrary() }
    }

    func hide() {
        window.orderOut(nil)
    }

    private func apply(_ mode: ClaspPresentationMode) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        switch mode {
        case .mini, .medium:
            let size = NSSize(width: 460, height: min(720, screen.visibleFrame.height - 32))
            let origin = NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2
            )
            window.setFrame(NSRect(origin: origin, size: size), display: true)
        case .maximum:
            window.setFrame(screen.visibleFrame.insetBy(dx: 16, dy: 16), display: true)
        }
    }

    private func scrollWideContentToLeadingEdge(in view: NSView?) {
        guard let view else { return }
        if let scrollView = view as? NSScrollView,
           scrollView.hasHorizontalScroller,
           let documentView = scrollView.documentView,
           documentView.frame.width > scrollView.contentSize.width {
            scrollView.contentView.scroll(to: NSPoint(
                x: documentView.bounds.minX,
                y: scrollView.contentView.bounds.origin.y
            ))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
        view.subviews.forEach { scrollWideContentToLeadingEdge(in: $0) }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clasp"
        window.contentView = NSHostingView(rootView: LibraryView(model: model))
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.minSize = NSSize(width: 420, height: 520)
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.center()
        return window
    }
}
