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
- Notes, Source, Priority, and Due Date when present
- the optional user instruction when non-empty

The workspace is configurable in Settings and defaults to
`~/Data/work/truetest-pm-agenthub`; Clasp rejects an unavailable folder rather than routing the
task elsewhere. The Task ID is deterministically derived from the normalized Notion page UUID.
Clasp stores the returned thread ID locally but does not open its desktop route while the
app-server turn is active. The Task table shows a non-clickable Working indicator during this
period. When the worker reaches a waiting or terminal state, Clasp releases the worker, allows a
short persistence grace period, and opens `codex://threads/<thread-id>` exactly once. This avoids
presenting Codex desktop as a second live client for a turn it does not stream and guarantees the
opened conversation contains the currently available agent output.

## Progress lifecycle

Clasp is the writer of lifecycle state to Notion:

| Codex state | Notion Progress |
|---|---|
| No handoff | Not Started |
| Turn started or active | Working |
| Waiting on approval or user input | Waiting |
| Turn completed successfully | Completed |
| Startup, protocol, or turn failure | Failed |

Every remote update is confirmed before the main-table projection changes. The Notion
integration token is never passed to Codex or written to the Codex conversation.

## Local association

The mapping from Notion page ID to Codex thread ID is stored in application preferences. It is
used to replace Ask Codex with an Open Conversation link in the Task table, survives Clasp
restarts, and is not treated as a remote source of truth.
