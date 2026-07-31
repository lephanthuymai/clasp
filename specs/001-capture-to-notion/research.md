# Phase 0 Research: Capture Selected Text to Notion

## Native macOS shell and capture panel

**Decision**: Use a SwiftUI application shell with `MenuBarExtra`, accessory activation policy,
and an AppKit-managed `NSPanel` for the editable capture surface. Snapshot the frontmost app
and read its selection before activating Clasp.

**Rationale**: SwiftUI provides current native menu and form controls, while `NSPanel` gives
deterministic first-responder, Escape, Space, and multi-display behavior. Reading first avoids
replacing the source app's focused accessibility element with Clasp's own UI.

**Alternatives considered**:

- Pure AppKit: capable but adds boilerplate without improving selection capture.
- Pure SwiftUI window scenes: simpler, but less reliable for programmatic key-window activation.
- A nonactivating panel: preserves source focus but conflicts with keyboard-heavy editing.

**Risks and mitigations**: Source focus may change or the source app may exit during capture.
Treat source context as a snapshot and return a typed, recoverable unavailable state.

References: [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra),
[activation policy](https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum/accessory),
[NSPanel](https://developer.apple.com/documentation/appkit/nspanel).

## Selection access and permission

**Decision**: Use `AXUIElementCreateApplication(sourcePID)`, retrieve the focused UI element,
then read `kAXSelectedTextAttribute`. Best-effort source metadata may use the accessibility URL
or document attribute. Request trust only after an explanatory screen and use
`AXIsProcessTrustedWithOptions` for the system prompt. If selection is unavailable, open an
empty editor and expose an explicit Paste action.

**Rationale**: Accessibility exposes the actual current selection without modifying the
clipboard. Explicit paste preserves user awareness and prevents unrelated clipboard content
from being silently captured.

**Alternatives considered**:

- Simulating Command-C: rejected because it mutates the clipboard and is timing-sensitive.
- Reading the clipboard automatically: rejected by the privacy and user-control principles.
- System-wide focused element: valid but more race-prone than scoping to the captured PID.

**Risks and mitigations**: Some custom controls, terminals, PDFs, web canvases, and secure text
fields do not expose selection. AX messaging can also time out. Return typed outcomes
(`permissionDenied`, `noSelection`, `unsupported`, `sourceUnresponsive`) and never include raw
selected text in diagnostics.

References: [AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement_h),
[selected text](https://developer.apple.com/documentation/applicationservices/kaxselectedtextattribute),
[trust prompt](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions).

## Global shortcut

**Decision**: Wrap `RegisterEventHotKey` behind `GlobalShortcutRegistrar`. Require Command or
Control, store the user's chosen modifiers/key in preferences, detect registration collisions,
and unregister on shutdown.

**Rationale**: A registered hotkey is narrower than a global key monitor or event tap and does
not require observing the user's general keyboard stream.

**Alternatives considered**:

- Global `NSEvent` monitor: broader observation, misses events sent to Clasp, and adds permission
  concerns.
- Core Graphics event tap: more machinery and privilege than a single shortcut requires.
- Third-party hotkey package: unnecessary for the MVP and contrary to the dependency constraint.

**Risks and mitigations**: Carbon hotkeys are a legacy interface, layouts differ, and a
combination may already be taken. Isolate the adapter and surface registration failure in
Settings.

## Distribution model

**Decision**: Target a signed and notarized Developer ID build outside the Mac App Store and do
not enable App Sandbox for the Accessibility capture build.

**Rationale**: Arbitrary cross-application Accessibility access is incompatible with a normal
sandboxed Mac App Store architecture. Direct distribution matches the stated MVP assumption.

**Alternatives considered**: A sandboxed edition based on Services or manual paste could be
offered later, but it would not provide equivalent capture-from-any-app behavior.

Reference: [App Sandbox and user data](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox).

## Local persistence, concurrency, and secrets

**Decision**: Use Swift 6 strict concurrency. Models are `Codable & Sendable`; an actor owns a
versioned JSON snapshot in Application Support and writes it atomically with owner-only file
permissions. Persist `.pending` before networking and then `.delivered` or `.failed`. Store only
the Notion token in Keychain as a generic password.

**Rationale**: The MVP is a small single-user outbox. Codable storage is transparent,
migratable, testable with Command Line Tools, and avoids framework or macro dependencies.
Keychain is the platform facility for small secrets.

**Alternatives considered**:

- SwiftData: rejected for the bootstrap because the current machine lacks the SwiftData macro
  implementation supplied by full Xcode, and the data model does not yet justify it.
- Core Data: mature but disproportionate setup for a small outbox.
- SQLite: stronger querying but unnecessary binding and migration complexity.
- JSON Lines: append-friendly but requires compaction and more recovery logic.

**Risks and mitigations**: Whole-file writes do not coordinate multiple app instances and grow
with history. Enforce one instance, serialize in-process mutations, maintain a last-known-good
backup, and reconsider a database after measured scale warrants it.

References: [Keychain Services](https://developer.apple.com/documentation/security/keychain-services),
[safe file replacement](https://developer.apple.com/documentation/foundation/filemanager).

## Networking and deterministic tests

**Decision**: Use async `URLSession` behind an `HTTPTransport` protocol. Test request
construction, schema validation, state transitions, and retries using in-memory repositories,
fake credentials, fixed clocks/UUIDs, and fake transports. Keep real Keychain and Notion tests
opt-in.

**Rationale**: Protocol boundaries make tests deterministic and prevent development tests from
requiring personal credentials, network access, or Accessibility permission.

**Alternatives considered**: Calling `URLSession.shared` and Keychain statically was rejected
because it couples core behavior to global state.

Reference: [async URLSession](https://developer.apple.com/documentation/foundation/urlsession/data%28for%3Adelegate%3A%29).

## Current Notion destination model

**Decision**: Pin `Notion-Version: 2026-03-11`. Accept a database ID, retrieve it, resolve a
single child data source or ask the user to choose, then persist the data source ID. Retrieve
that data source to validate its schema. Store stable Notion property IDs after validation and
use them in page-create and query payloads.

**Rationale**: Since API version `2025-09-03`, a database is a container and each data source
owns an independent schema. Property IDs survive user renames.

**Alternatives considered**:

- Legacy database query/page-parent calls: rejected because they are deprecated for
  multi-source databases.
- Pinning `2025-09-03`: workable but not current; the MVP does not use APIs affected by the
  small `2026-03-11` changes.
- Automatically creating missing columns/options: deferred because it requires broader
  permissions and can surprise users.

References: [current API version](https://developers.notion.com/reference/versioning),
[database/data source model](https://developers.notion.com/reference/database),
[2025-09-03 upgrade](https://developers.notion.com/guides/get-started/upgrade-guide-2025-09-03).

## Notion delivery, limits, and idempotency

**Decision**: Create pages with `POST /v1/pages` and a `data_source_id` parent. A stable local
UUID is written to required rich-text property `Clasp ID`. Before every retry—and after any
ambiguous failure—query the data source for that ID. A match is reconciled as delivered rather
than creating again. Split rich-text content into chunks of at most 2,000 characters.

**Rationale**: Notion exposes no create-page idempotency key. A durable application ID provides
best-effort exactly-once behavior and permits reconciliation after a timeout.

**Alternatives considered**:

- Notion `unique_id`: assigned only after creation and cannot reconcile an ambiguous create.
- Title or URL dedupe: legitimate items can share them.
- Blind retries: can create duplicates after a successful but timed-out response.

**Risks and mitigations**: Notion does not enforce uniqueness for `Clasp ID`; serialize the
local sync worker. Respect HTTP 429/529 `Retry-After`, use bounded jittered backoff for
409/502/503/504, reconcile before retrying 500/timeouts, and require user correction for
400/401/403/404. Keep failed items in the outbox.

References: [Create a page](https://developers.notion.com/reference/post-page),
[Query/filter a data source](https://developers.notion.com/reference/filter-data-source-entries),
[request limits](https://developers.notion.com/reference/request-limits).

## 2026-07-30 amendment: Clasp-managed databases

**Superseding decision**: Setup accepts a shared parent page and uses `POST /v1/databases` to
find-or-create separate `Clasp Tasks` and `Clasp Bookmarks` databases with their initial data
sources. Exact compatible titles under the same parent are reused after partial setup. This
supersedes user-managed schema validation and the remote `Clasp ID` property.

The requested schemas intentionally contain no internal idempotency property. Clasp still
persists locally before delivery and classifies an uncertain create as ambiguous, but the user
must check Notion before retrying an ambiguous request because the current Create Page API does
not expose an idempotency key.

Source is rich text rather than a URL property: HTTPS values use a rich-text link, while local
file sources remain valid POSIX paths. Accessibility discovery prefers selection-local URL
metadata, then document/window metadata, and treats Slack message permalinks as best-effort.

References: [Create a database](https://developers.notion.com/reference/create-database),
[Create a page](https://developers.notion.com/reference/post-page).
