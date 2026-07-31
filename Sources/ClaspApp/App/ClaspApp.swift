import AppKit
import ClaspCore
import Darwin
import OSLog
import SwiftUI

@MainActor
final class ClaspAppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.clasp.app", category: "lifecycle")
    private let repository = FileCaptureStore()
    private let credentialStore = KeychainCredentialStore()
    private let hotKeyManager = GlobalHotKeyManager()
    private let selectionReader = AccessibilitySelectionReader()
    private var instanceLock: SingleInstanceLock?

    private lazy var notionClient = NotionClient(
        transport: URLSessionHTTPTransport()
    )
    private lazy var captureService = CaptureService(
        repository: repository,
        credentialStore: credentialStore,
        notion: notionClient
    )
    private lazy var settingsService = SettingsService(
        repository: repository,
        credentialStore: credentialStore,
        notion: notionClient
    )
    private lazy var libraryService = LibraryService(
        repository: repository,
        credentialStore: credentialStore,
        notion: notionClient
    )
    private lazy var deliveryCoordinator = DeliveryCoordinator(
        repository: repository,
        captureService: captureService
    )
    lazy var appModel = AppModel(
        repository: repository,
        captureService: captureService,
        settingsService: settingsService,
        libraryService: libraryService,
        deliveryCoordinator: deliveryCoordinator,
        hotKeyManager: hotKeyManager
    )
    private lazy var capturePanel = CapturePanelCoordinator(model: appModel)
    private lazy var settingsWindow = SettingsWindowCoordinator(model: appModel)
    private lazy var mainWindow = MainWindowCoordinator(model: appModel)

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let lock = SingleInstanceLock.acquire() else {
            logger.notice("Another Clasp instance is already running")
            NSApp.terminate(nil)
            return
        }
        instanceLock = lock
        setActivationPolicy(for: appModel.presentationMode)
        logger.info("Clasp started")
        hotKeyManager.onPressed = { [weak self] in
            DispatchQueue.main.async {
                self?.beginCapture()
            }
        }
        if !hotKeyManager.register(hotKeyManager.savedShortcut()) {
            appModel.statusMessage = "The saved global shortcut is already in use."
        }
        Task {
            await appModel.load()
            if appModel.destinations == nil {
                showSettings()
            } else if appModel.presentationMode != .mini {
                showMain()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        appModel.recheckAccessibilityPermission()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        guard appModel.presentationMode != .mini else { return true }
        if appModel.destinations == nil {
            showSettings()
        } else {
            showMain()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Clasp stopped")
    }

    func beginCapture() {
        Task {
            let outcome = await selectionReader.readSelection()
            let prepared = CapturePreparation.prepare(from: outcome)
            capturePanel.show(prepared)
        }
    }

    func showSettings() {
        settingsWindow.show()
    }

    func showMain() {
        mainWindow.show(mode: appModel.presentationMode == .maximum ? .maximum : .medium)
    }

    func applyPresentationMode(_ mode: ClaspPresentationMode) {
        appModel.setPresentationMode(mode)
        setActivationPolicy(for: mode)
        switch mode {
        case .mini:
            mainWindow.hide()
        case .medium, .maximum:
            mainWindow.show(mode: mode)
        }
    }

    private func setActivationPolicy(for mode: ClaspPresentationMode) {
        NSApp.setActivationPolicy(mode == .mini ? .accessory : .regular)
    }
}

private final class SingleInstanceLock {
    private let descriptor: Int32

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    static func acquire() -> SingleInstanceLock? {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.clasp.app.\(getuid()).lock")
            .path
        let descriptor = Darwin.open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return nil }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor)
            return nil
        }
        return SingleInstanceLock(descriptor: descriptor)
    }

    deinit {
        flock(descriptor, LOCK_UN)
        Darwin.close(descriptor)
    }
}

@main
struct ClaspApplication: App {
    @NSApplicationDelegateAdaptor private var appDelegate: ClaspAppDelegate

    var body: some Scene {
        MenuBarExtra {
            ClaspMenuView(
                model: appDelegate.appModel,
                onCapture: appDelegate.beginCapture,
                onOpenMain: appDelegate.showMain,
                onPresentationMode: appDelegate.applyPresentationMode,
                onSettings: appDelegate.showSettings
            )
        } label: {
            Label {
                Text("Clasp")
            } icon: {
                ClaspMenuBarIcon()
            }
            .accessibilityLabel("Clasp")
        }

        Window("Recent Captures", id: "recent-captures") {
            RecentCapturesView(model: appDelegate.appModel)
        }
        .defaultSize(width: 680, height: 480)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appDelegate.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

private struct ClaspMenuView: View {
    @ObservedObject var model: AppModel
    let onCapture: () -> Void
    let onOpenMain: () -> Void
    let onPresentationMode: (ClaspPresentationMode) -> Void
    let onSettings: () -> Void

    var body: some View {
        Button("Capture Selection") {
            onCapture()
        }
        .keyboardShortcut("c")

        Button("Open Clasp") {
            onOpenMain()
        }
        .keyboardShortcut("o")

        Divider()
        Text("Window Mode")
        ForEach(ClaspPresentationMode.allCases) { mode in
            Button {
                onPresentationMode(mode)
            } label: {
                Label {
                    Text("\(mode.title) — \(mode.helpText)")
                } icon: {
                    Image(systemName: model.presentationMode == mode ? "checkmark.circle.fill" : "circle")
                }
            }
        }

        let pendingCount = model.captures.filter {
            $0.delivery == .pending || $0.delivery == .failed
        }.count
        if pendingCount > 0 {
            Text("\(pendingCount) capture\(pendingCount == 1 ? "" : "s") need attention")
                .foregroundStyle(.secondary)
        }

        Divider()
        Button("Settings…") {
            onSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Clasp") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
