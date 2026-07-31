# Capture UI Contract

## Invocation

1. A registered global shortcut or the menu-bar Capture command requests capture.
2. Clasp snapshots the frontmost application before activating itself.
3. Clasp attempts to read selected text with a bounded Accessibility call.
4. Clasp activates and presents one key-capable capture panel.

Repeated invocation while the panel is visible brings the existing panel forward; it does not
replace an edited draft without confirmation.

## Capture panel state

The panel exposes:

- Task/Bookmark choice.
- Required editable Title.
- Required editable Notes for Task; Bookmarks use Name and Source only.
- Read-only source application identity.
- Optional editable source URL or absolute file path.
- Optional Task due date.
- Task Priority picker with Low, Medium, and High.
- Explicit Paste button when no selection was available.
- Cancel and Save actions.

The initial title is the first non-empty line of selected text, truncated for display. Initial
keyboard focus is Title. Tab order follows the visual order. Escape cancels; Command-Return
saves when valid.

## Permission and unavailable-selection outcomes

| Outcome | User-facing behavior |
|---|---|
| Permission not determined/denied | Explain why access is needed; offer Open System Settings and Try Again |
| No textual selection | Open an empty draft; explain that no selection was available |
| Attribute unsupported | Open an empty draft; identify that the source app did not expose selection |
| Source unresponsive | Open an empty draft; offer Try Again |
| Success | Prefill content and source context |

Clasp uses Accessibility first. When an invoked Capture cannot read selected text, it may issue
Copy to the source process, read only that result, and immediately restore the previous clipboard.
Outside this capture-time fallback, Clasp never reads or inserts clipboard text without the user
activating Paste.

For Slack, Clasp matches the copied selection to a visible Accessibility text node and uses the
timestamp permalink exposed within that message container. It does not substitute the channel URL
when a message-level link cannot be identified.

## Save behavior

Save remains disabled until Title is non-empty and, for Tasks, Notes is also non-empty. On Save:

1. Normalize inputs.
2. Persist a pending Capture.
3. Dismiss the panel and restore normal accessory behavior.
4. Attempt delivery without blocking panel dismissal.
5. Surface success or pending/failed state through the menu and recent-captures window.

Cancel discards only the in-memory draft and returns focus to the prior application when
possible.

## Recent captures

Each row shows title, type, source app, creation time, and delivery state. Pending and failed
rows expose Retry. Delivered rows expose Open in Notion when a remote page URL is known.
Deletion requires confirmation and never deletes the Notion page in the MVP.

## Accessibility

- All icon-only controls have accessibility labels.
- Status is conveyed by text as well as color.
- Standard controls preserve VoiceOver roles and increased text sizes.
- Task/Bookmark choice and delivery state announce their selected/current values.
- Every primary action is reachable without a pointing device.
