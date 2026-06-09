# zigeffect Causal Deterministic Replay Design

## Context

M5 now has named snapshot manifests, snapshot comparison, and replay feasibility
reports. Those tools are intentionally observational: they read causal artifacts
and explain what changed or why arbitrary replay is not possible.

The next useful step is a narrow deterministic replay slice for agentic
development loops. In this branch, "replay" means rerunning an explicitly
registered `causal_run` scenario and comparing the newly observed causal JSON
artifact with a named baseline snapshot. It does not mean reconstructing effect
closures, services, fibers, resources, clock state, external IO, or runtime
memory from a causal event log.

The user has also narrowed durable storage direction: no CockroachDB work for
now. The active storage boundary remains the deterministic in-memory store,
local causal artifacts, backend contracts, and the NenDB adapter contract.

## Goals

- Add a first execution path for deterministic replay:
  `zig build causal-snapshot -- replay-scenario <snapshot> <scenario>`.
- Accept the same snapshot references as compare and replay-feasibility:
  snapshot name or explicit manifest JSON path.
- Require `<scenario>` to resolve through the existing `causal_run` scenario
  registry.
- Rerun the scenario command using the registered `argv`.
- Convert the command result into causal command artifacts using the existing
  `causal_run.buildCommandArtifacts` path.
- Write replay artifacts under `.zig-cache/causal-artifacts/` without
  overwriting canonical scenario artifacts.
- Compare the baseline snapshot artifact with the replay artifact using
  `causal_compare.runCompare`.
- Emit a deterministic text report with schema
  `zigeffect.causal.deterministic-replay.v1`.
- Make the report explicit that arbitrary event-log replay remains unsupported.
- Preserve clear next queries for agents.

## Non-Goals

- No arbitrary causal JSON event-log replay.
- No closure, service, resource, fiber, scheduler, clock, or external IO
  reconstruction.
- No runtime memory patching or mutation.
- No source mutation.
- No effect/fiber/scope forking.
- No database dependency.
- No CockroachDB or RoachGraph backend work.
- No direct NenDB package dependency in this slice.
- No claim that passing replay proves production determinism.

## Selected Architecture

Extend `packages/zigeffect/tools/causal_snapshot.zig`. The snapshot tool already
owns snapshot name validation, manifest reference resolution, manifest artifact
path extraction, snapshot comparison, and replay-feasibility reporting. Keeping
the first replay slice there avoids a new CLI surface while M5 is still centered
on named snapshots.

The implementation adds:

- `deterministic_replay_schema =
  "zigeffect.causal.deterministic-replay.v1"`;
- `formatDeterministicReplayText(...)`, a pure formatter for testable report
  output;
- replay artifact path helpers that include the snapshot name and scenario slug;
- a `replay-scenario` CLI subcommand that:
  1. resolves the baseline snapshot manifest;
  2. reads the manifest's referenced causal JSON artifact;
  3. resolves the scenario from `causal_run.scenarioByName`;
  4. runs the registered command;
  5. builds causal command artifacts for the observed command result;
  6. writes replay `.txt`, `.json`, and `.dot` artifacts under a replay-specific
     prefix;
  7. prints a deterministic replay report comparing baseline artifact to replay
     artifact.

## Report Semantics

The report uses this posture:

- `executed: true` when the registered scenario command was run.
- `mode: registered_scenario_rerun`.
- `arbitrary event replay: false`.
- `verdict: matched` when the event comparison has no added, removed, changed,
  or finding deltas.
- `verdict: changed` when the comparison detects causal event differences.
- `verdict: command_failed` when the command result conflicts with the
  scenario's expected outcome.

The first implementation should be conservative about verdicts. A successful
registered scenario rerun plus a non-empty compare report is already useful for
agents. The key invariant is that the report never says the event log itself was
executed.

## Artifact Paths

Replay artifacts should not overwrite canonical scenario artifacts from
`zig build causal-run -- <scenario>`.

Path shape:

```text
.zig-cache/causal-artifacts/zigeffect-causal-replay-<snapshot>-<scenario>.txt
.zig-cache/causal-artifacts/zigeffect-causal-replay-<snapshot>-<scenario>.json
.zig-cache/causal-artifacts/zigeffect-causal-replay-<snapshot>-<scenario>.dot
```

The snapshot component is the manifest's `name` field for normal snapshot
manifests. If an explicit path points to a manifest with an invalid name, the
command should fail rather than create ambiguous artifact paths.

## CLI

```sh
zig build causal-snapshot -- replay-scenario <snapshot> <scenario>
```

Examples:

```sh
zig build causal-run -- causal-scoped-fiber
zig build causal-snapshot -- capture scoped-baseline causal-scoped-fiber
zig build causal-snapshot -- replay-scenario scoped-baseline causal-scoped-fiber
```

`<snapshot>` can be a snapshot name or an explicit manifest JSON path.
`<scenario>` must be a registered scenario slug from `zig build causal-catalog`.

## Report Shape

```text
zigeffect causal deterministic replay report
schema: zigeffect.causal.deterministic-replay.v1
schema version: 1
mode: registered_scenario_rerun
executed: true
arbitrary event replay: false
snapshot: scoped-baseline
manifest: .zig-cache/causal-artifacts/zigeffect-causal-snapshot-scoped-baseline.json
baseline artifact: .zig-cache/causal-artifacts/zigeffect-causal-causal-scoped-fiber.json
scenario: causal-scoped-fiber
scenario expectation: expected_pass
scenario owner: fiber_runtime
replay report: .zig-cache/causal-artifacts/zigeffect-causal-replay-scoped-baseline-causal-scoped-fiber.txt
replay artifact: .zig-cache/causal-artifacts/zigeffect-causal-replay-scoped-baseline-causal-scoped-fiber.json
replay dot: .zig-cache/causal-artifacts/zigeffect-causal-replay-scoped-baseline-causal-scoped-fiber.dot
command status: success
verdict: matched
boundary:
- replay reruns a registered deterministic scenario command
- replay does not execute or reconstruct causal event logs
- replay does not reconstruct services, closures, resources, fibers, clocks, scheduler state, external IO, or runtime memory
event compare:
zigeffect causal compare report
...
next queries:
- zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-causal-scoped-fiber.json snapshot
- zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-replay-scoped-baseline-causal-scoped-fiber.json snapshot
- zig build causal-snapshot -- replay-feasibility scoped-baseline
```

## Testing

Unit tests should cover:

- deterministic replay report formatting includes schema, mode, boundary, paths,
  scenario metadata, command status, verdict, compare output, and next queries;
- replay artifact path generation is stable and validates snapshot/scenario
  names;
- usage text lists `replay-scenario`.

CLI verification should cover:

- capture a baseline for `causal-scoped-fiber`;
- replay that baseline through `replay-scenario`;
- confirm replay artifacts exist;
- confirm the report includes `mode: registered_scenario_rerun` and
  `arbitrary event replay: false`.

## Agent Value

This gives development agents a concrete self-improvement loop:

1. capture a baseline for a known causal scenario;
2. edit zigeffect;
3. rerun the scenario as a replay check;
4. compare causal evidence before and after;
5. use event ids and next queries to decide whether behavior changed for good
   reasons.

It also keeps the trust boundary honest. Agents can rely on the report as
evidence that a registered scenario was rerun and compared, not as evidence that
zigeffect can replay arbitrary event logs.

## Self-Review

- Placeholder scan: no placeholder implementation details remain.
- Internal consistency: the CLI, report schema, artifact path shape, and
  non-goals all describe registered-scenario rerun only.
- Scope check: this is a single M5 branch scoped to local causal artifacts and
  registered scenarios.
- Ambiguity check: "replay" is explicitly defined as scenario rerun and compare,
  not event-log execution.
