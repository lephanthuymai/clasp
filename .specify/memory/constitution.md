<!--
Sync Impact Report
- Version change: template → 1.0.0
- Added principles:
  - I. Native, Focused macOS Experience
  - II. Privacy and User Control
  - III. Specifications Are the Source of Truth
  - IV. Testable Boundaries
  - V. Reliable Capture, Graceful Failure
- Added sections:
  - Product and Technical Constraints
  - Development Workflow and Quality Gates
- Removed sections: none
- Deferred items: none
-->
# Clasp Constitution

## Core Principles

### I. Native, Focused macOS Experience
Clasp MUST behave like a focused macOS utility: fast to invoke, keyboard accessible,
compatible with system appearance and assistive technologies, and unobtrusive when idle.
Every interaction MUST minimize the time between selecting text and confirming a capture.
Platform conventions take precedence over custom interaction patterns.

### II. Privacy and User Control
Selected text, source metadata, Notion credentials, and database identifiers MUST be treated
as private user data. Secrets MUST be stored in Keychain and MUST NOT appear in logs, source
control, analytics, or crash metadata. Clasp MUST transmit captured content only to destinations
the user explicitly configures. Destructive or irreversible actions require clear confirmation.

### III. Specifications Are the Source of Truth
Each user-visible capability MUST begin with a Spec Kit specification, plan, and task list.
Implementation changes MUST remain traceable to an acceptance scenario or documented
requirement. When code and specification disagree, the discrepancy MUST be resolved by
updating the intended behavior and its tests before the work is considered complete.

### IV. Testable Boundaries
Business rules, capture normalization, persistence, and Notion request construction MUST live
behind independently testable boundaries. New behavior MUST include automated tests written
before or alongside implementation. Network and macOS system APIs MUST be represented by
protocols or adapters so tests remain deterministic and do not require real credentials.

### V. Reliable Capture, Graceful Failure
Clasp MUST never silently discard a confirmed capture. Failed Notion submissions MUST remain
recoverable locally and expose an understandable retry path. Permission denials, unsupported
source applications, invalid database schemas, and network failures MUST produce actionable
feedback without destabilizing the app. Simplicity is mandatory: new infrastructure requires
evidence that the current design cannot meet an accepted requirement.

## Product and Technical Constraints

- The primary client MUST be a native Swift macOS application.
- Core behavior MUST remain usable without telemetry or account creation beyond the user's
  Notion integration.
- The repository MUST use an OSI-approved license; Apache-2.0 is the default project license.
- Third-party dependencies MUST be minimal, actively maintained, license-compatible, and
  justified in the implementation plan.
- Accessibility permission MUST be requested only when a feature requires it, with a plain
  explanation and a path to System Settings.
- Supported macOS versions and Notion API versions MUST be explicit in each relevant plan.

## Development Workflow and Quality Gates

Work MUST follow the Spec Kit sequence: constitution, specification, clarification when needed,
plan, tasks, analysis when risk warrants it, implementation, and convergence. A change is
complete only when acceptance scenarios pass, automated tests pass, secrets are absent from
the diff, and user-facing setup or permission changes are documented. Reviews MUST explicitly
check privacy, accessibility, failure recovery, and unnecessary complexity.

## Governance

This constitution supersedes conflicting project practices. Amendments MUST be proposed in
writing, explain their impact on existing specifications and code, and include any required
migration work. Semantic versioning governs this document: MAJOR for incompatible governance
changes, MINOR for new or materially expanded principles, and PATCH for clarifications.
Every feature plan and review MUST include a constitution compliance check. Exceptions MUST
be recorded in the relevant plan's Complexity Tracking section with rationale and a simpler
alternative that was rejected.

**Version**: 1.0.0 | **Ratified**: 2026-07-30 | **Last Amended**: 2026-07-30
