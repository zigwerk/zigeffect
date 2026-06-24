# zigeffect Roadmap M20-M23 Design

Date: 2026-06-24

## Goal

Continue the remaining frontier after M19 with another bounded implementation
slice:

- M20: live engine command tap abstraction.
- M21: Zig semantic diff artifact emission.
- M22: graph-linked workbench Diff UX.
- M23: ops alert sink and runbook artifact.

## Design

### M20 Live Engine Command Tap

`applyCausalLiveCommand` executes one command. Add a small tap abstraction for a
running engine loop:

- `CausalLiveCommandEnvelope`: a command plus sequence number.
- `CausalLiveCommandTap`: owns no transport; it processes command envelopes
  through `applyCausalLiveCommand` and records result counters.
- `runCausalLiveCommandTapBatch`: deterministic helper for tests and local
  collectors.

This is the engine-side loop substrate, not a network client.

### M21 Zig Semantic Diff Artifact Emission

The workbench can render `semantic_diff` payloads. Add a formatter in
`causal_diff.zig` that emits a complete JSON artifact shape:

- `schema: "zigeffect.causal.semantic-diff.v1"`;
- before/after artifact labels;
- summary counters;
- arrays for resolved/introduced findings, fiber terminals, resource
  finalizations, and lineage edges.

### M22 Graph-Linked Diff UX

The Diff tab currently displays entries as static rows. Make entries with event
ids clickable so agents and humans can jump back to the causal graph/timeline
selection.

The UI still stays read-only. It only calls `setSelectedId`.

### M23 Ops Alert Sink And Runbook Artifact

`CausalOpsPolicy` emits alert events. Add a small alert sink/runbook module:

- `CausalOpsAlertSink`: callback-based sink for alert events.
- `emitCausalOpsAlerts`: sends alert events from a store snapshot to the sink.
- `formatCausalOpsRunbookJson`: emits a bounded operator runbook artifact with
  deployment metadata, retention policy, and alert summary.

This is local operator evidence, not an external incident-management integration.

## Testing

- Zig tests prove command tap batch processing applies approved commands and
  counts rejected commands.
- Zig tests prove semantic diff JSON is parseable by the workbench shape.
- Workbench tests prove Diff tab rows can select event ids.
- Zig tests prove alert sinks receive alert facts and runbook JSON redacts and
  carries retention posture.

## Non-Goals

- No transport-specific command client.
- No source mutation.
- No external alert service integration.
- No exact event-id graph isomorphism.
