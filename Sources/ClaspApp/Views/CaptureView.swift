import AppKit
import ClaspCore
import SwiftUI

struct CaptureView: View {
    @ObservedObject var model: AppModel

    let notice: CapturePreparationNotice?
    let onCancel: () -> Void
    let onSaved: () -> Void

    @State private var draft: CaptureDraft
    @State private var sourceText: String
    @State private var includeDueDate: Bool
    @State private var validationMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case content
        case source
    }

    init(
        model: AppModel,
        initialDraft: CaptureDraft,
        notice: CapturePreparationNotice?,
        onCancel: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        self.model = model
        self.notice = notice
        self.onCancel = onCancel
        self.onSaved = onSaved
        _draft = State(initialValue: initialDraft)
        _sourceText = State(initialValue: initialDraft.source.displaySource)
        _includeDueDate = State(initialValue: initialDraft.dueDate != nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let notice {
                    noticeBanner(notice)
                }

                Picker("Capture type", selection: $draft.type) {
                    ForEach(CaptureType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Capture type")

                HStack {
                    TextField("Name", text: $draft.title)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .title)
                        .accessibilityLabel("Capture name")
                    if draft.type == .bookmark {
                        Button("Paste") {
                            pasteBookmarkNameExplicitly()
                        }
                        .help("Insert clipboard text as the bookmark name")
                        .accessibilityHint("Reads the clipboard only when activated")
                    }
                }

                if draft.type == .task {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Notes")
                                .font(.headline)
                            Spacer()
                            Button("Paste") {
                                pasteExplicitly()
                            }
                            .help("Insert clipboard text after your explicit action")
                            .accessibilityHint("Reads the clipboard only when activated")
                        }
                        TextEditor(text: $draft.body)
                            .font(.body)
                            .frame(minHeight: 130)
                            .padding(5)
                            .background(
                                .quaternary.opacity(0.35),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .focused($focusedField, equals: .content)
                            .accessibilityLabel("Task notes")
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label(draft.source.applicationName, systemImage: "app")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Source application \(draft.source.applicationName)")
                    TextField("Source URL or file path (optional)", text: $sourceText)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .source)
                        .accessibilityLabel("Source URL or file path")
                }

                if draft.type == .task {
                    Picker(
                        "Priority",
                        selection: Binding(
                            get: { draft.priority ?? .medium },
                            set: { draft.priority = $0 }
                        )
                    ) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }

                    Toggle("Due date", isOn: $includeDueDate)
                    if includeDueDate {
                        DatePicker(
                            "Due",
                            selection: Binding(
                                get: { draft.dueDate ?? Date() },
                                set: { draft.dueDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                if let message = validationMessage ?? model.statusMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(validationMessage == nil ? Color.secondary : Color.red)
                        .accessibilityLabel("Status: \(message)")
                }

                HStack {
                    Button("Cancel", role: .cancel, action: onCancel)
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    if model.isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Saving capture")
                    }
                    Button("Save") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.isBusy || !canSave)
                }
            }
            .padding(22)
        }
        .frame(width: 590)
        .frame(minHeight: 520)
        .onAppear { focusedField = .title }
        .onChange(of: draft.type) { _, type in
            if type == .bookmark {
                includeDueDate = false
                draft.dueDate = nil
                draft.priority = nil
            } else if draft.priority == nil {
                draft.priority = .medium
            }
        }
    }

    private var header: some View {
        ClaspBrandHeader(
            subtitle: "Turn this selection into something you can act on.",
            logoSize: 42
        )
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (draft.type == .bookmark
                || !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @ViewBuilder
    private func noticeBanner(_ notice: CapturePreparationNotice) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: notice == .permissionDenied ? "lock.trianglebadge.exclamationmark" : "info.circle")
                .accessibilityHidden(true)
            Text(notice.message)
                .font(.callout)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func save() {
        validationMessage = nil
        let trimmedSource = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSource.isEmpty {
            draft.source.sourceURL = nil
        } else if let url = SourceLocationResolver.normalize(trimmedSource) {
            draft.source.sourceURL = url
        } else {
            validationMessage = ClaspError.invalidURL.localizedDescription
            focusedField = .source
            return
        }
        if draft.type == .task, includeDueDate, draft.dueDate == nil {
            draft.dueDate = Date()
        }

        Task {
            if await model.confirm(draft) {
                onSaved()
            }
        }
    }

    private func pasteExplicitly() {
        if let clipboardText = NSPasteboard.general.string(forType: .string) {
            draft.body = clipboardText
            if draft.title.isEmpty {
                draft.title = CaptureDraft.suggestedTitle(from: clipboardText)
            }
        }
    }

    private func pasteBookmarkNameExplicitly() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string) else {
            return
        }
        let value = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.title = String(value.prefix(2_000))
        draft.body = value
    }
}
