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
        ZStack {
            ClaspBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let notice {
                        noticeBanner(notice)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Capture type", selection: $draft.type) {
                            ForEach(CaptureType.allCases, id: \.self) { type in
                                Label(
                                    type.displayName,
                                    systemImage: type == .task ? "checkmark.circle" : "bookmark"
                                )
                                .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                        .accessibilityLabel("Capture type")

                        HStack {
                            TextField("What do you want to remember?", text: $draft.title)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.large)
                                .focused($focusedField, equals: .title)
                                .accessibilityLabel("Capture name")
                            if draft.type == .bookmark {
                                Button {
                                    pasteBookmarkNameExplicitly()
                                } label: {
                                    Label("Paste", systemImage: "doc.on.clipboard")
                                }
                                .controlSize(.large)
                                .help("Insert clipboard text as the bookmark name")
                                .accessibilityHint("Reads the clipboard only when activated")
                            }
                        }

                        if draft.type == .task {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Notes")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Button {
                                        pasteExplicitly()
                                    } label: {
                                        Label("Paste", systemImage: "doc.on.clipboard")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Insert clipboard text after your explicit action")
                                    .accessibilityHint("Reads the clipboard only when activated")
                                }
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $draft.body)
                                        .font(.body)
                                        .scrollContentBackground(.hidden)
                                        .padding(8)
                                        .focused($focusedField, equals: .content)
                                        .accessibilityLabel("Task notes")
                                    if draft.body.isEmpty {
                                        Text("Add context, details, or the selected text…")
                                            .foregroundStyle(.tertiary)
                                            .padding(.horizontal, 13)
                                            .padding(.vertical, 12)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .frame(minHeight: 138)
                                .background(
                                    Color(nsColor: .textBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                }
                            }
                        }
                    }
                    .claspCard()

                    VStack(alignment: .leading, spacing: 14) {
                        ClaspSectionHeading(
                            "Source",
                            icon: "link",
                            subtitle: "Clasp detected this from \(draft.source.applicationName)"
                        )
                        TextField("URL or file path (optional)", text: $sourceText)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.large)
                            .focused($focusedField, equals: .source)
                            .accessibilityLabel("Source URL or file path")
                    }
                    .claspCard()

                    if draft.type == .task {
                        VStack(alignment: .leading, spacing: 14) {
                            ClaspSectionHeading(
                                "Task details",
                                icon: "slider.horizontal.3",
                                subtitle: "Set priority and an optional due date"
                            )

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

                            Toggle("Add a due date", isOn: $includeDueDate)
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
                        .claspCard()
                    }

                    if let message = validationMessage ?? model.statusMessage {
                        ClaspStatusBanner(
                            message: message,
                            isError: validationMessage != nil
                        )
                    }

                    HStack {
                        Button("Cancel", role: .cancel, action: onCancel)
                            .keyboardShortcut(.cancelAction)
                            .controlSize(.large)
                        Spacer()
                        if model.isBusy {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Saving capture")
                        }
                        Button {
                            save()
                        } label: {
                            Label(
                                draft.type == .task ? "Create Task" : "Save Bookmark",
                                systemImage: draft.type == .task ? "checkmark" : "bookmark"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(ClaspBrand.accent)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(model.isBusy || !canSave)
                    }
                    .padding(.top, 2)
                }
                .padding(22)
            }
        }
        .frame(width: 590)
        .frame(minHeight: 560)
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
        HStack(spacing: 14) {
            ClaspLogoView(size: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text("Capture with Clasp")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                Text("Turn this selection into something you can act on.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
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
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.orange.opacity(0.18), lineWidth: 1)
        }
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
