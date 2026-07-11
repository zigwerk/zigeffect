# zigeffect Local Agent Turn Receipts Design

## Goal

Represent Codex/Claude-style local development turns as first-class workbench
evidence, not as opaque transcript files.

## Decision

Add an `agent_turn` local dev-session event and a `turns` collection on
`LocalDevSessionModel`. A turn captures agent ownership, role, status, summary,
input/output snippets, and an optional artifact path. Static session artifacts
can include `turns`, and live feeds can append/update turns through
`POST /agent-events` or `POST /agent-feed`.

## Architecture

- `causalArtifact.ts` owns the normalized `LocalDevTurnModel`, static artifact
  parser, health counter, and timeline projection.
- `localDevSessionFeed.ts` owns live `agent_turn` parsing and upsert behavior.
- The workbench Dev Session summary shows a turn count, and the timeline shows
  turn rows beside agents, checks, commands, artifacts, transports, guardrails,
  warnings, and next actions.

Turn text is normalized through the existing local dev-session redaction helper
so prompts, outputs, summaries, and artifact paths are safe for browser display.

## Non-Goals

- Do not tail an interactive terminal yet.
- Do not parse provider-specific hidden transcript formats.
- Do not store full unredacted prompts or outputs in the browser model.

## Acceptance Criteria

- Static session artifacts with `turns` normalize into redacted turn models.
- Live `agent_turn` events apply to an existing session and update in sequence.
- Turn rows appear in the derived development timeline.
- Health summary exposes a turn count for the Dev Session metric.
