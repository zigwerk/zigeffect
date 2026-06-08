# Zigeffect Causal Snapshot Manifest Design

## Context

M5 moves the causal runtime from "single artifact inspection" toward named
states that agents can compare, cite, and eventually replay. The codebase
already has causal JSON artifacts, query reports, compare reports, dev-loop
before/after JSON pairs, audit-chain reports, and an artifact retention map.
What is missing is a versioned, machine-readable manifest that gives a causal
JSON artifact a stable name and a small amount of derived metadata.

This branch is the first M5 slice. It does not add replay execution, forking,
Cockroach, Hyperdrive, filesystem watchers, or a database. It adds a local
snapshot manifest tool over existing causal JSON artifacts.

## Goals

- Add schema `zigeffect.causal.snapshot-manifest.v1`.
- Add a `zig build causal-snapshot` tool.
- Produce JSON and text manifests for named causal snapshot states.
- Support a pure in-memory formatter for tests and future tools.
- Support a `manifest` command that prints a manifest for an explicit causal
  JSON artifact path.
- Support a `capture` command that writes manifest JSON and text files for an
  existing known artifact path.
- Keep capture read-only with respect to source/runtime code and existing
  causal JSON artifacts.
- Include enough metadata for agents to decide what to query next and whether
  replay is currently feasible.

## Non-Goals

- No deterministic replay engine.
- No snapshot diff engine beyond links to existing compare reports.
- No changes to `CausalStore` or causal event semantics.
- No database-backed snapshot index.
- No CockroachDB or RoachGraph work.
- No automatic test execution from `causal-snapshot capture`.

## Design Options Considered

### Option A: Extend `causal-artifacts`

The existing artifact manifest could list named snapshots directly.

This keeps one command, but that file is a human/CI retention map. Adding
versioned per-snapshot metadata there would mix static upload guidance with
stateful snapshot identity.

### Option B: Add A Dedicated Snapshot Manifest Tool

Add `tools/causal_snapshot.zig` with reusable formatters and a `causal-snapshot`
build step. Keep it independent from the existing retention manifest, but let
docs and `causal-artifacts` mention the new output paths.

This is the recommended option. It gives M5 a clear home without changing the
existing query, compare, or dev-loop command contracts.

### Option C: Build Snapshot Manifests Into Dev Loop Only

The dev loop could write snapshot manifests after `baseline` and `after`.

This will be useful later, but it is too narrow as the first step. Agents should
also be able to name dogfood and scenario artifacts outside the dev-loop path.

## Selected Architecture

Implement Option B.

The new tool has two layers:

- Pure formatters:
  - parse causal JSON artifact metadata and events
  - compute event count, event id range, finding count, and compatibility
    warnings
  - produce JSON and text manifest output
- CLI commands:
  - `manifest <name> <artifact.json> [options]` prints JSON to stdout
  - `capture <name> [scenario]` reads a known existing artifact and writes
    `.json` plus `.txt` manifest files under `.zig-cache/causal-artifacts`

`capture` intentionally does not run scenarios or package tests. To capture a
fresh causal state, the operator first runs the existing producer:

```sh
zig build causal-test
zig build causal-run -- package-tests
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
```

Then `causal-snapshot capture` names whichever existing JSON artifact should be
used as the snapshot source.

## Snapshot Manifest JSON Shape

The formatter should emit deterministic JSON with this shape:

```json
{
  "schema": "zigeffect.causal.snapshot-manifest.v1",
  "schema_version": 1,
  "name": "baseline",
  "target": "dogfood",
  "phase": "baseline",
  "artifact": {
    "path": ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
    "schema": "zigeffect.causal.v1",
    "schema_version": 1,
    "event_taxonomy_version": 1,
    "events": 6,
    "first_event_id": 1,
    "last_event_id": 6,
    "findings": 3
  },
  "related": {
    "baseline_path": null,
    "compare_report_path": null,
    "query_report_path": null,
    "advice_report_path": null
  },
  "replay": {
    "feasible": false,
    "reason": "snapshot manifest references observed causal artifact only"
  },
  "next_queries": [
    "zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json snapshot"
  ],
  "warnings": []
}
```

The manifest does not embed the full causal event list. The causal JSON artifact
remains the source of event truth.

## Text Summary Shape

The text formatter should emit:

```text
zigeffect causal snapshot manifest
schema: zigeffect.causal.snapshot-manifest.v1
name: baseline
target: dogfood
phase: baseline
artifact: .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
events: 6
event ids: 1..6
findings: 3
replay feasible: false
replay reason: snapshot manifest references observed causal artifact only
next queries:
- zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json snapshot
```

If compatibility warnings exist, append a `warnings:` section.

## CLI

### `manifest`

```sh
zig build causal-snapshot -- manifest <name> <artifact.json> \
  [--target <target>] \
  [--phase <phase>] \
  [--baseline <baseline.json>] \
  [--compare-report <compare.txt>] \
  [--query-report <queries.txt>] \
  [--advice-report <advice.txt>] \
  [--format json|text]
```

Default format is `json`. The command reads `<artifact.json>` and writes the
selected manifest format to stdout.

### `capture`

```sh
zig build causal-snapshot -- capture <name> [scenario]
```

The command reads a known existing causal JSON artifact and writes:

- `.zig-cache/causal-artifacts/zigeffect-causal-snapshot-<name>.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-snapshot-<name>.txt`

Source selection:

- no scenario: `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.json`
- scenario slug: `causal_run.artifactPaths(slug).json_path`

The output should print the manifest paths and next query command. Invalid names
are rejected before any write. Unknown scenarios use the existing
`causal_run.scenarioByName` validation.

## Name Validation

Snapshot names become file names, so they must be conservative:

- allowed bytes: `a-z`, `A-Z`, `0-9`, `_`, `-`
- at least 1 byte
- at most 64 bytes
- cannot be `.` or `..`

The tool should return `error.InvalidSnapshotName` for invalid names.

## Finding Count

Use the same local finding heuristic already used by compare/advice tools:

- unfinalized resources
- pending fibers after scope close
- failed finalizers
- exhausted retry schedules
- missing service requirements
- failed assertions

This keeps the manifest useful without depending on a new finding schema.

## Compatibility

The snapshot formatter should reuse `causal_artifact` compatibility helpers for
causal JSON artifact metadata:

- unsupported causal artifact schema name
- future causal artifact schema version
- future event taxonomy version
- unknown event kinds

Warnings belong in both JSON and text manifests. The snapshot manifest schema
itself starts at version `1`.

## Build Integration

Add:

- module `tools/causal_snapshot.zig`
- executable `zigeffect-causal-snapshot`
- build step `zig build causal-snapshot`
- tests included in `zig build examples`

The branch should not make `zig build causal-snapshot` run scenarios by default.
That keeps `zig build examples` deterministic and lightweight.

## Documentation

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `packages/zigeffect/docs/causal-scenarios.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

The docs should make the operational sequence explicit:

1. Generate a causal JSON artifact with an existing command.
2. Name it with `causal-snapshot`.
3. Query or compare the underlying causal JSON artifact.
4. Treat replay as not feasible until later M5 branches add deterministic replay
   support.

## Verification

Focused gates:

- `zig build causal-snapshot -- manifest baseline .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json`
- `zig build causal-snapshot`
- `zig build examples`

Package and repo gates:

- `zig build test-raw --summary none`
- `zig build test --summary none`
- `zig build causal-test-matrix`
- `bun run check`
- `bun run zig:test`
- `git diff --check HEAD`
