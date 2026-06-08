# zigeffect Causal Replay Feasibility Design

## Context

M5 now has named snapshot manifests and snapshot comparison. Agents can name a
causal state, compare two named states, and query the underlying causal JSON
artifact. The next honest step is not replay. It is a read-only report that
explains whether a named snapshot has enough information for replay, what would
block replay, and which event evidence is useful for future deterministic
replay work.

Current snapshot manifests explicitly say replay is not feasible because they
reference observed causal artifacts only. This branch preserves that posture.
It adds analysis and evidence, not replay execution, forking, runtime mutation,
or a database-backed state machine.

## Goals

- Add `zig build causal-snapshot -- replay-feasibility <snapshot>`.
- Accept the same snapshot references as compare: snapshot name or explicit
  manifest JSON path.
- Read the snapshot manifest and its referenced causal JSON artifact.
- Emit a deterministic text report with schema
  `zigeffect.causal.replay-feasibility.v1`.
- Preserve the top-level verdict `feasible: false`.
- Explain blockers such as missing effect program inputs, missing service and
  resource constructors, missing scheduler/clock transcripts, unknown event
  kinds, redacted/truncated detail, and sampleable observability events.
- Count structural, finding-evidence, sampleable, unknown, redacted, and
  truncated events.
- Include a bounded event posture sample for agents.
- Print next safe query and comparison commands.

## Non-Goals

- No actual replay execution.
- No effect/fiber/scope forking.
- No runtime memory mutation.
- No source mutation.
- No new database or durable service dependency.
- No direct NenDB package dependency.
- No attempt to reconstruct closures, service values, resource constructors,
  clock values, scheduler state, or external effects.

## Selected Architecture

Extend `tools/causal_snapshot.zig` again. The snapshot tool already owns:

- manifest schema constants;
- snapshot name validation;
- snapshot name/path reference resolution;
- manifest parsing for compare;
- artifact path extraction from manifests.

Add a replay-feasibility layer beside snapshot compare:

- `replay_feasibility_schema = "zigeffect.causal.replay-feasibility.v1"`
- `formatReplayFeasibilityText(allocator, manifest_path, manifest_json,
  artifact_json)`
- `zig build causal-snapshot -- replay-feasibility <snapshot>`

The formatter parses:

- the snapshot manifest metadata;
- the referenced causal JSON artifact events.

Then it computes:

- total events;
- structural event count;
- finding-evidence event count;
- sampleable event count;
- unknown event count;
- redacted detail count;
- truncated detail count;
- presence of service, resource, fiber, schedule, log/metric/span, and unknown
  event categories.

The report is deliberately conservative. It can say an event is useful evidence
for future replay planning, but it must not call any event executable today.

## Event Posture

Each sampled event receives one of these posture labels:

- `structural_observation`: known structural runtime checkpoint.
- `finding_evidence_observation`: known event that may explain a failure or
  invariant breach.
- `sampleable_observation`: log, metric, or span event that may be sampled and
  is never replay input.
- `unknown_taxonomy`: event kind is not known to taxonomy version 1.

The report samples the first 20 events by artifact order. Full event evidence
remains in the causal JSON artifact and can be inspected with `causal-query`.

## Blocking Reasons

The report always includes these baseline blockers:

- snapshot manifests reference observed artifacts, not executable programs;
- no replay engine exists in this branch;
- event records do not serialize service implementations, closures, resource
  constructors, scheduler state, clock transcripts, or external effects.

Conditional blockers:

- service events exist: service values/providers are not serialized;
- resource events exist: resource constructors/finalizers are not serialized;
- fiber events exist: scheduler state and closures are not serialized;
- schedule events exist: timing/randomness decisions are observed, not replay
  inputs;
- sampleable events exist: logs, metrics, and spans may be sampled;
- unknown events exist: taxonomy role semantics are incomplete;
- redacted/truncated detail exists: faithful replay evidence is intentionally
  unavailable.

## CLI

```sh
zig build causal-snapshot -- replay-feasibility <snapshot>
```

`<snapshot>` can be either a snapshot name or an explicit manifest JSON path.
The command reads the manifest, reads `artifact.path`, and prints the report to
stdout.

Example:

```sh
zig build causal-snapshot -- replay-feasibility baseline
```

## Report Shape

```text
zigeffect causal replay feasibility report
schema: zigeffect.causal.replay-feasibility.v1
schema version: 1
snapshot: baseline
manifest: .zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json
target: dogfood
phase: captured
artifact: .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
feasible: false
reason: snapshot manifest references observed causal artifact only
events: 8
structural events: 8
finding evidence events: 4
sampleable events: 0
unknown events: 0
redacted detail events: 0
truncated detail events: 0
blocking reasons:
- snapshot manifest references observed artifacts, not executable programs
- replay engine is not implemented
event posture sample:
- event id=1 kind=run_started posture=structural_observation
next queries:
- zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json snapshot
- zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json lineage 1
```

## Testing

Add tests in `packages/zigeffect/tools/causal_snapshot.zig` for:

- report header, schema, snapshot identity, artifact path, and `feasible:
  false`;
- counts for structural, finding-evidence, sampleable, unknown, redacted, and
  truncated events;
- blocking reasons for service/resource/fiber/schedule/sampleable/unknown and
  redacted/truncated evidence;
- bounded event posture sample;
- CLI usage text includes `replay-feasibility`.

Focused gates:

```sh
cd packages/zigeffect
zig build examples
zig build causal-snapshot
zig build causal-test
zig build causal-snapshot -- capture baseline
zig build causal-snapshot -- replay-feasibility baseline
```

## Documentation

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `packages/zigeffect/docs/causal-scenarios.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Docs must avoid claiming replay is implemented. The wording should be:

1. Snapshot manifests and artifacts can be inspected.
2. Replay feasibility can be explained.
3. Replay remains false until the deterministic replay branch introduces an
   executable replay engine for supported scenarios.

## Exit Criteria

- `zig build causal-snapshot -- replay-feasibility <snapshot>` works for names
  and explicit manifest paths.
- The report keeps `feasible: false`.
- Blockers are deterministic and grounded in event categories.
- The command is read-only and local-artifact based.
- No new database, durable service, or direct NenDB dependency is introduced.
- `zig build examples`, `zig build test --summary none`, `bun run check`, and
  `bun run zig:test` pass before merge.
