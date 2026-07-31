# Feature Specification: Capture Selected Text to Notion

**Feature Branch**: `main`

**Created**: 2026-07-30

**Status**: Draft

**Input**: User description: "Create a macOS desktop app that lets a user select text in any
app, turn it into a task or bookmark, and track it in a Notion database."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Capture Selected Text (Priority: P1)

A Mac user selects useful text in another application, invokes Clasp with a global shortcut,
chooses Task or Bookmark, reviews the captured content, and saves it to a configured Notion
database without leaving the source application.

**Why this priority**: This is Clasp's central value: converting transient selected text into a
trackable item with minimal interruption.

**Independent Test**: Provision Clasp's two destinations, select text in a supported
application, invoke Clasp, submit the item, and confirm Tasks and Bookmarks are routed to their
respective databases.

**Acceptance Scenarios**:

1. **Given** Clasp is configured and text is selected in another application, **When** the user
   invokes Clasp, **Then** a compact capture window appears with the selected text and source
   application prefilled.
2. **Given** the capture window contains selected text, **When** the user chooses Task, edits the
   title, and confirms, **Then** a task containing the title, selected text, source, and capture
   time is saved to the Clasp Tasks database.
3. **Given** the capture window contains selected text, **When** the user chooses Bookmark,
   optionally adds a source address, and confirms, **Then** a bookmark containing the title,
   selected text and source information is saved to the Clasp Bookmarks database.
4. **Given** the capture window is open, **When** the user cancels, **Then** no local or remote
   item is created and focus returns to the previous application.

---

### User Story 2 - Configure and Validate Notion (Priority: P2)

A user securely connects Clasp to Notion, chooses a parent page, and asks Clasp to create and
validate one Tasks database and one Bookmarks database before attempting a capture.

**Why this priority**: Capture cannot complete reliably until the destination and its required
fields have been validated.

**Independent Test**: Enter valid connection details and a shared parent page, run setup, and
confirm that both managed databases are created or reused without creating a capture item.

**Acceptance Scenarios**:

1. **Given** the user has valid integration credentials and a parent page shared with that
   integration, **When** they choose Create Clasp Databases, **Then** Clasp creates `Clasp Tasks`
   and `Clasp Bookmarks` under that page and confirms both destinations are ready.
2. **Given** credentials are invalid or the parent page is inaccessible, **When** setup runs,
   **Then** Clasp explains the problem and does not mark setup complete.
3. **Given** one previously created Clasp database is found under the parent page, **When** setup
   is retried, **Then** Clasp reuses and validates it instead of creating a duplicate.
4. **Given** saved credentials exist, **When** the user reopens settings, **Then** the secret is
   not displayed in readable form and can be replaced or removed.
5. **Given** Clasp has not been configured, **When** the user launches the app, **Then** a visible
   setup window appears without requiring the user to discover the menu-bar icon.

---

### User Story 3 - Recover Failed Captures (Priority: P3)

A user who loses connectivity or encounters a temporary Notion failure can see that the
confirmed capture is pending and retry it later without reselecting the original text.

**Why this priority**: A capture utility loses trust if confirmed information can disappear.

**Independent Test**: Simulate an unavailable destination, submit a capture, restore access,
retry the item, and confirm it is delivered while the original capture remains safely retained.

**Acceptance Scenarios**:

1. **Given** the destination is temporarily unavailable, **When** the user confirms a capture,
   **Then** Clasp retains the complete item locally and clearly reports it as pending.
2. **Given** a pending item exists and access is restored, **When** the user retries it, **Then**
   Clasp creates one remote item and marks the local item delivered.
3. **Given** multiple pending items exist, **When** the user opens recent captures, **Then** they
   can distinguish pending, delivered, and failed items and retry each failed item.

---

### User Story 4 - Capture When Selection Access Is Unavailable (Priority: P4)

A user can still create an item when the current application does not expose its selection,
without Clasp silently capturing unrelated clipboard contents.

**Why this priority**: Some applications restrict selection access, but a transparent fallback
keeps the app useful without weakening privacy.

**Independent Test**: Invoke Clasp from an application whose selection is unavailable and
verify that the user can explicitly paste or type content before saving.

**Acceptance Scenarios**:

1. **Given** Clasp cannot read the current selection, **When** it is invoked, **Then** it explains
   that no selection was available and opens an empty editable capture window.
2. **Given** no selection was available, **When** the user explicitly chooses Paste, **Then**
   Clasp inserts the current clipboard text and allows the user to review it before saving.

---

### User Story 5 - Browse and Create Clasp Items (Priority: P2)

A configured user opens Clasp's main window, switches between Tasks and Bookmarks, sees the
current entries loaded from the corresponding Notion data source, and can create either kind
without first selecting text in another app.

**Why this priority**: Capturing is the fastest input path, but a useful desktop application also
needs a dependable home for reviewing the remote source of truth and adding items manually.

**Independent Test**: Configure both managed destinations, seed each with remote entries, open
the main window, verify each tab shows only its matching entries, then create one Task and one
Bookmark manually and confirm both appear in the correct Notion database after refresh.

**Acceptance Scenarios**:

1. **Given** Clasp is configured, **When** the main window opens, **Then** it presents Tasks and
   Bookmarks tabs and loads entries from their respective Notion data sources.
2. **Given** a tab is visible, **When** the user refreshes, **Then** Clasp replaces that tab's
   contents with the latest remote entries and clearly reports any failure.
3. **Given** the Tasks tab is selected, **When** the user creates an entry manually, **Then** they
   can set Name, Source, Due Date, Priority, and Notes and the entry is persisted locally before
   being delivered to Clasp Tasks.
4. **Given** the Bookmarks tab is selected, **When** the user creates an entry manually, **Then**
   they can set Name and Source and the entry is persisted locally before being delivered to
   Clasp Bookmarks.
5. **Given** a remote entry has a Notion URL, **When** the user activates it, **Then** Clasp opens
   that entry in Notion.
6. **Given** an unchecked Task or Bookmark is visible, **When** the user checks Done, **Then**
   Clasp updates that page in Notion and removes it from the visible list after confirmation.
7. **Given** a Task or Bookmark is already Done in Notion, **When** Clasp loads or refreshes,
   **Then** that entry is excluded from the visible list.
8. **Given** either library tab contains entries, **When** the user reviews it, **Then** entries
   are presented in a table with labeled columns and an unmistakably interactive Done checkbox.
9. **Given** a Task is visible, **When** the user changes its Priority or sets, changes, or clears
   its Due Date, **Then** Clasp updates the corresponding Notion page and reflects the value only
   after Notion accepts the update.
10. **Given** a Task is visible, **When** the user chooses Ask Codex, optionally adds an
    instruction, and confirms, **Then** Clasp creates and opens a persistent Codex conversation
    whose title starts with that Task's stable Clasp Task ID, starts the work, and reflects its
    lifecycle through the Task's Progress property in Notion and the main table.
11. **Given** the main library is open, **When** a Task or Bookmark created through either
    Clasp entry flow is confirmed by Notion, **Then** the corresponding table refreshes
    automatically without requiring the user to press Refresh.
12. **Given** a Task has not been handed to Codex, **When** the user opens Ask Codex, **Then**
    Clasp presents a compact branded dialog with a clear task summary, non-duplicated context,
    optional instruction editor, configured workspace, and a consistently visible action footer.
13. **Given** either managed database is created or revalidated, **When** Clasp inspects its
    schema, **Then** a read-only Created Date column exists in Notion and is populated by Notion,
    while Clasp does not add it to the main table.
14. **Given** a visible Task or Bookmark is not being worked on by Codex, **When** the user
    confirms Delete, **Then** Clasp moves the Notion page to Trash and removes the row only after
    Notion accepts the request.

### Edge Cases

- The selected content is empty, whitespace-only, extremely long, or contains multiple scripts
  and emoji.
- The selected content changes between invocation and capture.
- The source application closes while the capture window is open.
- The global shortcut conflicts with another application or macOS feature.
- Accessibility permission is denied, revoked, or restricted by device management.
- The configured destination is deleted, unshared, renamed, or has its field kinds changed.
- A request times out after the destination accepted it, creating uncertainty about delivery.
- The device is offline for an extended period and accumulates many pending items.
- The source address is unavailable or is not a valid web address.
- Credentials are removed while captures remain pending.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Clasp MUST run as an unobtrusive macOS utility that remains available from the
  menu bar.
- **FR-002**: Users MUST be able to assign and invoke a global keyboard shortcut.
- **FR-003**: Clasp MUST request selection-access permission only when required and MUST explain
  why it is needed before directing the user to grant it.
- **FR-004**: Clasp MUST attempt to capture the currently selected textual content and identify
  the source application.
- **FR-005**: Clasp MUST use Accessibility first. Only after the user explicitly invokes Capture,
  Clasp MAY issue Copy when the source app does not expose selected text, MUST accept the result
  only when that Copy changes the pasteboard, and MUST immediately restore prior clipboard
  contents. Manual clipboard insertion MUST still require the explicit Paste action.
- **FR-006**: Users MUST be able to review and edit captured content before it is transmitted.
- **FR-007**: Users MUST be able to classify each capture as either Task or Bookmark.
- **FR-008**: Each capture MUST include a user-editable title, body text, item type, source
  application, source location when available, capture time, and delivery state.
- **FR-009**: Task captures MUST support an optional due date.
- **FR-010**: Task captures MUST support an optional Priority of Low, Medium, or High and Notes
  populated from the selected text.
- **FR-011**: Users MUST be able to securely save, replace, test, and remove their Notion
  connection credentials.
- **FR-012**: Clasp MUST create separate `Clasp Tasks` and `Clasp Bookmarks` databases under a
  user-supplied Notion parent page.
- **FR-013**: The Tasks database MUST contain `Name` (title), `Source` (rich text), `Due Date`
  (date), `Priority` (select), and `Notes` (rich text).
- **FR-014**: The Bookmarks database MUST contain `Name` (title) and `Source` (rich text).
- **FR-015**: Confirmed captures MUST be stored locally before remote delivery is attempted.
- **FR-016**: Clasp MUST preserve confirmed captures across app restarts until the user deletes
  them.
- **FR-017**: Clasp MUST distinguish pending, delivered, and failed delivery states.
- **FR-018**: Users MUST be able to inspect recent captures and manually retry pending or failed
  captures.
- **FR-019**: A retry MUST avoid creating a duplicate when Clasp can determine that an earlier
  attempt succeeded.
- **FR-020**: Clasp MUST provide actionable messages for permission, authentication, destination
  schema, connectivity, and service-limit failures without exposing credentials.
- **FR-021**: Users MUST be able to cancel a capture without creating local or remote data.
- **FR-022**: The complete primary capture flow MUST be operable by keyboard and expose
  meaningful labels to assistive technologies.
- **FR-023**: Clasp MUST support light mode, dark mode, and increased text sizes without hiding
  required controls.
- **FR-024**: Clasp MUST NOT send analytics or captured content to any destination other than
  the user-configured Notion workspace, except when the user explicitly invokes Ask Codex for
  a specific Task.
- **FR-025**: Launching an unconfigured Clasp installation MUST present a visible setup window,
  and reopening a running app MUST bring that window forward.
- **FR-026**: Setup MUST present token and parent-page values as visually identifiable editable
  controls and explain why validation is unavailable when required values are empty.
- **FR-027**: Clasp MUST reuse compatible `Clasp Tasks` or `Clasp Bookmarks` databases already
  created under the configured parent page when retrying partial setup.
- **FR-028**: A Task capture MUST route only to the Tasks database and a Bookmark capture MUST
  route only to the Bookmarks database.
- **FR-029**: Source discovery MUST prefer a Gmail email URL, local file path, webpage URL, or
  Slack message permalink according to the source application and exposed macOS metadata.
- **FR-030**: When an exact source cannot be discovered, Clasp MUST keep Source editable and
  MUST NOT fabricate a URL or file path.
- **FR-031**: Setup MUST provide a direct link from the integration-token field to Notion's
  official instructions for creating and retrieving an internal integration token.
- **FR-032**: Setup MUST provide a direct link from the parent-page field to Notion's official
  instructions for granting an internal integration access to a page.
- **FR-033**: A configured Clasp installation MUST provide a main window with separate Tasks and
  Bookmarks tabs.
- **FR-034**: Each tab MUST load and refresh entries from its matching configured Notion data
  source using the current Notion query API.
- **FR-035**: Users MUST be able to create Tasks and Bookmarks manually from the main window with
  the same type-specific fields and durable local-before-remote delivery guarantees as captures.
- **FR-036**: Remote list rows MUST expose their Notion page link when available and MUST show
  loading, empty, and actionable failure states.
- **FR-037**: Both managed data sources MUST contain a `Done` checkbox property; Clasp MUST add
  it automatically to compatible existing managed data sources.
- **FR-038**: The main window MUST present each tab as a table with a labeled `Done` column and
  an unchecked, interactive checkbox for every visible entry, update the corresponding Notion
  page when activated, and remove it from the visible table only after the remote update
  succeeds.
- **FR-039**: Notion list queries MUST exclude pages whose Done checkbox is checked.
- **FR-040**: The final Clasp logo MUST be packaged as the macOS application icon and appear
  consistently in the main library, Settings, and capture-review surfaces; the menu bar MUST
  use a recognizable high-contrast monochrome rendering of the same connected Clasp mark plus
  the visible text label `Clasp`.
- **FR-041**: The main library MUST place the Clasp heading and subtitle “Your central task and
  bookmark management” above an in-content Tasks/Bookmarks segmented control.
- **FR-042**: Task Priority and Due Date cells MUST provide explicit editing controls, persist
  changes to their mapped Notion properties, disable duplicate updates while a request is in
  flight, and retain the previous visible value when Notion rejects an update.
- **FR-043**: The managed Tasks data source MUST contain a `Progress` select property with
  `Not Started`, `Working`, `Waiting`, `Completed`, and `Failed` options; Clasp MUST add it
  automatically to compatible existing Tasks data sources.
- **FR-044**: Every Task row MUST display its current Progress value from Notion. A Task without
  a saved Codex thread MUST provide an explicit Ask Codex button; after conversation creation
  succeeds, Clasp MUST replace that button with a persistent link to the created conversation.
- **FR-045**: Ask Codex MUST present the Task context and an optional user instruction before
  creating or starting any Codex conversation.
- **FR-046**: Clasp MUST derive a stable, human-readable Task ID from the Notion page ID and set
  the created Codex conversation title to `[<Task ID>] <Task Name>`.
- **FR-047**: Clasp MUST start the Codex turn only after explicit confirmation, update Progress
  to `Working` while the turn is active, `Waiting` when Codex requires user interaction,
  `Completed` when the turn succeeds, and `Failed` when startup or execution fails. Clasp MUST
  update the visible row only after Notion accepts each Progress change.
- **FR-048**: Clasp MUST keep a newly created Codex conversation owned by its app-server worker
  while the turn is active and MUST NOT open its desktop route during that period. The Task row
  MUST show an explicit non-clickable Working state. After the turn completes, fails, or requires
  user interaction, Clasp MUST release the worker and open the persisted conversation exactly
  once so Codex displays the available agent output rather than a stale prompt-only shell.
- **FR-049**: Ask Codex MUST create each conversation in a user-configurable local workspace
  folder. The initial default MUST come from the local ignored `.env`, and an unavailable
  configured folder MUST produce an actionable error without silently using another workspace.
- **FR-050**: After Notion confirms a Task or Bookmark created through manual entry or selection
  capture, Clasp MUST refresh the main library immediately and perform one bounded follow-up
  refresh to reconcile any short Notion indexing delay.
- **FR-051**: The Ask Codex dialog MUST use Clasp branding, visually separate Task context from
  the optional instruction, suppress Notes when they merely repeat the Task Name, show the
  configured workspace, and keep Cancel and Start actions visible without clipping.
- **FR-052**: Both managed data sources MUST contain a `Created Date` property of Notion type
  `created_time`. Clasp MUST add it automatically to compatible existing data sources, MUST rely
  on Notion to populate it, and MUST NOT show it in the main Clasp table.
- **FR-053**: Every visible Task and Bookmark row MUST provide a confirmed Delete action that
  sends the page to Notion Trash with `in_trash: true`. Clasp MUST remove the row only after a
  successful response, explain that the page is recoverable from Trash, and disable deletion
  while its Codex Progress is `Working`.
- **FR-054**: Clasp MUST present its main library, capture panel, manual-entry sheet, Ask Codex
  sheet, settings, and recent-captures window with one cohesive modern visual system. The system
  MUST retain native macOS conventions and accessibility while providing clear hierarchy,
  prominent primary actions, legible state badges, consistent branded surfaces, and unambiguous
  interactive controls. This visual refresh MUST preserve all existing behavior and keyboard
  shortcuts.
- **FR-055**: The main library MUST attempt a real credential-backed Notion load whenever it
  opens or the user invokes Refresh, even when an earlier Keychain check failed. A missing,
  denied, or inaccessible Keychain credential MUST produce an actionable visible status and
  MUST NOT be represented as a successful Notion sync. Settings MUST distinguish a saved
  database mapping from a fully usable credential-backed connection. One user-visible action
  MUST NOT issue overlapping or redundant reads of the same Keychain credential.
- **FR-056**: Ask Codex MUST let the user choose the local Codex project folder for each Task.
  Clasp MUST dynamically discover valid project folders from persisted Codex thread metadata,
  keep the locally configured default workspace first and selected
  by default, deduplicate and ignore unavailable folders, and provide a folder chooser for valid
  projects that have no existing Codex conversation. Project choices MUST NOT be hard-coded.
- **FR-057**: Clasp MUST run as a regular macOS application while retaining its menu-bar item.
  Its icon MUST appear in the Dock and the application MUST be reachable through the standard
  Command-Tab app switcher. Opening the main window or Settings MUST activate Clasp, move the
  window to the active Space, and raise it above other application windows. The Capture panel
  MUST remain a floating all-Spaces utility while capture is active.
- **FR-058**: Clasp MUST provide persistent Mini, Medium, and Maximum presentation modes from
  its menu-bar menu. Medium MUST be the default and use a compact task-and-bookmark window;
  Maximum MUST expand that window to the usable screen; and Mini MUST hide the main window,
  Dock icon, and Command-Tab presence while retaining capture, Settings, and explicit Open Clasp
  access from the menu bar. Selecting Medium or Maximum MUST restore regular-app presence and
  immediately show the corresponding window. The menu-bar menu MUST NOT include a Recent
  Captures item. This mode-specific behavior supersedes FR-057's always-regular requirement.
- **FR-059**: Whenever the main Clasp window is explicitly visible in Medium or Maximum mode,
  it MUST remain above ordinary application windows, including when another application becomes
  active. The window MUST retain normal close, minimize, move, resize, and mode behavior.
- **FR-060**: The initial Ask Codex workspace MUST NOT be hard-coded in tracked source. Local
  builds MUST accept it from the ignored `.env` variable `CLASP_DEFAULT_CODEX_WORKSPACE_PATH`,
  package it for Finder-launched app bundles, and fall back to dynamic discovery or user folder
  selection when it is absent. The repository MUST include only a generic `.env.example`.
- **FR-061**: The main library MUST show a Pomodoro timer above the Tasks and Bookmarks tabs with
  selectable 25-minute Focus and 5-minute Break modes, visible remaining time, start,
  pause/resume, reset, progress, and completion feedback. Switching modes MUST pause and reset
  the timer to the selected duration.
- **FR-062**: The Tasks table MUST order incomplete tasks first by Priority in High, Medium, Low,
  and unset order, then by Due Date ascending within each priority. Tasks without a Due Date MUST
  follow dated tasks of the same priority, and exact ties MUST retain their source order.
- **FR-063**: The Pomodoro Focus/Break selector MUST use a subtle neutral selection treatment,
  and its Start/Pause action MUST retain the same Clasp accent color in both timer modes.
- **FR-064**: Starting a Break MUST reveal an original cute anime cat demonstrating calm deep
  breathing, accompanied by alternating inhale and exhale guidance synchronized to a gentle
  animation. Pausing MUST retain the companion with a paused cue, Reset or Focus MUST hide it,
  and completion MUST retain it with positive feedback.
- **FR-065**: The guided Break companion MUST be named Mochi and visually reflect the user's
  white-and-brown/black tabby cat reference without storing the reference photo in the repository.
  While a Break runs, Clasp MUST speak the inhale and exhale cues, offer an accessible mute control,
  stop speaking when paused, reset, hidden, or dismissed, and announce completion when audio is on.
- **FR-066**: Mochi's spoken guidance MUST use a quiet, slow, relaxing voice with deliberate pauses
  in “Breathe … in” and “Breathe … out.” An unobtrusive ambient music bed MUST play during an active
  Break, share the audio toggle, and stop on pause, reset, Focus, completion, mute, or dismissal.
- **FR-067**: Spoken breathing guidance MUST prefer a locally installed Premium or Enhanced English
  voice, use a natural unshifted pitch at low volume, and separate “Breathe” from “in” or “out” with
  a deliberate pause. The ambient bed MUST remain clearly audible beneath the spoken cue.
- **FR-068**: Break music MUST be an original, spacious meditation soundscape centered on 528 Hz,
  with warm lower harmonics, slow breath-like modulation, sparse chimes, and gentle reverb. It MAY
  be mood-informed by a user-provided reference but MUST NOT copy or distribute that recording.
- **FR-069**: Mini, Medium, and Maximum MUST appear as direct, individually labeled commands in the
  Clasp menu-bar menu rather than being hidden inside a submenu.

### Key Entities

- **Capture**: A task or bookmark created from selected or entered text. It has an identifier,
  title, body, type, source application, optional source address, optional due date, tags,
  creation time, delivery state, attempt history, and optional remote identifier.
- **Destination Configuration**: The user's selected Notion database, its validated field
  mapping, validation status, and last validation time. It references credentials without
  containing the readable secret.
- **Delivery Attempt**: One attempt to send a capture, including its time, outcome, retryability,
  and a safe error summary.
- **Source Context**: Information available from the application where capture began, including
  application name and optional address.
- **Notion List Item**: A projection of a remote Task or Bookmark page containing its stable
  page ID, URL, type-specific properties, and Notion timestamps.
- **Codex Task Session**: A local association between a Notion Task page and its persistent
  Codex thread, including the derived Task ID and latest observed lifecycle state. It contains
  no Notion credential.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A configured user can turn selected text into a confirmed task or bookmark in
  under 10 seconds for at least 90% of routine captures.
- **SC-002**: The capture window becomes ready for input within 500 milliseconds for at least
  95% of invocations on a supported Mac under normal load.
- **SC-003**: In usability testing, at least 9 of 10 first-time users complete a basic capture
  without assistance after setup.
- **SC-004**: Every confirmed capture remains visible as delivered, pending, or failed after an
  app restart; no confirmed capture is silently lost.
- **SC-005**: After a simulated temporary outage, users can retry and deliver at least 99% of
  retained captures without re-entering their content.
- **SC-006**: All primary capture and retry actions can be completed without a pointing device.
- **SC-007**: Setup validation identifies invalid credentials, inaccessible destinations, and
  incompatible required fields before the first real capture is submitted.
- **SC-008**: No readable connection secret or captured body text appears in diagnostic output
  during automated privacy checks.

## Assumptions

- The initial release supports a single local Mac user and one Notion parent page containing
  two Clasp-managed databases.
- The user creates a Notion integration and explicitly shares the parent page with it.
- The Notion integration enables Read content, Insert content, and Update content capabilities.
- Gmail and browser page URLs are normally available through Accessibility document metadata.
- Exact Slack message permalinks are best-effort because some Slack versions expose only a
  channel URL; the user can review or replace Source before saving.
- Ask Codex requires the installed Codex desktop application and its bundled app-server
  executable, using the user's existing Codex sign-in.
- Capturing an address from arbitrary applications is not guaranteed; the user can add or edit it.
- Clasp does not modify or complete existing Notion items in the initial release.
- Automatic background retries, multiple workspaces, team sharing, browser extensions, mobile
  clients, and content summarization are outside the initial MVP.
- The initial release is distributed outside the Mac App Store as a signed and notarized app.
- The app targets currently supported Apple Silicon Macs; Intel support may be added later.
