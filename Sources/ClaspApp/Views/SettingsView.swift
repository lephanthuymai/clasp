import AppKit
import ClaspCore
import SwiftUI

struct SettingsView: View {
    private static let notionIntegrationGuideURL = URL(
        string: "https://www.notion.com/help/create-integrations-with-the-notion-api"
    )!
    private static let notionPageAccessGuideURL = URL(
        string: "https://developers.notion.com/guides/get-started/internal-connections#from-the-notion-ui"
    )!

    @ObservedObject var model: AppModel

    @State private var token = ""
    @State private var parentPageID = ""
    @State private var codexWorkspacePath = ""
    @State private var showingRemoveConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            ClaspBrandHeader(
                subtitle: "Settings",
                logoSize: 42
            )
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 10)

            Form {
                notionSection
                codexSection
                permissionSection
                shortcutSection

                if let message = model.statusMessage {
                    Section("Status") {
                        Text(message)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .accessibilityLabel("Status: \(message)")
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 580)
        .frame(minHeight: 660)
        .task {
            await model.load()
            parentPageID = model.destinations?.parentPageID ?? parentPageID
            codexWorkspacePath = model.codexWorkspacePath
        }
        .confirmationDialog(
            "Remove the Notion connection?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Connection", role: .destructive) {
                Task { await model.removeConnection() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The token and local destination mapping will be removed. The Notion databases and local captures will remain.")
        }
    }

    private var codexSection: some View {
        Section {
            TextField("Codex workspace folder", text: $codexWorkspacePath)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Codex workspace folder")

            HStack {
                Button("Choose Folder…") {
                    chooseCodexWorkspaceFolder()
                }
                Spacer()
                Button("Save Workspace") {
                    if model.saveCodexWorkspacePath(codexWorkspacePath) {
                        codexWorkspacePath = model.codexWorkspacePath
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        } header: {
            Text("Codex")
        } footer: {
            Text(
                "New Ask Codex conversations run in this folder and inherit its project instructions, skills, and configuration."
            )
        }
    }

    private func chooseCodexWorkspaceFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Codex Workspace"
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if !codexWorkspacePath.isEmpty {
            panel.directoryURL = URL(
                fileURLWithPath: codexWorkspacePath,
                isDirectory: true
            )
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        codexWorkspacePath = url.path
        if model.saveCodexWorkspacePath(url.path) {
            codexWorkspacePath = model.codexWorkspacePath
        }
    }

    private var notionSection: some View {
        Section {
            destinationStatus

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Notion integration token")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Link(destination: Self.notionIntegrationGuideURL) {
                        Label("How to get a token", systemImage: "questionmark.circle")
                    }
                    .font(.caption)
                    .accessibilityHint("Opens Notion’s integration setup guide in your browser")
                }
                SecureField(
                    model.hasToken
                        ? "Leave blank to keep the token stored in Keychain"
                        : "Paste your Notion integration token",
                    text: $token
                )
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)
                .accessibilityLabel("Notion integration token")
            }
            .padding(.vertical, 3)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Parent page URL or ID")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Link(destination: Self.notionPageAccessGuideURL) {
                        Label("How to connect a page", systemImage: "link")
                    }
                    .font(.caption)
                    .accessibilityHint("Opens Notion’s page access instructions in your browser")
                }
                TextField("Paste the shared Notion page URL or ID", text: $parentPageID)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                    .accessibilityLabel("Notion parent page URL or ID")
                Text("Clasp creates “Clasp Tasks” and “Clasp Bookmarks” as full-page databases under this page.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 3)

            HStack {
                Button(model.destinations == nil ? "Create Clasp Databases" : "Find or Revalidate") {
                    Task {
                        let succeeded = await model.provisionConnection(
                            token: token,
                            parentPageID: parentPageID
                        )
                        if succeeded {
                            token = ""
                            parentPageID = model.destinations?.parentPageID ?? parentPageID
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || setupValuesMissing)

                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Creating or validating Clasp databases")
                }

                Spacer()

                if model.hasToken {
                    Button("Remove…", role: .destructive) {
                        showingRemoveConfirmation = true
                    }
                }
            }

            if setupValuesMissing {
                Text("Enter an integration token and shared parent page to enable setup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DisclosureGroup("Databases Clasp creates") {
                VStack(alignment: .leading, spacing: 8) {
                    schemaRow(
                        "Clasp Tasks",
                        "Name · Source · Due Date · Priority · Notes · Created Date · Progress · Done"
                    )
                    schemaRow(
                        "Clasp Bookmarks",
                        "Name · Source · Created Date · Done"
                    )
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Notion")
        } footer: {
            Text("Enable Read, Insert, and Update content, then share the parent page with your integration. The token stays in your Mac’s Keychain.")
        }
    }

    @ViewBuilder
    private var destinationStatus: some View {
        if let destinations = model.destinations {
            VStack(alignment: .leading, spacing: 5) {
                Label("Both databases ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Tasks: \(destinations.tasks.dataSourceName)")
                Text("Bookmarks: \(destinations.bookmarks.dataSourceName)")
            }
            .font(.callout)
        } else {
            LabeledContent("Connection") {
                Label("Not configured", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var setupValuesMissing: Bool {
        parentPageID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (!model.hasToken
                && token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var permissionSection: some View {
        Section {
            LabeledContent("Selection access") {
                Label(
                    model.accessibilityGranted ? "Enabled" : "Not enabled",
                    systemImage: model.accessibilityGranted
                        ? "checkmark.circle.fill"
                        : "lock.circle"
                )
                .foregroundStyle(model.accessibilityGranted ? .green : .secondary)
            }

            Text(
                "Clasp reads the selected text and exposed source metadata only when you invoke Capture. It does not monitor typing."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack {
                Button("Request Access") {
                    model.requestAccessibilityPermission()
                }
                Button("Open Privacy Settings") {
                    if let url = URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    ) {
                        NSWorkspace.shared.open(url)
                    }
                }
                Spacer()
                Button("Check Again") {
                    model.recheckAccessibilityPermission()
                }
            }
        } header: {
            Text("Accessibility Permission")
        }
    }

    private var shortcutSection: some View {
        Section {
            Picker("Key", selection: $model.shortcut.keyCode) {
                ForEach(GlobalShortcut.availableKeys, id: \.code) { key in
                    Text(key.label).tag(key.code)
                }
            }
            .onChange(of: model.shortcut.keyCode) { _, code in
                model.shortcut.keyLabel = GlobalShortcut.availableKeys
                    .first(where: { $0.code == code })?.label ?? "Key"
            }

            HStack {
                Toggle("⌘ Command", isOn: $model.shortcut.command)
                Toggle("⌃ Control", isOn: $model.shortcut.control)
                Toggle("⌥ Option", isOn: $model.shortcut.option)
                Toggle("⇧ Shift", isOn: $model.shortcut.shift)
            }

            HStack {
                Text("Current: \(model.shortcut.displayName)")
                    .monospaced()
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply Shortcut") {
                    model.applyShortcut()
                }
                .disabled(!model.shortcut.isValid)
            }
        } header: {
            Text("Global Shortcut")
        } footer: {
            Text("Clasp registers only this shortcut; it does not install a general keyboard monitor.")
        }
    }

    private func schemaRow(_ database: String, _ fields: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(database).font(.callout.weight(.medium))
            Text(fields).font(.caption).foregroundStyle(.secondary)
        }
    }
}
