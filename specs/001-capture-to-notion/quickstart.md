# Quickstart Validation Guide

## Prerequisites

- macOS 14 or later on Apple Silicon.
- Swift 6 toolchain.
- A Notion internal integration with Read content and Insert content capabilities.
- One empty or existing Notion page shared with that integration.

Clasp creates two full-page databases under the shared page:

| Database | Properties |
|---|---|
| Clasp Tasks | Name, Source, Due Date, Priority, Notes |
| Clasp Bookmarks | Name, Source |

## Build and test

```bash
swift build
swift test
./scripts/package-app.sh
open dist/Clasp.app
```

## Configure

1. Launch Clasp and use the setup window.
2. Paste the Notion integration token.
3. Paste the URL or ID of the page shared with the integration.
4. Choose **Create Clasp Databases**.
5. Confirm Settings reports both managed databases ready.

## Main library

1. Reopen Clasp or choose **Open Clasp** from the menu bar.
2. Confirm the Tasks tab loads entries from Clasp Tasks.
3. Switch to Bookmarks and confirm it loads entries from Clasp Bookmarks.
4. Use Refresh to retrieve current remote values.
5. Press `Command-N` in either tab, complete the type-specific form, and create the entry.
6. Confirm the entry appears in the matching Notion database and in Clasp after refresh.
7. Choose Mini, Medium, and Maximum from the menu-bar **Window Mode** menu and confirm their
   menu-only, compact-window, and full-size-window behavior.
8. Grant Accessibility access after reading the explanation.
9. Choose and apply a global shortcut.

## Capture routing

1. Select text, invoke Clasp, and choose Task.
2. Review Name, Notes, Source, Due Date, and Priority.
3. Save and confirm a row appears only in `Clasp Tasks`.
4. Repeat as Bookmark and confirm Name and Source appear only in `Clasp Bookmarks`.

## Source provenance

Verify the editable Source field contains:

- A Gmail thread URL when selecting text in an open Gmail email.
- A POSIX path when selecting text in a local document whose app exposes `AXDocument`.
- The current page URL for a browser webpage.
- A Slack message permalink when Slack exposes one near the selected message.

If an app exposes only a broader location or no source, verify Clasp leaves the field editable
and does not invent a permalink.

## Recovery and privacy

1. Disable networking and save a capture; verify it remains Pending after restart.
2. Restore networking and retry.
3. Confirm the Keychain token, selected Notes, and Notion payload never appear in logs.
4. Verify keyboard navigation, VoiceOver labels, dark mode, and increased text size.
