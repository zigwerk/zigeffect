# zigeffect Roadmap M28-M31 Design

Date: 2026-06-24

## Context

M24-M27 added the first network-facing and operator-facing artifact contracts:
the collector has a command inbox, evals can emit linked diff artifacts, ops
reads can be formatted as gated responses, and runner lineage can carry
deployment metadata.

This slice turns those contracts into slightly stronger integration points while
preserving the core boundary. The Zig core still does not import Bun/WebSocket or
make HTTP calls. The collector/workbench layer can validate network payloads;
the core can consume already-decoded command batches.

## Goals

- Add a typed client/parser for `GET /commands?after=<sequence>` responses.
- Add a core helper that applies one polled command batch and carries the next
  inbox cursor forward.
- Register the new artifact families in the schema governance inventory.
- Add an external alert delivery JSON envelope that can be handed to a real
  delivery adapter later.

## Non-Goals

- No long-running engine daemon yet.
- No outbound HTTP client inside `packages/zigeffect`.
- No actual Slack/PagerDuty/email transport.
- No new report-only tool.

## Milestones

### M28 - Typed command inbox client

Add `fetchLiveCommands` and validation helpers in the workbench live attach
module. The helper appends `after`, validates `commands` and `next_after`, and
returns typed command frames.

### M29 - Core polled command batch bridge

Add `CausalLiveCommandPollBatch` and `runCausalLiveCommandPolledBatch` in the
core live command service. It consumes decoded command envelopes, runs the
existing tap batch, and returns the next cursor.

### M30 - Schema governance for new artifacts

Register semantic diff, eval diff, ops artifact response, ops runbook, ops alert
delivery, and runner lineage schemas in `causal_schema_governance.zig`.

### M31 - External alert delivery envelope

Add `formatCausalOpsAlertDeliveryJson` so an alert fact can be converted to a
redacted, delivery-adapter-ready artifact without actually sending it.

## Acceptance

- Workbench tests prove command inbox responses validate and reject invalid
  frames.
- Zig tests prove a polled batch applies commands and preserves the inbox cursor.
- Schema governance tests prove the inventory count and new schemas are present.
- Ops alert tests prove the delivery envelope redacts sentinel text.
