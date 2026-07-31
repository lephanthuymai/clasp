import AppKit
import ClaspCore
import SwiftUI

struct LibraryView: View {
    @ObservedObject var model: AppModel
    @State private var selectedType: CaptureType = .task
    @State private var showingNewEntry = false
    @State private var askCodexItem: NotionListItem?
    @State private var deleteConfirmationItem: NotionListItem?

    var body: some View {
        VStack(spacing: 0) {
            ClaspBrandHeader(
                subtitle: "Your central task and bookmark management",
                logoSize: 34
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            Picker("Library", selection: $selectedType) {
                Label("Tasks", systemImage: "checkmark.circle")
                    .tag(CaptureType.task)
                Label("Bookmarks", systemImage: "bookmark")
                    .tag(CaptureType.bookmark)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .padding(.vertical, 10)

            Divider()

            switch selectedType {
            case .task:
                itemList(
                    model.notionTasks,
                    type: .task,
                    emptyTitle: "No Tasks",
                    emptyDescription: "Create a task here or capture one from another app."
                )
            case .bookmark:
                itemList(
                    model.notionBookmarks,
                    type: .bookmark,
                    emptyTitle: "No Bookmarks",
                    emptyDescription: "Create a bookmark here or capture one from another app."
                )
            }

            if let message = model.statusMessage {
                Divider()
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .textSelection(.enabled)
                    .accessibilityLabel("Status: \(message)")
            }
        }
        .navigationTitle("Clasp")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await model.loadLibrary() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLibraryLoading)

                Button {
                    showingNewEntry = true
                } label: {
                    Label(
                        selectedType == .task ? "New Task" : "New Bookmark",
                        systemImage: "plus"
                    )
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(model.destinations == nil)
            }
        }
        .overlay {
            if model.isLibraryLoading
                && model.notionTasks.isEmpty
                && model.notionBookmarks.isEmpty {
                ProgressView("Loading from Notion…")
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            ManualEntryView(model: model, type: selectedType)
        }
        .sheet(item: $askCodexItem) { item in
            AskCodexView(model: model, item: item)
        }
        .confirmationDialog(
            "Move this \(deleteConfirmationItem?.type.displayName.lowercased() ?? "entry") to Notion Trash?",
            isPresented: Binding(
                get: { deleteConfirmationItem != nil },
                set: { if !$0 { deleteConfirmationItem = nil } }
            ),
            titleVisibility: .visible,
            presenting: deleteConfirmationItem
        ) { item in
            Button("Move to Trash", role: .destructive) {
                deleteConfirmationItem = nil
                Task { await model.delete(item) }
            }
            Button("Cancel", role: .cancel) {
                deleteConfirmationItem = nil
            }
        } message: { item in
            Text(
                "“\(displayTitle(for: item))” will be removed from Clasp and moved to Notion Trash, where it can be restored."
            )
        }
        .task {
            await model.load()
            await model.loadLibrary()
        }
    }

    @ViewBuilder
    private func itemList(
        _ items: [NotionListItem],
        type: CaptureType,
        emptyTitle: String,
        emptyDescription: String
    ) -> some View {
        if items.isEmpty, !model.isLibraryLoading {
            ContentUnavailableView {
                Label(
                    emptyTitle,
                    systemImage: type == .task ? "checkmark.circle" : "bookmark"
                )
            } description: {
                Text(emptyDescription)
            } actions: {
                Button(type == .task ? "New Task" : "New Bookmark") {
                    selectedType = type
                    showingNewEntry = true
                }
            }
        } else {
            switch type {
            case .task:
                taskTable(items)
            case .bookmark:
                bookmarkTable(items)
            }
        }
    }

    private func taskTable(_ items: [NotionListItem]) -> some View {
        Table(items) {
            TableColumn("Done") { item in
                completionToggle(for: item)
            }
            .width(54)

            TableColumn("Name") { item in
                Text(displayTitle(for: item))
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .help(displayTitle(for: item))
            }
            .width(min: 145, ideal: 180, max: 220)

            TableColumn("Priority") { item in
                priorityEditor(for: item)
            }
            .width(min: 90, ideal: 100, max: 115)

            TableColumn("Due Date") { item in
                TaskDueDateEditor(model: model, item: item)
            }
            .width(min: 100, ideal: 110, max: 125)

            TableColumn("Progress") { item in
                progressCell(for: item)
            }
            .width(min: 92, ideal: 105, max: 120)

            TableColumn("Notes") { item in
                Text(item.notes.isEmpty ? "—" : item.notes)
                    .lineLimit(2)
                    .foregroundStyle(item.notes.isEmpty ? .tertiary : .secondary)
                    .help(item.notes)
            }
            .width(min: 105, ideal: 130, max: 160)

            TableColumn("Source") { item in
                sourceCell(for: item)
            }
            .width(min: 125, ideal: 160, max: 210)

            TableColumn("Codex") { item in
                askCodexButton(for: item)
            }
            .width(min: 125, ideal: 140, max: 160)

            TableColumn("Notion") { item in
                notionLink(for: item)
            }
            .width(52)

            TableColumn("Actions") { item in
                deleteButton(for: item)
            }
            .width(58)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .accessibilityLabel("Notion tasks table")
    }

    private func bookmarkTable(_ items: [NotionListItem]) -> some View {
        Table(items) {
            TableColumn("Done") { item in
                completionToggle(for: item)
            }
            .width(54)

            TableColumn("Name") { item in
                Text(displayTitle(for: item))
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .help(displayTitle(for: item))
            }
            .width(min: 190, ideal: 280)

            TableColumn("Source") { item in
                sourceCell(for: item)
            }
            .width(min: 240, ideal: 380)

            TableColumn("Notion") { item in
                notionLink(for: item)
            }
            .width(52)

            TableColumn("Actions") { item in
                deleteButton(for: item)
            }
            .width(58)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .accessibilityLabel("Notion bookmarks table")
    }

    private func completionToggle(for item: NotionListItem) -> some View {
        // An explicit action avoids Table mutating a synthetic Toggle binding while rows load.
        Button {
            Task { await model.markDone(item) }
        } label: {
            Image(systemName: "square")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.completingItemIDs.contains(item.id))
        .help("Mark as done")
        .accessibilityLabel("Mark \(displayTitle(for: item)) done")
        .accessibilityAddTraits(.isToggle)
    }

    private func deleteButton(for item: NotionListItem) -> some View {
        Button {
            deleteConfirmationItem = item
        } label: {
            if model.deletingItemIDs.contains(item.id) {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .disabled(
            model.deletingItemIDs.contains(item.id)
                || item.progress == .working
        )
        .help(
            item.progress == .working
                ? "Wait for Codex to finish before deleting"
                : "Move to Notion Trash"
        )
        .accessibilityLabel("Delete \(displayTitle(for: item))")
    }

    @ViewBuilder
    private func priorityEditor(for item: NotionListItem) -> some View {
        if model.isUpdatingTaskField(item, field: "priority") {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Updating priority")
        } else {
            Menu {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Button {
                        Task {
                            _ = await model.updateTaskPriority(
                                item,
                                priority: priority
                            )
                        }
                    } label: {
                        if item.priority == priority {
                            Label(priority.displayName, systemImage: "checkmark")
                        } else {
                            Text(priority.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "flag")
                    Text(item.priority?.displayName ?? "Set")
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Change priority")
            .accessibilityLabel(
                "Priority, \(item.priority?.displayName ?? "not set"). Change priority"
            )
        }
    }

    private func progressCell(for item: NotionListItem) -> some View {
        Label(item.progress.displayName, systemImage: progressIcon(item.progress))
            .font(.callout)
            .foregroundStyle(progressColor(item.progress))
            .lineLimit(1)
            .help("Codex progress: \(item.progress.displayName)")
    }

    @ViewBuilder
    private func askCodexButton(for item: NotionListItem) -> some View {
        if let threadID = model.codexThreadID(for: item),
           let destination = URL(string: "codex://threads/\(threadID)") {
            if item.progress == .working {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Working…")
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .help("Codex is working on \(item.taskID)")
                .accessibilityLabel("Codex is working on \(displayTitle(for: item))")
            } else {
                Link(destination: destination) {
                    Label("Open Conversation", systemImage: "bubble.left.and.bubble.right")
                        .lineLimit(1)
                }
                .help("Open \(item.taskID) in Codex")
                .accessibilityLabel(
                    "Open Codex conversation for \(displayTitle(for: item))"
                )
            }
        } else if model.askingCodexTaskIDs.contains(item.id) {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Starting Codex for \(displayTitle(for: item))")
        } else {
            Button {
                askCodexItem = item
            } label: {
                Label("Ask Codex", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Create a Codex conversation for \(item.taskID)")
        }
    }

    private func progressIcon(_ progress: TaskProgress) -> String {
        switch progress {
        case .notStarted: "circle"
        case .working: "bolt.circle"
        case .waiting: "pause.circle"
        case .completed: "checkmark.circle"
        case .failed: "exclamationmark.circle"
        }
    }

    private func progressColor(_ progress: TaskProgress) -> Color {
        switch progress {
        case .notStarted: .secondary
        case .working: .blue
        case .waiting: .orange
        case .completed: .green
        case .failed: .red
        }
    }

    @ViewBuilder
    private func sourceCell(for item: NotionListItem) -> some View {
        if item.source.isEmpty {
            Text("—")
                .foregroundStyle(.tertiary)
        } else if let url = SourceLocationResolver.normalize(item.source),
                  !url.isFileURL {
            Link(destination: url) {
                Label(item.source, systemImage: "link")
                    .lineLimit(1)
            }
            .help(item.source)
        } else {
            Label(item.source, systemImage: "doc")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .help(item.source)
        }
    }

    @ViewBuilder
    private func notionLink(for item: NotionListItem) -> some View {
        if let url = item.url {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Label("Open in Notion", systemImage: "arrow.up.right.square")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Open in Notion")
        } else {
            Text("—")
                .foregroundStyle(.tertiary)
        }
    }

    private func displayTitle(for item: NotionListItem) -> String {
        item.title.isEmpty ? "Untitled" : item.title
    }
}

private struct AskCodexView: View {
    @ObservedObject var model: AppModel
    let item: NotionListItem

    @Environment(\.dismiss) private var dismiss
    @State private var instruction = ""
    @FocusState private var instructionFocused: Bool

    private var isStarting: Bool {
        model.askingCodexTaskIDs.contains(item.id)
    }

    private var taskTitle: String {
        item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled Task"
            : item.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var distinctNotes: String? {
        let notes = item.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notes.isEmpty,
              notes.localizedCaseInsensitiveCompare(taskTitle) != .orderedSame
        else {
            return nil
        }
        return notes
    }

    private var workspaceName: String {
        URL(
            fileURLWithPath: model.codexWorkspacePath,
            isDirectory: true
        ).lastPathComponent
    }

    var body: some View {
        VStack(spacing: 0) {
            dialogHeader
            Divider()

            VStack(alignment: .leading, spacing: 20) {
                taskContext
                instructionEditor
                workspaceDisclosure
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)

            Divider()
            actionFooter
        }
        .frame(width: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            instructionFocused = true
        }
    }

    private var dialogHeader: some View {
        HStack(spacing: 13) {
            ClaspLogoView(size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Ask Codex")
                    .font(.title2.weight(.semibold))
                Text("Turn this task into an active Codex conversation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Text(item.taskID)
                .font(.caption.monospaced().weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var taskContext: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("TASK CONTEXT", systemImage: "checkmark.square")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)

            Text(taskTitle)
                .font(.headline)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if let notes = distinctNotes {
                Text(notes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 14) {
                if let priority = item.priority {
                    Label(priority.displayName, systemImage: "flag")
                }
                if let dueDate = item.dueDate {
                    Label {
                        Text(dueDate, format: .dateTime.year().month().day())
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Color.accentColor.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor.opacity(0.14), lineWidth: 1)
        }
    }

    private var instructionEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Instruction")
                    .font(.headline)
                Text("Optional")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $instruction)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .focused($instructionFocused)

                if instruction.isEmpty {
                    Text("What would you like Codex to do?")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 112)
            .background(
                Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        instructionFocused
                            ? Color.accentColor.opacity(0.75)
                            : Color.secondary.opacity(0.22),
                        lineWidth: instructionFocused ? 2 : 1
                    )
            }
        }
    }

    private var workspaceDisclosure: some View {
        HStack(spacing: 9) {
            Image(systemName: "folder")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Runs in \(workspaceName)")
                    .font(.callout.weight(.medium))
                Text(model.codexWorkspacePath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var actionFooter: some View {
        HStack(spacing: 12) {
            Text("Codex opens when the task is ready for you.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .disabled(isStarting)

            if isStarting {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                Task {
                    if await model.askCodex(item, instruction: instruction) {
                        dismiss()
                    }
                }
            } label: {
                Label("Start in Codex", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(isStarting)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

private struct TaskDueDateEditor: View {
    @ObservedObject var model: AppModel
    let item: NotionListItem

    @State private var showingEditor = false
    @State private var selectedDate = Date()

    private var isUpdating: Bool {
        model.isUpdatingTaskField(item, field: "due-date")
    }

    var body: some View {
        Button {
            selectedDate = item.dueDate ?? Calendar.current.startOfDay(for: Date())
            showingEditor = true
        } label: {
            HStack(spacing: 5) {
                if isUpdating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "calendar")
                    if let dueDate = item.dueDate {
                        Text(dueDate, format: .dateTime.year().month().day())
                    } else {
                        Text("Set date")
                            .foregroundStyle(.tint)
                    }
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isUpdating)
        .help(item.dueDate == nil ? "Set due date" : "Change due date")
        .accessibilityLabel(
            item.dueDate == nil ? "Set due date" : "Change due date"
        )
        .popover(isPresented: $showingEditor) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Due Date")
                    .font(.headline)

                DatePicker(
                    "Due date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                HStack {
                    if item.dueDate != nil {
                        Button("Clear") {
                            save(nil)
                        }
                        .disabled(isUpdating)
                    }

                    Spacer()

                    Button("Cancel", role: .cancel) {
                        showingEditor = false
                    }
                    .disabled(isUpdating)

                    Button("Save") {
                        save(selectedDate)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUpdating)
                }
            }
            .padding(16)
            .frame(width: 280)
        }
    }

    private func save(_ dueDate: Date?) {
        Task {
            if await model.updateTaskDueDate(item, dueDate: dueDate) {
                showingEditor = false
            }
        }
    }
}

private struct ManualEntryView: View {
    @ObservedObject var model: AppModel
    let type: CaptureType

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var source = ""
    @State private var notes = ""
    @State private var priority: TaskPriority = .medium
    @State private var includeDueDate = false
    @State private var dueDate = Date()
    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(type == .task ? "New Task" : "New Bookmark")
                .font(.title2.weight(.semibold))

            Form {
                TextField("Name", text: $title)
                    .textFieldStyle(.roundedBorder)

                TextField("Source URL or file path", text: $source)
                    .textFieldStyle(.roundedBorder)

                if type == .task {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }

                    Toggle("Due date", isOn: $includeDueDate)
                    if includeDueDate {
                        DatePicker(
                            "Due",
                            selection: $dueDate,
                            displayedComponents: .date
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                        TextEditor(text: $notes)
                            .frame(minHeight: 120)
                            .padding(4)
                            .background(
                                .quaternary.opacity(0.35),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                }
            }
            .formStyle(.grouped)

            if let validationMessage {
                Text(validationMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("Create") {
                    create()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.isBusy || !canCreate)
            }
        }
        .padding(22)
        .frame(width: 500)
        .frame(minHeight: type == .task ? 500 : 260)
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (type == .bookmark
                || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func create() {
        validationMessage = nil
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceURL: URL?
        if trimmedSource.isEmpty {
            sourceURL = nil
        } else if let normalized = SourceLocationResolver.normalize(trimmedSource) {
            sourceURL = normalized
        } else {
            validationMessage = ClaspError.invalidURL.localizedDescription
            return
        }

        let draft = CaptureDraft(
            title: title,
            body: type == .task ? notes : "",
            type: type,
            source: SourceContext(
                applicationName: "Clasp",
                bundleIdentifier: "com.clasp.app",
                sourceURL: sourceURL
            ),
            dueDate: type == .task && includeDueDate ? dueDate : nil,
            priority: type == .task ? priority : nil
        )
        Task {
            if await model.createManual(draft) {
                dismiss()
            }
        }
    }
}
