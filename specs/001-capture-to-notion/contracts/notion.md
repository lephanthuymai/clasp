# Notion REST Contract

## Protocol

- Base URL: `https://api.notion.com/v1`
- Version header: `Notion-Version: 2026-03-11`
- Authentication: `Authorization: Bearer <Keychain token>`
- Required capabilities: Read content, Insert content, and Update content
- The user shares one parent page with the integration.

## Find or create managed databases

Setup searches for exact `Clasp Tasks` and `Clasp Bookmarks` database titles whose parent is the
configured page. With API version `2026-03-11`, search filters for `data_source` objects and
uses each result's immediate database parent plus `database_parent` page. Compatible matches
are reused to make partial setup retryable.

Missing databases are created with `POST /databases` and:

```json
{
  "parent": { "type": "page_id", "page_id": "<parent page ID>" },
  "title": [{ "type": "text", "text": { "content": "Clasp Tasks" } }],
  "is_inline": false,
  "initial_data_source": {
    "properties": {
      "Name": { "title": {} },
      "Source": { "rich_text": {} },
      "Due Date": { "date": {} },
      "Priority": {
        "select": {
          "options": [
            { "name": "Low", "color": "gray" },
            { "name": "Medium", "color": "yellow" },
            { "name": "High", "color": "red" }
          ]
        }
      },
      "Notes": { "rich_text": {} },
      "Created Date": { "created_time": {} },
      "Done": { "checkbox": {} },
      "Progress": {
        "select": {
          "options": [
            { "name": "Not Started", "color": "gray" },
            { "name": "Working", "color": "blue" },
            { "name": "Waiting", "color": "yellow" },
            { "name": "Completed", "color": "green" },
            { "name": "Failed", "color": "red" }
          ]
        }
      }
    }
  }
}
```

The Bookmarks request uses title `Clasp Bookmarks` and `Name`, `Source`, `Created Date`, plus the
`Done` checkbox. Clasp retrieves
the created/reused database and its first data source, validates exact property kinds, and
persists returned stable property IDs only after both destinations succeed.

## Create capture pages

`POST /pages` uses the Tasks data source for Task captures and the Bookmarks data source for
Bookmark captures.

Task properties: Name title, Source linked/plain rich text, optional Due Date, optional Priority,
and Notes rich text. Bookmark properties: Name title and Source linked/plain rich text.

For HTTPS sources, the displayed source and rich-text link target are the URL. For `file://`
sources, the displayed value is the POSIX path without a remote link.

Rich text is split into at most 100 chunks of 2,000 characters. A successful response persists
the page ID and URL. Authentication, access, rate-limit, retryable server, and transport errors
remain classified without logging request content or credentials.

## Query managed entries

The main window queries each saved data source with:

`POST /v1/data_sources/{data_source_id}/query`

Requests filter `Done` equal to false, sort by `created_time` descending, request up to 100
pages at a time, and follow
`has_more`/`next_cursor`. Responses are projected through the destination's stable property IDs
into NotionListItem values. Tasks read Name, Source, Due Date, Priority, and Notes; Bookmarks read
only Name and Source.

Before querying, Clasp retrieves each data source. If `Created Date` is missing, it adds the
read-only `created_time` property with `PATCH /v1/data_sources/{data_source_id}`. It never sends
a Created Date page value and does not project this property into a visible Clasp column. An
existing property named Created Date with another type is an actionable schema error.

If `Done` is missing, Clasp adds the checkbox
with `PATCH /v1/data_sources/{data_source_id}`. If a property named Done exists with another
type, setup fails with an actionable schema error.

For the Tasks data source, Clasp similarly adds a missing `Progress` select with the five
managed options. An existing incompatible Progress property or missing managed option is an
actionable schema error.

Checking a visible row sends `PATCH /v1/pages/{page_id}` with
`{"properties":{"Done":{"checkbox":true}}}`. Clasp removes the row from its visible projection
only after Notion accepts the update.

Editing a Task sends `PATCH /v1/pages/{page_id}` using the saved stable property ID:

- Priority: `{"properties":{"<priority_property_id>":{"select":{"name":"High"}}}}`
- Due Date: `{"properties":{"<due_date_property_id>":{"date":{"start":"YYYY-MM-DD"}}}}`
- Clear Due Date: `{"properties":{"<due_date_property_id>":{"date":null}}}`

Clasp updates its visible projection only after Notion accepts the property change.

Deleting a visible entry sends `PATCH /v1/pages/{page_id}` with `{"in_trash":true}`. The action
requires confirmation, describes Notion Trash recovery, and removes the row only after a
successful response. Notion's API does not permanently delete the page. Deletion is disabled
while a Task's Progress is Working.

Codex lifecycle changes send `PATCH /v1/pages/{page_id}` using the saved stable Progress
property ID, for example
`{"properties":{"<progress_property_id>":{"select":{"name":"Working"}}}}`.
