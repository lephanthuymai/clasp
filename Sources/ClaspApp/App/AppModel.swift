import AppKit
import ClaspCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var presentationMode: ClaspPresentationMode
    @Published private(set) var captures: [Capture] = []
    @Published private(set) var destinations: DestinationSet?
    @Published private(set) var notionTasks: [NotionListItem] = []
    @Published private(set) var notionBookmarks: [NotionListItem] = []
    @Published private(set) var hasToken = false
    @Published private(set) var isBusy = false
    @Published private(set) var isLibraryLoading = false
    @Published private(set) var completingItemIDs: Set<String> = []
    @Published private(set) var deletingItemIDs: Set<String> = []
    @Published private(set) var updatingTaskFieldKeys: Set<String> = []
    @Published private(set) var askingCodexTaskIDs: Set<String> = []
    @Published private(set) var codexProjects: [CodexProjectOption]
    @Published private(set) var isLoadingCodexProjects = false
    @Published var statusMessage: String?
    @Published var shortcut: GlobalShortcut
    @Published private(set) var codexWorkspacePath: String
    @Published private(set) var accessibilityGranted = AccessibilitySelectionReader.hasPermission

    private let repository: any CaptureRepository
    private let captureService: CaptureService
    private let settingsService: SettingsService
    private let libraryService: LibraryService
    private let deliveryCoordinator: DeliveryCoordinator
    private let hotKeyManager: GlobalHotKeyManager
    private lazy var codexTaskCoordinator = CodexTaskCoordinator(
        onProgress: { [weak self] pageID, progress in
            await self?.receiveCodexProgress(pageID: pageID, progress: progress)
        },
        onThreadReleased: { threadID in
            guard let url = URL(string: "codex://threads/\(threadID)") else { return }
            NSWorkspace.shared.open(url)
        }
    )

    init(
        repository: any CaptureRepository,
        captureService: CaptureService,
        settingsService: SettingsService,
        libraryService: LibraryService,
        deliveryCoordinator: DeliveryCoordinator,
        hotKeyManager: GlobalHotKeyManager
    ) {
        self.repository = repository
        self.captureService = captureService
        self.settingsService = settingsService
        self.libraryService = libraryService
        self.deliveryCoordinator = deliveryCoordinator
        self.hotKeyManager = hotKeyManager
        self.presentationMode = ClaspPresentationMode.saved()
        self.shortcut = hotKeyManager.savedShortcut()
        let savedWorkspacePath = Self.savedCodexWorkspacePath()
        self.codexWorkspacePath = savedWorkspacePath
        self.codexProjects = CodexProjectCatalog.options(
            defaultPath: savedWorkspacePath,
            discoveredPaths: []
        )
    }

    func setPresentationMode(_ mode: ClaspPresentationMode) {
        presentationMode = mode
        mode.save()
    }

    func load() async {
        do {
            _ = try await deliveryCoordinator.recoverInterruptedDeliveries()
            try await refresh()
        } catch {
            statusMessage = safeMessage(for: error)
        }
    }

    func refresh() async throws {
        let document = try await repository.load()
        captures = document.captures.sorted { $0.createdAt > $1.createdAt }
        destinations = document.destinations
        accessibilityGranted = AccessibilitySelectionReader.hasPermission
    }

    func refreshCredentialState() async {
        hasToken = await settingsService.hasToken()
    }

    func confirm(_ draft: CaptureDraft) async -> Bool {
        isBusy = true
        do {
            let capture = try await captureService.enqueue(draft)
            try await refresh()
            isBusy = false
            statusMessage = "Capture saved locally and sending to Notion."
            Task { [weak self] in
                guard let self else { return }
                let result = await self.captureService.attemptDelivery(capture)
                try? await self.refresh()
                if result.delivery == .delivered {
                    await self.refreshLibraryAfterDelivery()
                    self.statusMessage = "Saved to Notion."
                } else {
                    self.statusMessage = "Capture saved locally. Open Recent Captures to retry."
                }
            }
            return true
        } catch {
            isBusy = false
            statusMessage = safeMessage(for: error)
            return false
        }
    }

    func loadLibrary() async {
        guard destinations != nil else {
            notionTasks = []
            notionBookmarks = []
            statusMessage = ClaspError.destinationNotConfigured.localizedDescription
            return
        }
        guard !isLibraryLoading else { return }
        isLibraryLoading = true
        defer { isLibraryLoading = false }
        do {
            let result = try await libraryService.loadAll()
            notionTasks = result.tasks
            notionBookmarks = result.bookmarks
            hasToken = true
            statusMessage = nil
        } catch {
            if let claspError = error as? ClaspError {
                switch claspError {
                case .credentialNotFound, .keychainFailure:
                    hasToken = false
                    notionTasks = []
                    notionBookmarks = []
                default:
                    break
                }
            }
            statusMessage = safeMessage(for: error)
        }
    }

    func createManual(_ draft: CaptureDraft) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        do {
            let capture = try await captureService.enqueue(draft)
            try await refresh()
            let delivered = await captureService.attemptDelivery(capture)
            try await refresh()
            if delivered.delivery == .delivered {
                await refreshLibraryAfterDelivery()
                statusMessage = "\(draft.type.displayName) created in Notion."
            } else {
                statusMessage = "Saved locally. Open Recent Captures to retry delivery."
            }
            return true
        } catch {
            statusMessage = safeMessage(for: error)
            return false
        }
    }

    func markDone(_ item: NotionListItem) async {
        guard completingItemIDs.insert(item.id).inserted else { return }
        defer { completingItemIDs.remove(item.id) }
        do {
            try await libraryService.markDone(pageID: item.id)
            switch item.type {
            case .task:
                notionTasks.removeAll { $0.id == item.id }
            case .bookmark:
                notionBookmarks.removeAll { $0.id == item.id }
            }
            statusMessage = "\(item.type.displayName) marked done."
        } catch {
            statusMessage = safeMessage(for: error)
        }
    }

    func delete(_ item: NotionListItem) async {
        guard item.progress != .working,
              deletingItemIDs.insert(item.id).inserted
        else {
            return
        }
        defer { deletingItemIDs.remove(item.id) }
        do {
            try await libraryService.deletePage(pageID: item.id)
            switch item.type {
            case .task:
                notionTasks.removeAll { $0.id == item.id }
                codexTaskCoordinator.removeSavedThreadID(for: item.id)
            case .bookmark:
                notionBookmarks.removeAll { $0.id == item.id }
            }
            statusMessage = "\(item.type.displayName) moved to Notion Trash."
        } catch {
            statusMessage = safeMessage(for: error)
        }
    }

    func updateTaskPriority(
        _ item: NotionListItem,
        priority: TaskPriority
    ) async -> Bool {
        guard item.type == .task else { return false }
        let key = taskFieldKey(item.id, "priority")
        guard updatingTaskFieldKeys.insert(key).inserted else { return false }
        defer { updatingTaskFieldKeys.remove(key) }
        do {
            try await libraryService.updateTaskPriority(
                pageID: item.id,
                priority: priority
            )
            if let index = notionTasks.firstIndex(where: { $0.id == item.id }) {
                notionTasks[index].priority = priority
            }
            statusMessage = "Task priority updated."
            return true
        } catch {
            statusMessage = safeMessage(for: error)
            return false
        }
    }

    func updateTaskDueDate(
        _ item: NotionListItem,
        dueDate: Date?
    ) async -> Bool {
        guard item.type == .task else { return false }
        let key = taskFieldKey(item.id, "due-date")
        guard updatingTaskFieldKeys.insert(key).inserted else { return false }
        defer { updatingTaskFieldKeys.remove(key) }
        do {
            try await libraryService.updateTaskDueDate(
                pageID: item.id,
                dueDate: dueDate
            )
            if let index = notionTasks.firstIndex(where: { $0.id == item.id }) {
                notionTasks[index].dueDate = dueDate
            }
            statusMessage = dueDate == nil
                ? "Task due date cleared."
                : "Task due date updated."
            return true
        } catch {
            statusMessage = safeMessage(for: error)
            return false
        }
    }

    func isUpdatingTaskField(_ item: NotionListItem, field: String) -> Bool {
        updatingTaskFieldKeys.contains(taskFieldKey(item.id, field))
    }

    func askCodex(
        _ item: NotionListItem,
        instruction: String,
        workspacePath: String
    ) async -> Bool {
        guard item.type == .task,
              askingCodexTaskIDs.insert(item.id).inserted
        else {
            return false
        }
        defer { askingCodexTaskIDs.remove(item.id) }

        do {
            try await applyTaskProgress(pageID: item.id, progress: .working)
            _ = try await codexTaskCoordinator.start(
                item: item,
                instruction: instruction,
                workspacePath: workspacePath
            )
            statusMessage = "Codex is working on \(item.taskID). It will open when ready."
            return true
        } catch {
            try? await applyTaskProgress(pageID: item.id, progress: .failed)
            statusMessage = error.localizedDescription
            return false
        }
    }

    func codexThreadID(for item: NotionListItem) -> String? {
        guard item.type == .task else { return nil }
        return codexTaskCoordinator.savedThreadID(for: item.id)
    }

    func loadCodexProjects() async {
        guard !isLoadingCodexProjects else { return }
        isLoadingCodexProjects = true
        codexProjects = await codexTaskCoordinator.availableProjects(
            defaultPath: codexWorkspacePath
        )
        isLoadingCodexProjects = false
    }

    func includeCodexProject(path: String) {
        codexProjects = CodexProjectCatalog.options(
            defaultPath: codexWorkspacePath,
            discoveredPaths: codexProjects.map(\.path) + [path]
        )
    }

    @discardableResult
    func saveCodexWorkspacePath(_ path: String) -> Bool {
        let normalized = NSString(
            string: path.trimmingCharacters(in: .whitespacesAndNewlines)
        ).expandingTildeInPath
        let url = URL(fileURLWithPath: normalized, isDirectory: true)
            .standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            statusMessage = "Choose an existing folder for the Codex workspace."
            return false
        }
        codexWorkspacePath = url.path
        UserDefaults.standard.set(url.path, forKey: "clasp.codexWorkspacePath")
        codexProjects = CodexProjectCatalog.options(
            defaultPath: url.path,
            discoveredPaths: codexProjects.map(\.path)
        )
        statusMessage = "Codex workspace updated."
        return true
    }

    private func receiveCodexProgress(
        pageID: String,
        progress: TaskProgress
    ) async {
        do {
            try await applyTaskProgress(pageID: pageID, progress: progress)
            statusMessage = "Codex progress: \(progress.displayName)."
        } catch {
            statusMessage = safeMessage(for: error)
        }
    }

    private func applyTaskProgress(
        pageID: String,
        progress: TaskProgress
    ) async throws {
        try await libraryService.updateTaskProgress(
            pageID: pageID,
            progress: progress
        )
        if let index = notionTasks.firstIndex(where: { $0.id == pageID }) {
            notionTasks[index].progress = progress
        }
    }

    private func taskFieldKey(_ pageID: String, _ field: String) -> String {
        "\(pageID):\(field)"
    }

    private func refreshLibraryAfterDelivery() async {
        await loadLibrary()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            await self?.loadLibrary()
        }
    }

    private static func savedCodexWorkspacePath() -> String {
        if let saved = UserDefaults.standard.string(
            forKey: "clasp.codexWorkspacePath"
        ), !saved.isEmpty {
            return saved
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Data/work/truetest-pm-agenthub",
                isDirectory: true
            )
            .path
    }

    func provisionConnection(
        token: String,
        parentPageID: String
    ) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        do {
            let provisioned: DestinationSet
            if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, hasToken {
                provisioned = try await settingsService.provisionUsingSavedToken(
                    parentPageID: parentPageID
                )
            } else {
                provisioned = try await settingsService.provisionAndSave(
                    token: token,
                    parentPageID: parentPageID
                )
            }
            try await refresh()
            hasToken = true
            statusMessage = "Created or connected \(provisioned.tasks.dataSourceName) and \(provisioned.bookmarks.dataSourceName)."
            return true
        } catch {
            statusMessage = safeMessage(for: error)
            return false
        }
    }

    func removeConnection() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await settingsService.removeConnection()
            try await refresh()
            statusMessage = "Notion connection removed."
        } catch {
            statusMessage = safeMessage(for: error)
        }
    }

    func retry(_ capture: Capture) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await deliveryCoordinator.retry(id: capture.id)
            try await refresh()
            statusMessage = result.delivery == .delivered
                ? "Capture delivered."
                : "Capture is still pending."
        } catch {
            statusMessage = safeMessage(for: error)
        }
    }

    func delete(_ capture: Capture) async {
        do {
            try await deliveryCoordinator.delete(id: capture.id)
            try await refresh()
        } catch {
            statusMessage = safeMessage(for: error)
        }
    }

    func applyShortcut() {
        if hotKeyManager.register(shortcut) {
            statusMessage = "Shortcut set to \(shortcut.displayName)."
        } else {
            statusMessage = shortcut.isValid
                ? "That shortcut is already in use. Choose another."
                : "A shortcut must include Command or Control."
        }
    }

    func requestAccessibilityPermission() {
        _ = AccessibilitySelectionReader.requestPermissionPrompt()
        accessibilityGranted = AccessibilitySelectionReader.hasPermission
        statusMessage = accessibilityGranted
            ? "Accessibility access is enabled."
            : "Grant access in System Settings, then return to Clasp."
    }

    func recheckAccessibilityPermission() {
        accessibilityGranted = AccessibilitySelectionReader.hasPermission
    }

    private func safeMessage(for error: Error) -> String {
        if let claspError = error as? ClaspError {
            return claspError.localizedDescription
        }
        return "Clasp could not complete that action. Your saved captures were not removed."
    }
}
