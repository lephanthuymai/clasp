# Tasks: Capture Selected Text to Notion

**Input**: Design documents from `specs/001-capture-to-notion/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`,
`quickstart.md`

**Tests**: Automated tests are required by the project constitution. Story tests are written
before or alongside their implementations and use no real credentials.

**Organization**: Tasks are grouped by user story so each story remains independently testable.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize the native Swift project and repository policy.

- [x] T001 Create the Swift package with ClaspCore library and ClaspApp executable targets in `Package.swift`
- [x] T002 [P] Add Apache-2.0 project licensing in `LICENSE`
- [x] T003 [P] Add Swift/macOS, credentials, and local-store exclusions in `.gitignore`
- [x] T004 Create the planned source and test directory skeleton under `Sources/` and `Tests/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build shared models and boundaries required by every user story.

**⚠️ CRITICAL**: No story implementation begins until these shared contracts compile.

- [x] T005 Create capture, source, delivery, destination, and property-map models in `Sources/ClaspCore/Models/Models.swift`
- [x] T006 [P] Define repository, credential, HTTP, clock, UUID, and Notion service protocols in `Sources/ClaspCore/Services/Protocols.swift`
- [x] T007 [P] Define safe domain and transport errors in `Sources/ClaspCore/Models/ClaspError.swift`
- [x] T008 Implement the versioned actor-isolated atomic JSON store in `Sources/ClaspCore/Persistence/FileCaptureStore.swift`
- [x] T009 [P] Implement the macOS Keychain credential adapter in `Sources/ClaspCore/Persistence/KeychainCredentialStore.swift`
- [x] T010 [P] Implement async URLSession transport and sanitized HTTP responses in `Sources/ClaspCore/Notion/URLSessionHTTPTransport.swift`
- [x] T011 Add foundational model and JSON migration/recovery tests in `Tests/ClaspCoreTests/Persistence/FileCaptureStoreTests.swift`

**Checkpoint**: Models, persistence, secrets, and networking boundaries build and test without UI.

---

## Phase 3: User Story 1 - Capture Selected Text (Priority: P1) 🎯 MVP

**Goal**: Select text in another app, review a Task or Bookmark, durably confirm it, and deliver
it to a preconfigured fake or real destination.

**Independent Test**: With a destination and fake transport, invoke capture with selected text,
save Task and Bookmark drafts, and verify durable records and create-page payloads.

### Tests for User Story 1

- [x] T012 [P] [US1] Add capture normalization and validation tests in `Tests/ClaspCoreTests/Models/CaptureDraftTests.swift`
- [x] T013 [P] [US1] Add create-page request contract tests in `Tests/ClaspCoreTests/Notion/NotionPayloadBuilderTests.swift`
- [x] T014 [P] [US1] Add enqueue-before-delivery service tests in `Tests/ClaspCoreTests/Services/CaptureServiceTests.swift`

### Implementation for User Story 1

- [x] T015 [P] [US1] Implement capture draft normalization in `Sources/ClaspCore/Models/CaptureDraft.swift`
- [x] T016 [P] [US1] Implement Notion property payload construction and rich-text chunking in `Sources/ClaspCore/Notion/NotionPayloadBuilder.swift`
- [x] T017 [US1] Implement durable confirm-and-deliver orchestration in `Sources/ClaspCore/Services/CaptureService.swift`
- [x] T018 [P] [US1] Implement frontmost-app Accessibility selection reading in `Sources/ClaspApp/Selection/AccessibilitySelectionReader.swift`
- [x] T019 [P] [US1] Implement configurable Carbon hotkey registration in `Sources/ClaspApp/HotKey/GlobalHotKeyManager.swift`
- [x] T020 [US1] Implement the keyboard-first SwiftUI capture form in `Sources/ClaspApp/Views/CaptureView.swift`
- [x] T021 [US1] Wire the menu-bar app, capture panel, and core dependencies in `Sources/ClaspApp/App/ClaspApp.swift`

**Checkpoint**: US1 works with a configured destination and is demonstrable from the menu bar.

---

## Phase 4: User Story 2 - Configure and Validate Notion (Priority: P2)

**Goal**: Securely save a token, resolve a database to a data source, validate all required
properties, and persist only stable non-secret configuration.

**Independent Test**: Feed representative Notion database/data-source responses through a fake
transport and verify valid, missing, mismatched, unauthorized, and multi-source outcomes.

### Tests for User Story 2

- [x] T022 [P] [US2] Add database discovery and schema validation contract tests in `Tests/ClaspCoreTests/Notion/NotionClientTests.swift`
- [x] T023 [P] [US2] Add credential save/replace/remove service tests with a fake store in `Tests/ClaspCoreTests/Services/SettingsServiceTests.swift`

### Implementation for User Story 2

- [x] T024 [US2] Implement current-version database discovery, data-source retrieval, and schema validation in `Sources/ClaspCore/Notion/NotionClient.swift`
- [x] T025 [US2] Implement settings and credential orchestration in `Sources/ClaspCore/Services/SettingsService.swift`
- [x] T026 [US2] Implement Notion setup, field validation, token replacement, and shortcut settings UI in `Sources/ClaspApp/Views/SettingsView.swift`
- [x] T027 [US2] Connect Settings window lifecycle and persisted configuration in `Sources/ClaspApp/App/ClaspApp.swift`

**Checkpoint**: Setup detects invalid credentials, inaccessible databases, multiple data sources,
and incompatible fields before capture.

---

## Phase 5: User Story 3 - Recover Failed Captures (Priority: P3)

**Goal**: Preserve pending/failed captures, reconcile uncertain creates by Clasp ID, and support
manual retry without duplicate pages.

**Independent Test**: Simulate offline, timeout-after-create, retryable, and permanent responses;
restart from the stored file and verify recovery and best-effort exactly-once delivery.

### Tests for User Story 3

- [x] T028 [P] [US3] Add delivery state-machine and startup recovery tests in `Tests/ClaspCoreTests/Services/DeliveryCoordinatorTests.swift`
- [x] T029 [P] [US3] Add Clasp-ID query-before-create and ambiguous-failure tests in `Tests/ClaspCoreTests/Notion/NotionDeliveryTests.swift`

### Implementation for User Story 3

- [x] T030 [US3] Implement reconciliation, response classification, and delivery operations in `Sources/ClaspCore/Notion/NotionClient.swift`
- [x] T031 [US3] Implement serialized startup recovery and manual retry coordination in `Sources/ClaspCore/Services/DeliveryCoordinator.swift`
- [x] T032 [US3] Implement recent-captures status, retry, delete confirmation, and open-remote UI in `Sources/ClaspApp/Views/RecentCapturesView.swift`
- [x] T033 [US3] Connect recent-captures window and delivery updates in `Sources/ClaspApp/App/ClaspApp.swift`

**Checkpoint**: Confirmed captures survive restart and can be reconciled or retried without
re-entry.

---

## Phase 6: User Story 4 - Explicit Fallback Capture (Priority: P4)

**Goal**: Keep capture useful when selection access fails while never silently reading the
clipboard.

**Independent Test**: Return each typed selection failure and verify an empty draft appears;
clipboard text appears only after the Paste action.

### Tests for User Story 4

- [x] T034 [P] [US4] Add selection-outcome draft mapping tests in `Tests/ClaspCoreTests/Services/CapturePreparationTests.swift`

### Implementation for User Story 4

- [x] T035 [US4] Implement typed selection-to-draft preparation in `Sources/ClaspCore/Services/CapturePreparation.swift`
- [x] T036 [US4] Add permission, unavailable-selection, explicit Paste, and retry states in `Sources/ClaspApp/Views/CaptureView.swift`
- [x] T037 [US4] Add contextual Accessibility permission explanation and System Settings routing in `Sources/ClaspApp/Views/SettingsView.swift`

**Checkpoint**: Unsupported apps and denied permission produce transparent, editable fallbacks.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Complete privacy, accessibility, documentation, and release-readiness checks.

- [x] T038 [P] Document setup, required Notion schema, privacy behavior, and development commands in `README.md`
- [x] T039 [P] Add app metadata and permission usage strings in `Resources/Info.plist`
- [x] T040 Add safe logging, single-instance behavior, and owner-only store permissions across `Sources/ClaspApp/App/ClaspApp.swift` and `Sources/ClaspCore/Persistence/FileCaptureStore.swift`
- [x] T041 Audit keyboard labels, VoiceOver names, dark mode, and increased text behavior in `Sources/ClaspApp/Views/`
- [x] T042 Run `swift build`, `swift test`, privacy scans, and the scenarios in `specs/001-capture-to-notion/quickstart.md`
- [x] T043 Record completed tasks and any full-Xcode-only validation gaps in `specs/001-capture-to-notion/tasks.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Starts immediately.
- **Foundational (Phase 2)**: Depends on Setup and blocks all stories.
- **US1 (Phase 3)**: Depends on Foundational; provides the MVP capture path.
- **US2 (Phase 4)**: Depends on Foundational and can be tested independently with fake capture
  callers; integrates with US1 for real delivery.
- **US3 (Phase 5)**: Depends on Foundational and the Notion client contract; integrates with US1
  confirmation and US2 configuration.
- **US4 (Phase 6)**: Depends on Foundational and can proceed independently of Notion delivery;
  integrates into the US1 panel.
- **Polish (Phase 7)**: Depends on every story selected for the release.

### User Story Completion Order

```text
Foundational ──┬──> US1 Capture ─────┬──> Polish
               ├──> US2 Setup ───────┤
               ├──> US3 Recovery ────┤
               └──> US4 Fallback ────┘
```

For a single developer, implement P1 → P2 → P3 → P4. US3 consumes the Notion behavior created
for US1/US2, although its core state-machine tests remain independent.

### Parallel Opportunities

- T002 and T003 can run alongside T001.
- T006, T007, T009, and T010 affect separate foundational files.
- Each story's test files marked `[P]` can be authored together before implementation.
- T018 and T019 are independent macOS adapters.
- US2 and US4 can proceed in parallel after the foundation.
- Documentation and app metadata can proceed in parallel during polish.

## Parallel Example: User Story 1

```text
T012: CaptureDraft model tests
T013: NotionPayloadBuilder contract tests
T014: CaptureService orchestration tests

After their contracts are established:
T015: CaptureDraft implementation
T016: NotionPayloadBuilder implementation
T018: AccessibilitySelectionReader adapter
T019: GlobalHotKeyManager adapter
```

## Implementation Strategy

### MVP First

1. Complete Setup and Foundational phases.
2. Complete US1 using a fixture destination and fake transport.
3. Validate local persistence and the menu-bar capture panel.
4. Add US2 to enable real self-service Notion setup.

### Incremental Delivery

1. US1 proves selection-to-durable-capture value.
2. US2 makes that value usable against a real Notion workspace.
3. US3 establishes trust through recovery and deduplication.
4. US4 expands app compatibility without weakening privacy.
5. Polish prepares direct signed/notarized distribution.

## Notes

- `[P]` tasks touch distinct files and can proceed concurrently.
- Story labels map directly to `spec.md` acceptance scenarios.
- Tests never use a personal Keychain entry, Accessibility permission, or live Notion token.
- Full signing, notarization, stable Accessibility identity, and UI automation require full Xcode.

## Validation Record

Completed on 2026-07-30:

- `plutil -lint Resources/Info.plist` passed.
- Debug `swift build` passed.
- `swift test` passed all 29 tests.
- Release `dist/Clasp.app` packaging and ad-hoc code-sign verification passed.
- Both the SwiftPM executable and packaged `.app` launched without an immediate runtime failure.
- The packaged app presented a visible `Clasp Settings` window on an unconfigured launch.
- Source privacy scans found no token-shaped secrets, debug printing, captured-body logging, or
  trailing whitespace.
- Source inspection confirmed standard controls, keyboard shortcuts, accessibility labels,
  text-plus-color delivery states, system colors, and scrolling for increased text sizes.

Environment-limited release checks:

- A live cross-application selection check still requires the user to grant Accessibility
  permission to the packaged app.
- A live end-to-end Notion submission requires the user's own integration token and shared test
  database; automated contract tests cover the database/data-source and page payloads.
- VoiceOver focus traversal and full-screen/multi-display behavior require interactive UI
  testing.
- Developer ID signing, notarization, hardened runtime validation, and release UI automation
  require full Xcode and Apple signing credentials.

## Phase 8: Convergence

- [x] T044 Persist a confirmed capture and dismiss the panel before asynchronous Notion delivery in `Sources/ClaspCore/Services/CaptureService.swift`, `Sources/ClaspApp/App/AppModel.swift`, and `Sources/ClaspApp/Views/CaptureView.swift` per US1/AC2, SC-001, and `contracts/capture-ui.md` (partial)
- [x] T045 Restore the captured source application when canceling in `Sources/ClaspApp/Capture/CapturePanelCoordinator.swift` and `Sources/ClaspApp/Selection/AccessibilitySelectionReader.swift` per US1/AC4 (partial)
- [x] T046 Preserve an edited visible draft or require confirmation before replacing it in `Sources/ClaspApp/Capture/CapturePanelCoordinator.swift` per `contracts/capture-ui.md` Invocation (partial)

## Phase 9: First-launch visibility

- [x] T047 Present Settings on an unconfigured first launch and bring it forward when the running
  app is reopened in `Sources/ClaspApp/App/ClaspApp.swift` and
  `Sources/ClaspApp/App/SettingsWindowCoordinator.swift` per US2/AC5 and FR-025

## Phase 10: Setup form usability

- [x] T048 Make required Notion inputs visually identifiable and explain the disabled validation
  action in `Sources/ClaspApp/Views/SettingsView.swift` per FR-026

## Phase 11: Managed Notion destinations and source provenance

- [x] T049 Replace the single destination model with versioned Tasks and Bookmarks destination
  configuration and preserve existing captures during migration per FR-012 and FR-028
- [x] T050 Add Notion request builders and client orchestration to find-or-create both Clasp
  databases under a shared parent page per US2/AC1, FR-013, FR-014, and FR-027
- [x] T051 Route Task and Bookmark payloads to their respective data sources with exactly their
  requested properties per FR-013, FR-014, and FR-028
- [x] T052 Add Task priority and adapt the capture review UI to the type-specific remote fields
  per FR-009 and FR-010
- [x] T053 Discover source provenance from selection geometry, Accessibility URL/document
  metadata, browser pages, local file documents, Gmail threads, and exposed Slack permalinks per
  FR-029 and FR-030
- [x] T054 Replace database selection setup with parent-page provisioning and dual-destination
  status in Settings per US2 and FR-012
- [x] T055 Add migration, provisioning, payload-routing, and source-normalization tests
- [x] T056 Rebuild, package, and interactively verify setup and capture surfaces

## Phase 12: Guided Notion connection setup

- [x] T057 Add a direct official Notion integration-token setup link beside the token field and
  document it in the README per FR-031
- [x] T058 Add a direct official Notion page-connection guide beside the parent-page field and
  document it in the README per FR-032
- [x] T059 Update managed-database discovery to use the current Notion `data_source` search
  contract and add regression coverage
- [x] T060 Add a capture-invoked, clipboard-restoring Copy fallback for apps such as Slack that
  do not expose selected text through Accessibility
- [x] T061 Give ad-hoc packaged builds a stable local designated requirement so Accessibility
  permission survives subsequent development rebuilds
- [x] T062 Resolve Slack message permalinks by matching captured text to the visible message
  container and reading its timestamp link

## Phase 13: Main Notion library

- [x] T063 Add Notion data-source query payloads, pagination, response projection, and contract
  tests per US5, FR-034, and FR-036
- [x] T064 Add a Tasks/Bookmarks main window with loading, empty, refresh, source, and remote-link
  states per US5, FR-033, and FR-036
- [x] T065 Add type-specific manual Task and Bookmark creation using the durable capture outbox
  per US5, FR-035
- [x] T066 Open the main window for configured launches and expose it from the menu bar
- [x] T067 Package and visually verify populated Tasks and Bookmarks tabs plus both manual-entry
  sheets against the configured Notion workspace

## Phase 14: Completion workflow

- [x] T068 Add the `Done` checkbox to newly created Task and Bookmark data sources and
  automatically upgrade existing compatible Clasp data sources per US5, FR-037
- [x] T069 Filter completed pages from both Notion queries and add page-property updates for
  marking entries done per US5, FR-038, and FR-039
- [x] T070 Add native completion checkboxes to both Clasp lists with pending and failure states
  per US5, FR-038, and FR-039
- [x] T071 Add contract, client, and service regression coverage for schema upgrades, filtering,
  and remote completion

## Phase 15: Tabular library presentation

- [x] T072 Replace the free-form Task and Bookmark lists with native macOS tables whose columns
  match each data source per US5/AC8 and FR-038
- [x] T073 Put completion controls beneath a labeled Done header and preserve pending, failure,
  and accessibility behavior per US5/AC6 and FR-038

## Phase 16: Product branding

- [x] T074 Package the final connected Clasp mark as the application icon and a runtime image
  resource per FR-040
- [x] T075 Add a reusable brand component to the menu bar, main library, Settings, and capture
  review surfaces per FR-040

## Phase 17: Main-library hierarchy

- [x] T076 Move Tasks and Bookmarks out of the window toolbar into a segmented control beneath
  the branded heading and apply the final product subtitle per FR-041

## Phase 18: Inline task editing

- [x] T077 Add page-property request builders and Notion client/service operations for updating
  Task Priority and setting or clearing Due Date per US5/AC9 and FR-042
- [x] T078 Add explicit Priority and Due Date table editors with per-field pending and failure
  behavior per US5/AC9 and FR-042
- [x] T079 Add payload, client, and service regression coverage for Task property editing

## Phase 19: Visible menu-bar identity

- [x] T080 Replace the unreadable reduced full-color logo with a high-contrast template-style
  rendering of the connected Clasp mark and an explicit Clasp label in the macOS status bar per
  FR-040

## Phase 20: Ask Codex task handoff

- [x] T081 Add the managed Task `Progress` select schema, automatic compatible-database upgrade,
  projection, page-property update, and Notion contract tests per FR-043 and FR-047
- [x] T082 Add derived stable Task IDs and a local Task-to-Codex-thread association per FR-046
- [x] T083 Add a Codex app-server adapter that creates a persistent prefixed conversation,
  starts a turn, opens it in Codex, and reports active/waiting/terminal lifecycle events per
  FR-045 through FR-047 and `contracts/codex.md`
- [x] T084 Add the Task table Progress column, Ask Codex action, optional-instruction sheet,
  pending/error behavior, and regression coverage per US5/AC10 and FR-044 through FR-047
- [x] T085 Rebuild, package, and verify Notion schema migration plus the Ask Codex handoff

## Phase 21: Persistent Codex conversation links

- [x] T086 Replace Ask Codex with a persistent Open Conversation link after a Task receives a
  saved Codex thread association per FR-044
- [x] T087 Rebuild, package, and verify both unlinked and linked Task-row states

## Phase 22: Readable Codex handoff

- [x] T088 Wait for the initial persisted Codex user-message event before opening a newly
  created thread, and refresh a frontmost released thread per FR-048
- [x] T089 Rebuild, package, and verify the corrected handoff without creating another live
  validation conversation

## Phase 23: Active, configurable Codex handoff

- [x] T090 Delay opening a newly created conversation until visible agent activity begins, while
  preserving the full turn lifecycle and Notion Progress updates per FR-048
- [x] T091 Add a validated, persistent Codex workspace folder setting defaulting to
  the locally configured default workspace, and route new conversations through it per FR-049
- [x] T092 Rebuild, test, package, and verify the configurable active handoff

## Phase 24: Automatic library reconciliation

- [x] T093 Refresh the Notion library after successful selection-capture and manual-entry
  delivery, including one bounded follow-up refresh, per US5/AC11 and FR-050
- [x] T094 Rebuild, test, package, and verify automatic Task and Bookmark table refresh

## Phase 25: Ask Codex dialog refinement

- [x] T095 Redesign Ask Codex as a compact branded dialog with non-duplicated Task context,
  workspace disclosure, focused instruction entry, and a fixed action footer per US5/AC12 and
  FR-051
- [x] T096 Rebuild, package, and visually verify the refined Ask Codex dialog

## Phase 26: Completed-turn desktop handoff

- [x] T097 Keep the Codex desktop route closed while the Clasp app-server turn is active and
  display a non-clickable Working state in the Task table per FR-048
- [x] T098 Release the worker and open the persisted conversation once at waiting or terminal
  state, including a short persistence grace period and unexpected-worker cleanup
- [x] T099 Rebuild, test, package, and verify the completed-turn handoff against the persisted
  CLASP-B56D248A conversation

## Phase 27: Created Date and recoverable deletion

- [x] T100 Add Created Date as a managed `created_time` property for new Task and Bookmark data
  sources and automatically upgrade compatible existing data sources per FR-052
- [x] T101 Add Notion page Trash payload/client/service behavior using `in_trash: true`, with
  payload, client, migration, and service regression coverage per FR-053
- [x] T102 Add confirmed Task and Bookmark Delete actions with pending, failure, recovery, and
  active-Codex safeguards, without exposing Created Date in the main table
- [x] T103 Rebuild, package, migrate the configured Notion databases, and verify the new actions

## Phase 28: Cohesive modern interface

- [x] T104 Add shared branded backdrop, card, section-heading, and status-banner primitives per
  FR-054
- [x] T105 Modernize the main library with a workspace header, visible primary actions,
  count-aware navigation, sync state, refined tables, and clearer status badges
- [x] T106 Modernize capture, manual entry, Ask Codex, settings, and recent-capture surfaces
  without changing their model actions, keyboard shortcuts, or validation behavior
- [x] T107 Rebuild, test, package, and visually verify the complete refreshed interface

## Phase 29: Honest connection state and Keychain recovery

- [x] T108 Make every library open and Refresh attempt credential-backed loading instead of
  short-circuiting on a stale in-memory token flag per FR-055
- [x] T109 Distinguish Notion mapping, Keychain-required, syncing, and fully synced states in
  the main library and Settings
- [x] T110 Remove duplicate app-delegate, window-coordinator, and SwiftUI lifecycle loads,
  coalesce in-flight library refreshes, and isolate explicit Settings credential checks
- [x] T111 Rebuild, test, package, and verify denied and allowed Keychain recovery paths

## Phase 30: Per-task Codex project selection

- [x] T112 Add a deterministic Codex project catalog that validates, deduplicates, and keeps the
  configured default first per FR-056, with regression coverage
- [x] T113 Discover project folders dynamically through app-server `thread/list` pagination and
  preserve `thread/start.cwd` routing
- [x] T114 Add a per-task project picker and fallback folder chooser to Ask Codex, defaulting to
  the locally configured default project
- [x] T115 Rebuild, package, and visually verify dynamic and manually chosen project paths

## Phase 31: Standard macOS application presence

- [x] T116 Replace the accessory/UI-element lifecycle with a regular activation policy while
  preserving the menu-bar entry per FR-057
- [x] T117 Raise main and Settings windows on the active Space and retain the floating capture
  panel behavior
- [x] T118 Rebuild, package, and verify Dock, Command-Tab, reopen, and frontmost-window behavior

## Phase 32: Configurable presentation modes

- [x] T119 Add persistent Mini, Medium, and Maximum presentation modes with Medium as the
  first-run default per FR-058
- [x] T120 Apply mode-specific activation policy and compact or maximized main-window geometry
- [x] T121 Add the mode selector and remove Recent Captures from the menu-bar menu
- [x] T122 Rebuild, package, and visually verify all three presentation modes

## Phase 33: Always-on-top main window

- [x] T123 Promote the visible main window to the macOS floating level while preserving normal
  window controls and presentation-mode behavior per FR-059
- [x] T124 Rebuild, package, and verify Clasp remains visible above another active application

## Phase 34: Private local default project

- [x] T125 Move the initial Codex workspace out of tracked source into the ignored local `.env`
  with a generic tracked `.env.example` per FR-060
- [x] T126 Load the local setting during packaging, embed it in the app bundle, and preserve
  process-environment and user-selected overrides
- [x] T127 Remove the private project name from current tracked code and documentation, rebuild,
  test, and verify the packaged configuration without exposing its value
