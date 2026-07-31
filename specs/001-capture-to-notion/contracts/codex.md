# Codex Task Handoff Contract

## Availability

Clasp discovers the executable bundled with the installed Codex desktop application. If it is
not available, Ask Codex remains visible but reports an actionable installation/sign-in error
without changing the Task's visible Progress.

## Conversation creation

After the user confirms the Ask Codex sheet, Clasp starts a local Codex app-server session,
initializes the JSON-RPC connection, creates a persistent thread rooted at the Clasp workspace,
sets its exact name to `[CLASP-XXXXXXXX] <Task Name>`, and starts one turn containing:

- Task ID and Name
- the canonical Notion Task page link when available
- Notes, Source, Priority, and Due Date when present
- the optional user instruction when non-empty

The default workspace is configurable in Settings and initially resolves to
the path supplied through `CLASP_DEFAULT_CODEX_WORKSPACE_PATH`. Ask Codex queries the documented
app-server `thread/list` method, extracts unique existing `cwd` values, and presents valid folders
as project choices with the configured default first. The user can choose any other folder when a
project has no existing thread. Clasp passes the selected path as `thread/start.cwd` and rejects an
unavailable folder rather than routing the task elsewhere. The Task ID is deterministically
derived from the normalized Notion page UUID.
Clasp stores the returned thread ID locally and immediately replaces Ask Codex with an
`Open Conversation` link, including while Progress is Working. Clasp does not automatically open
the desktop route while the app-server turn is active. When the worker reaches a waiting or
terminal state, Clasp releases the worker, allows a short persistence grace period, and opens
`codex://threads/<thread-id>` exactly once. This guarantees the user has immediate access to the
conversation while preserving the automatic handoff once agent output is available.

## Progress lifecycle

Clasp is the writer of lifecycle state to Notion:

| Codex state | Notion Progress |
|---|---|
| No handoff | Not Started |
| Turn started or active | Working |
| Waiting on approval or user input | Waiting |
| Turn ended without an explicit task-complete declaration | Waiting |
| Final response explicitly declares all requested work complete | Completed |
| Startup, protocol, or turn failure | Failed |

Codex app-server's `turn/completed` event means only that a response turn ended; it is not proof
that the requested Task is finished. The handoff therefore requires the final agent response to
declare `COMPLETED`, `WAITING`, or `FAILED` with Clasp's hidden status marker. A successful turn
without a valid marker becomes Waiting. The conversation is also instructed never to change the
Task's independent `Done` checkbox unless the user explicitly asks for that action.

Every remote Progress update is confirmed before the main-table projection changes. The Notion
integration token is never passed to Codex or written to the Codex conversation.

## Local association

The mapping from Notion page ID to Codex thread ID is stored in application preferences. It is
used to replace Ask Codex with an Open Conversation link in the Task table, survives Clasp
restarts, and is not treated as a remote source of truth.
