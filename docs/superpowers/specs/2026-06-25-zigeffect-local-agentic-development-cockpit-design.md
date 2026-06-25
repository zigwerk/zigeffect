# zigeffect Local Agentic Development Cockpit Design

Date: 2026-06-25

## Goal

Make zigeffect the local development runtime that Codex, Claude Code, and the
zigeffect causal tools can all use as shared evidence. The workbench should show
what the agents are doing, which local checks ran, which causal artifacts were
created, and what the graph says about the session.

This is explicitly local-first. No hosted control plane, cloud identity, or
remote storage is required for this phase.

## User outcome

A developer can run local zigeffect dogfood commands, open the SolidJS
workbench, and see a session cockpit with:

- the current local goal and phase;
- participating agents such as Codex, Claude Code, and zigeffect tools;
- command/check receipts with pass/fail/running status;
- links to before, after, verdict, audit, and diff artifacts;
- guardrails and next actions that tell an agent what is allowed to happen next.

The workbench remains read-only. Applying source changes stays outside the
causal tools unless an explicit human-approved policy path exists.

## Current substrate

- `tools/causal_dev_session.zig` already emits
  `zigeffect.causal.dev-session.v1` JSON and text receipts.
- The receipt records target, phase, command records, artifact paths, guardrails,
  and next actions.
- The Solid workbench already parses causal artifacts, governance artifacts,
  semantic diffs, and live frames.
- The collector and live attach path can stream engine facts into the same
  workbench model.

## Local session artifact contract

The first supported cockpit input is the existing
`zigeffect.causal.dev-session.v1` artifact, extended in a backward-compatible
way.

Required fields:

- `schema`
- `schema_version`
- `mode`
- `target`
- `phase`
- `status`
- `commands`
- `artifacts`

Optional fields:

- `session_id`
- `title`
- `goal`
- `agents`
- `checks`
- `next_actions`
- `guardrails`
- `warnings`

The workbench must tolerate older receipts that only have the required fields.
When `agents` or `checks` are missing, it derives useful local defaults from the
commands and session status.

## Milestone schedule

### M72 - Local development session protocol

Normalize the dev-session artifact in TypeScript and expose a stable
`LocalDevSessionModel`.

Acceptance:

- Existing `zigeffect.causal.dev-session.v1` receipts parse without schema
  migration.
- Extended receipts with agents, checks, artifacts, commands, next actions, and
  guardrails normalize to a stable model.
- Partial receipts do not crash the workbench.

### M73 - Workbench agent cockpit view

Add a read-only Agents tab to the Solid workbench.

Acceptance:

- The tab appears with the existing workbench tabs.
- A dev-session artifact renders goal, phase, agents, checks, artifacts,
  commands, guardrails, and next actions.
- Non-session artifacts show an empty state instead of failing.

### M74 - Dogfood session receipt enrichment

Extend `tools/causal_dev_session.zig` so local self-improvement runs emit
agent-aware receipt fields.

Acceptance:

- `start` receipts include local session identity, goal, default agent list, and
  baseline check receipt.
- `assess` receipts include after, agent, diagnosis, remediation-plan, and audit
  check receipts.
- JSON and text receipts stay redacted, deterministic, and covered by Zig tests.

### M75 - Live agent runtime feed

Map local session events into the live workbench stream.

Acceptance:

- A local host can emit agent/session frames while engine NDJSON is streaming.
- The workbench updates the session view without a static reload.
- Frames reuse the collector redaction boundary.

### M76 - Local Codex and Claude Code adapters

Define simple local append-only adapters that let agent CLIs write session
events or consume session receipts.

Acceptance:

- Codex and Claude Code can be represented as local agents without network
  services.
- Adapter output is JSONL or JSON that the workbench can ingest.
- The adapter contract documents ownership, redaction, and failure behavior.

### M77 - Local reliability gate

Add one local command that proves a development session is honest enough to hand
to another agent.

Acceptance:

- The gate checks workbench parsing, Zig dev-session receipt tests, tool hygiene,
  secret redaction, and local artifact links.
- The gate fails on stale status claims and missing evidence artifacts.

## Non-goals

- Hosted dashboards.
- Remote agent orchestration.
- Automatic source mutation from the workbench.
- Replacing Codex or Claude Code with a zigeffect-specific editor.

## Design choices

- Reuse `zigeffect.causal.dev-session.v1` rather than creating a parallel
  session schema.
- Derive missing agent/check rows from existing command records so old artifacts
  remain useful.
- Keep the UI dense and operational, matching the existing workbench rather than
  introducing a marketing-style dashboard.
- Treat local agent activity as causal evidence, not chat transcript storage.

