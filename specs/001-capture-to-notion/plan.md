# Implementation Plan: Capture Selected Text to Notion

**Branch**: `001-capture-to-notion` | **Date**: 2026-07-30 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-capture-to-notion/spec.md`

## Summary

Build Clasp as a native menu-bar macOS utility that reads the frontmost application's selected
text through macOS Accessibility, presents a compact keyboard-first review panel, durably
queues the confirmed Task or Bookmark, provisions separate Clasp Tasks and Bookmarks databases,
and delivers each capture to its type-specific Notion data source. The
implementation uses a Swift package with a testable core library and an AppKit/SwiftUI
executable, Apple system frameworks only, a private atomic JSON outbox, Keychain credentials,
and the versioned Notion REST interface.

## Technical Context

**Language/Version**: Swift 6.3, strict concurrency enabled

**Primary Dependencies**: AppKit, SwiftUI, ApplicationServices Accessibility, Security,
Foundation/URLSession, and the installed Codex desktop app's bundled app-server executable;
no third-party runtime packages

**Storage**: Atomic versioned JSON document in Application Support for captures and non-secret
configuration; macOS Keychain for the Notion token; UserDefaults for shortcut preferences

**Testing**: Swift Testing for unit and contract tests, dependency-injected in-memory
repositories and HTTP transport fakes; manual accessibility and cross-application smoke tests

**Target Platform**: macOS 14 or later, Apple Silicon first; Notion API version `2026-03-11`

**Project Type**: Native menu-bar desktop application with a reusable core library

**Performance Goals**: Capture panel ready within 500 ms at p95; local confirmation persisted
before network delivery; recent list remains responsive with 10,000 captures

**Constraints**: Keyboard and VoiceOver accessible; no telemetry; no readable secrets in files
or logs; no silent clipboard reads; offline-capable outbox; no full Xcode installation is
available in the current build environment

**Scale/Scope**: One local user, one Notion parent page with two managed databases/data sources,
five utility surfaces (main library, capture, setup/settings, recent captures, menu), manual
entry creation, manual retries, and user-initiated Task handoff to Codex

## Constitution Check

*GATE: Passed before Phase 0 research and re-checked after Phase 1 design.*

- **Native, Focused macOS Experience**: PASS. AppKit owns the status item, global shortcut, and
  non-activating capture behavior; SwiftUI supplies adaptive, accessible views.
- **Privacy and User Control**: PASS. Tokens live only in Keychain, clipboard use is explicit,
  diagnostics exclude capture bodies, networking targets the configured Notion API, and Task
  content reaches Codex only after an explicit Ask Codex confirmation.
- **Specifications Are the Source of Truth**: PASS. The design and tasks trace to FR/SC entries
  in `spec.md`.
- **Testable Boundaries**: PASS. Repositories, credential storage, selection reading, shortcut
  registration, time, and HTTP transport are protocol boundaries.
- **Reliable Capture, Graceful Failure**: PASS. The local outbox is written before delivery,
  delivery states are durable, and each capture routes deterministically by type.
- **Technical constraints**: PASS. The plan is native Swift, uses no third-party dependency,
  documents macOS 14+ and Notion `2026-03-11`, and includes permission guidance.

Post-design re-check: PASS. Contracts preserve explicit consent, recovery, accessibility, and
minimal-dependency requirements. No constitution exception is required.

## Project Structure

### Documentation (this feature)

```text
specs/001-capture-to-notion/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── capture-ui.md
│   └── notion.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
Package.swift
Sources/
├── ClaspCore/
│   ├── Models/
│   ├── Persistence/
│   ├── Notion/
│   └── Services/
└── ClaspApp/
    ├── App/
    ├── Capture/
    ├── HotKey/
    ├── Selection/
    ├── Main/
    └── Views/
Tests/
└── ClaspCoreTests/
    ├── Persistence/
    ├── Notion/
    └── Services/
```

**Structure Decision**: A single Swift package separates portable, deterministic business logic
in `ClaspCore` from macOS lifecycle and UI adapters in `ClaspApp`. This is the smallest layout
that lets `swift test` validate persistence, request construction, schema validation, and retry
behavior without Accessibility permission, credentials, network access, or a running UI.

## Complexity Tracking

No constitution violations require justification.
