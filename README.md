# Clasp

Clasp is a private, keyboard-first macOS menu-bar utility that turns selected text from another
app into a Task or Bookmark in Notion.

The repository is developed with [GitHub Spec Kit](https://github.com/github/spec-kit). Product
requirements, architecture decisions, contracts, and implementation tasks live in
[`specs/001-capture-to-notion`](specs/001-capture-to-notion/).

## Current MVP

- Captures selected text and source-app context through macOS Accessibility.
- Opens a compact native review panel from a configurable global shortcut.
- Creates Tasks or Bookmarks with optional URL, due date, and tags.
- Creates and validates dedicated `Clasp Tasks` and `Clasp Bookmarks` databases.
- Hands a Task to a persistent Codex conversation with an optional instruction and a dynamically
  discovered local project folder, then mirrors Codex lifecycle progress back to Notion.
- Opens a main window with separate Tasks and Bookmarks tabs loaded from Notion.
- Creates new Tasks and Bookmarks manually without requiring a source-app selection.
- Stores the Notion integration token only in macOS Keychain.
- Persists every confirmed capture locally before network delivery.
- Keeps pending and failed captures available for manual retry.
- Routes each capture to its type-specific database and retains failed captures for retry.
- Uses Accessibility first and, only after the user invokes Capture, falls back to a temporary
  Copy for apps such as Slack that do not expose selected text; the previous clipboard contents
  are restored immediately.
- Sends no analytics or captured data anywhere except the configured Notion workspace.

## Requirements

- macOS 14 or later.
- Apple Silicon for the initial supported release.
- Swift 6 for command-line builds and tests.
- Full Xcode for creating a stable `.app`, signing, notarization, UI tests, and release builds.
- A Notion internal integration with Read content, Insert content, and Update content capabilities.

The Accessibility-based build is intended for direct Developer ID distribution and does not
enable App Sandbox. A sandboxed Mac App Store build cannot provide equivalent arbitrary-app
selection access.

## Notion setup

1. Create a Notion internal integration by following
   [Notion’s official integration setup guide](https://www.notion.com/help/create-integrations-with-the-notion-api).
2. Enable Read content, Insert content, and Update content capabilities.
3. Create or choose a Notion page that will contain Clasp’s databases.
4. [Share that parent page with the integration](https://developers.notion.com/guides/get-started/internal-connections#from-the-notion-ui).
5. Clasp creates these databases automatically:

| Database | Properties |
|---|---|
| Clasp Tasks | Name, Source, Due Date, Priority, Notes, Progress, Done |
| Clasp Bookmarks | Name, Source, Done |

6. In Clasp Settings, enter the integration token and shared parent page URL or ID.
7. Select **Create Clasp Databases**. The token is written to Keychain only after both
   destinations are ready.

Clasp pins the Notion REST API to `2026-03-11`. Setup reuses exact compatible managed database
titles under the parent page, which makes retrying a partially completed setup safe.

## Accessibility permission

Clasp does not request Accessibility access at launch. Settings explains the feature before
opening the macOS prompt. On capture, Clasp snapshots the frontmost app and reads only its
currently selected text. It does not install a general key logger or monitor typing.

Clasp also inspects source metadata around the selected range. It prefers Gmail email URLs,
local file paths, webpage URLs, and exposed Slack message permalinks. Source remains editable
because some app versions expose only a channel/page URL or no location at all.

If permission is denied or an app does not expose selection, Clasp opens an empty editable
draft. Clipboard content appears only after the explicit **Paste** action.

## Build and test

```bash
swift build
swift test
```

Run the command-line development executable:

```bash
swift run ClaspApp
```

Create an ad-hoc-signed local application bundle:

```bash
./scripts/package-app.sh
open dist/Clasp.app
```

On the first launch, Clasp opens its setup window. After setup, it remains in the menu bar;
opening the app again brings the main Tasks and Bookmarks window forward. Use **Open Clasp** from
the menu bar at any time, refresh to load the latest Notion entries, or press `⌘N` to create an
entry in the selected tab.

Set `CLASP_CODESIGN_IDENTITY` to a Developer ID Application identity to create a distribution
candidate. Notarization still requires the full Apple release toolchain and credentials.

The Swift package verifies the app and core code, but `swift run` is not a production app
bundle. Accessibility permission is tied to code identity and executable location, so repeated
development builds outside the packaging script may need permission refreshed. Ad-hoc packages
embed a stable local designated requirement for `com.clasp.app`, while Developer ID builds use
Apple's signed requirement. The packaging script uses
[`Resources/Info.plist`](Resources/Info.plist) and places the stable development bundle at
`dist/Clasp.app`.

The tests use Apple's open-source Swift Testing package only because this machine's standalone
Command Line Tools omit the bundled XCTest/Testing modules. It is a test-only dependency;
Clasp has no third-party runtime dependency.

## Local data and privacy

- Token: macOS Keychain service `com.clasp.app.notion`.
- Capture outbox: `~/Library/Application Support/Clasp/clasp-store.json`.
- Store permissions: owner read/write only (`0600`).
- Store backup: `clasp-store.json.backup`.
- Logs: lifecycle events only; no token, selected text, request payload, or Notion response body.

Deleting a local delivered capture does not delete its Notion page. Removing the connection
removes the token from Keychain and leaves local captures intact.

## Project structure

```text
Sources/
├── ClaspCore/   # Models, atomic outbox, Keychain, Notion client, services
└── ClaspApp/    # Menu-bar lifecycle, Accessibility, hotkey, native views
Tests/
└── ClaspCoreTests/
specs/
└── 001-capture-to-notion/
```

## License

Apache License 2.0. See [`LICENSE`](LICENSE).
