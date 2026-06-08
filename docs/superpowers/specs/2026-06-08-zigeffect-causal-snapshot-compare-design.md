# zigeffect Causal Snapshot Compare Design

## Context

M5 is moving the causal runtime from individual artifact inspection toward
named states that agents can compare, cite, and eventually replay. The previous
slice added `zigeffect.causal.snapshot-manifest.v1`, which names an existing
causal JSON artifact and records event counts, finding counts, replay posture,
and compatibility warnings.

This branch adds the next M5 slice: compare two named snapshot manifests and
their underlying causal JSON artifacts. It stays local-artifact first. It does
not add replay execution, filesystem watchers, a database index, direct NenDB
package integration, SQL history, or durable service dependencies.

## Goals

- Add snapshot-level comparison under `zig build causal-snapshot -- compare`.
- Accept either snapshot names or explicit manifest JSON paths.
- Parse `zigeffect.causal.snapshot-manifest.v1` metadata.
- Read each manifest's referenced `artifact.path`.
- Reuse the existing `causal_compare.runCompare` event-level diff.
- Emit a deterministic text report that starts with snapshot identity and then
  embeds the event compare report.
- Preserve manifest warnings and surface manifest schema/version mismatches.
- Keep the command read-only over source files, runtime state, and existing
  causal artifacts.

## Non-Goals

- No deterministic replay or forking.
- No new causal event diff algorithm.
- No database-backed snapshot lookup.
- No direct NenDB package dependency.
- No SQL durable-history adapter.
- No automatic test or scenario execution.
- No source mutation or registry updates.

## Design Options Considered

### Option A: Add A New `causal-snapshot-compare` Tool

A separate executable would keep comparison code physically isolated.

This is straightforward, but it fragments the M5 user experience. Agents would
need to remember one command for naming snapshots and another command for using
those names.

### Option B: Extend `causal-snapshot`

Add a `compare <left> <right>` subcommand to `tools/causal_snapshot.zig`.

This is the chosen approach. The existing snapshot tool already owns manifest
schema, name validation, and deterministic snapshot paths. Adding compare there
keeps the interface cohesive while still delegating event-level comparison to
`causal_compare.runCompare`.

### Option C: Add Compare Links Only To Manifests

The manifest formatter could emit richer `next_queries` and leave actual
snapshot comparison to `causal-compare`.

This keeps code small, but it fails the agent workflow. Agents should be able
to compare named states directly without manually extracting artifact paths from
manifest JSON.

## Selected Architecture

Implement Option B.

`tools/causal_snapshot.zig` gets three new layers:

- Snapshot manifest parsing:
  - parse `schema`, `schema_version`, `name`, `target`, `phase`, `artifact`,
    and `warnings`;
  - ignore unknown fields for forward compatibility;
  - preserve missing or future manifest warnings in the report.
- Snapshot reference resolution:
  - arguments containing `/` or ending in `.json` are treated as explicit
    manifest paths;
  - other arguments are validated as snapshot names and resolved with
    `snapshotManifestPaths`;
  - invalid names fail before any artifact read.
- Snapshot compare formatting:
  - build a short snapshot summary for left and right;
  - show event and finding counts from the manifests;
  - show manifest warnings and schema/version warnings;
  - embed the existing causal compare report generated from the referenced
    causal JSON artifacts;
  - print next query commands for both underlying artifacts and the raw
    `causal-compare` command.

The build graph imports `causal_compare` into the snapshot tool module. This is
the only new code dependency.

## CLI

```sh
zig build causal-snapshot -- compare <left> <right>
```

`<left>` and `<right>` can be either:

- snapshot names, such as `baseline` and `after`;
- explicit manifest JSON paths, such as
  `.zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json`.

The command reads the two manifest JSON files, reads each manifest's
`artifact.path`, and prints a text report to stdout.

Example:

```sh
zig build causal-snapshot -- compare baseline after
```

## Report Shape

The text report should be deterministic:

```text
zigeffect causal snapshot compare report
schema: zigeffect.causal.snapshot-compare.v1
left snapshot: baseline
left manifest: .zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json
left target: dogfood
left phase: baseline
left artifact: .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
left events: 2
left findings: 1
right snapshot: after
right manifest: .zig-cache/causal-artifacts/zigeffect-causal-snapshot-after.json
right target: dogfood
right phase: after
right artifact: .zig-cache/causal-artifacts/zigeffect-causal-dogfood-after.json
right events: 3
right findings: 0
event delta from manifests: +1
finding delta from manifests: -1
manifest warnings:
- none
event compare:
zigeffect causal compare report
...
next queries:
- zig build causal-query -- --file <left-artifact> snapshot
- zig build causal-query -- --file <right-artifact> snapshot
- zig build causal-compare -- <left-artifact> <right-artifact>
```

The report should not embed full snapshot manifests. The manifest files and
causal JSON artifacts remain the source of truth.

## Compatibility

The snapshot compare command should warn when:

- a manifest schema is not `zigeffect.causal.snapshot-manifest.v1`;
- a manifest schema version is newer than supported;
- a manifest carries artifact compatibility warnings.

The underlying causal artifact comparison continues to use
`causal_compare.runCompare`, so existing causal artifact schema and taxonomy
warnings are preserved in the embedded event compare section.

## Testing

Add tests in `packages/zigeffect/tools/causal_snapshot.zig` for:

- formatting a snapshot compare report from two manifests and two causal JSON
  artifacts;
- preserving manifest identity, targets, phases, event counts, finding counts,
  and signed deltas;
- surfacing manifest warnings;
- resolving names to deterministic manifest paths while leaving explicit JSON
  paths untouched;
- rejecting invalid named references.

Focused red/green command:

```sh
cd packages/zigeffect
zig build examples
```

Manual CLI smoke after implementation:

```sh
cd packages/zigeffect
zig build causal-test
zig build causal-snapshot -- capture baseline
zig build causal-snapshot -- compare baseline baseline
```

## Documentation

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `packages/zigeffect/docs/causal-scenarios.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

The docs should make the sequence explicit:

1. Generate causal JSON artifacts.
2. Name artifacts with snapshot manifests.
3. Compare snapshot names or manifest paths.
4. Query underlying causal JSON artifacts for event-level detail.
5. Keep replay marked infeasible until later M5 work.

## Exit Criteria

- `zig build causal-snapshot -- compare <left> <right>` works for names and
  explicit manifest paths.
- The report cites snapshot names, manifest paths, artifact paths, signed event
  deltas, signed finding deltas, manifest warnings, and the underlying causal
  compare report.
- The command remains read-only and local-artifact based.
- No SQL durable-history dependency is introduced.
- `zig build examples`, `zig build test --summary none`, `bun run check`, and
  `bun run zig:test` pass before merge.
