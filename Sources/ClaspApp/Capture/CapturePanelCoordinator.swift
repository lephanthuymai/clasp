import AppKit
import ClaspCore
import SwiftUI

@MainActor
final class CapturePanelCoordinator {
    private let model: AppModel
    private lazy var panel: NSPanel = makePanel()
    private var sourceProcessIdentifier: pid_t?

    init(model: AppModel) {
        self.model = model
    }

    func show(_ prepared: PreparedCapture) {
        if panel.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            return
        }
        sourceProcessIdentifier = prepared.draft.source.processIdentifier
        let content = CaptureView(
            model: model,
            initialDraft: prepared.draft,
            notice: prepared.notice,
            onCancel: { [weak self] in self?.close(restoreSource: true) },
            onSaved: { [weak self] in self?.close(restoreSource: false) }
        )
        panel.contentView = NSHostingView(rootView: content)
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close(restoreSource: Bool) {
        panel.orderOut(nil)
        defer { sourceProcessIdentifier = nil }
        guard restoreSource,
              let sourceProcessIdentifier,
              let sourceApplication = NSRunningApplication(
                  processIdentifier: sourceProcessIdentifier
              ),
              !sourceApplication.isTerminated
        else {
            return
        }
        sourceApplication.activate()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 590, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Capture with Clasp"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        return panel
    }
}
