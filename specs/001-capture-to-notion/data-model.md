# Data Model: Capture Selected Text to Notion

## Capture

Represents one user-confirmed Task or Bookmark and is also the durable outbox record.

| Field | Type | Rules |
|---|---|---|
| `id` | UUID | Generated once before initial persistence |
| `title` | String | Trimmed, non-empty, maximum 2,000 characters |
| `body` | String | Task Notes; locally retained for both types |
| `type` | `task` or `bookmark` | Selects the remote destination and payload |
| `source` | SourceContext | Snapshot captured before Clasp activates |
| `dueDate` | Date? | Allowed for Task; omitted for Bookmark |
| `priority` | `low`, `medium`, `high`? | Allowed for Task; omitted for Bookmark |
| `createdAt` / `updatedAt` | Date | Durable lifecycle timestamps |
| `delivery` | DeliveryState | `pending`, `delivering`, `delivered`, or `failed` |
| `remotePageID` / `remotePageURL` | String? / URL? | Set after successful delivery |
| `attempts` | [DeliveryAttempt] | Capped safe metadata; no token or capture body |

A confirmed item is persisted as `pending` before network delivery. Startup changes an
interrupted `delivering` item back to `pending`.

## SourceContext

| Field | Type | Rules |
|---|---|---|
| `applicationName` | String | Human-readable source name |
| `bundleIdentifier` | String? | Frontmost application snapshot |
| `processIdentifier` | Int32? | Used only to restore focus |
| `sourceURL` | URL? | HTTPS permalink/page URL or local file URL |

For file URLs, the UI and Notion Source field display the POSIX path. For HTTPS URLs, Source is
linked rich text. Discovery walks the selected Accessibility element, its ancestors, the
element at the selected range's screen position, and the focused window. Slack permalinks are
preferred over channel URLs when exposed. No missing source is fabricated.

## DestinationSet

| Field | Type | Rules |
|---|---|---|
| `parentPageID` | String | Normalized shared Notion page UUID |
| `tasks` | DestinationConfiguration | `Clasp Tasks` database/data source |
| `bookmarks` | DestinationConfiguration | `Clasp Bookmarks` database/data source |
| `provisionedAt` | Date | Last successful complete setup |
| `apiVersion` | String | `2026-03-11` |

Each DestinationConfiguration stores database ID, data source ID/name, validated stable
property IDs, and validation time. It never contains the bearer token.

### Tasks property map

| Field | Notion kind |
|---|---|
| `Name` | `title` |
| `Source` | `rich_text` |
| `Due Date` | `date` |
| `Priority` | `select` with Low, Medium, High |
| `Notes` | `rich_text` |
| `Created Date` | `created_time` |
| `Done` | `checkbox` |
| `Progress` | `select` with Not Started, Working, Waiting, Completed, Failed |

### Bookmarks property map

| Field | Notion kind |
|---|---|
| `Name` | `title` |
| `Source` | `rich_text` |
| `Created Date` | `created_time` |
| `Done` | `checkbox` |

## StoreDocument

Schema version 2 stores captures and an optional DestinationSet. Version 1 data migrates by
preserving captures and clearing its incompatible single-database configuration so the user can
provision the two managed databases. The original file and last-known-good backup remain
recoverable if decoding or migration fails.

## NotionListItem

Represents a remote page returned by querying one managed Notion data source. It is transient
UI state and is not written to the local outbox.

| Field | Type | Rules |
|---|---|---|
| `id` | String | Notion page UUID |
| `url` | URL? | Opens the remote page |
| `type` | `task` or `bookmark` | Determined by the queried destination |
| `title` | String | Plain text from the configured Name property |
| `source` | String | Plain text from Source |
| `notes` | String | Tasks only; empty for Bookmarks |
| `dueDate` | Date? | Tasks only |
| `priority` | TaskPriority? | Tasks only |
| `progress` | TaskProgress? | Tasks only; defaults to Not Started when unset |
| `taskID` | String | Derived from the stable Notion page UUID; formatted `CLASP-XXXXXXXX` |
| `done` | Bool | Always false for items returned to the main window |
| `createdAt` / `updatedAt` | Date? | Notion page timestamps |

Queries use stable property IDs from DestinationConfiguration, follow Notion pagination, and
order by creation time descending. Local captures remain the durable delivery outbox; this model
is only a projection of Notion's remote source of truth.

## CodexTaskSession

Clasp stores the local Task-page-ID to Codex-thread-ID association in application preferences.
The Notion token and conversation content are not duplicated into this mapping. Conversation
titles use `[CLASP-XXXXXXXX] <Task Name>`, where the hexadecimal suffix is derived from the
normalized Notion page UUID.
