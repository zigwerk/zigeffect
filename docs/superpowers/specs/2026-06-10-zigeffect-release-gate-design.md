# zigeffect Release Gate Design

Date: 2026-06-10

Milestone: 46 - Release Gate

## Goal

Finish the first release-quality durable workflow and local cluster foundation
with one reproducible package command and the documentation needed to explain
what that command proves.

The release gate must cover durable workflow crash recovery, local and durable
cluster behavior, public API stability, storage conformance, bounded resources,
examples, CI artifact paths, quickstart instructions, a completion report, and
migration notes from the deterministic-only runtime to the durable runtime.

## Current Context

`packages/zigeffect/build.zig` already exposes focused gates:

- `zig build test`
- `zig build test-raw`
- `zig build public-api-review`
- `zig build storage-conformance`
- `zig build property-crash`
- `zig build performance-bounds`
- `zig build examples`
- `zig build causal-test`
- `zig build causal-artifacts`

The examples suite already includes durable workflow examples and multi-runner
cluster examples, including `cluster_workflow_migration.zig`. Crash recovery is
covered by generated property tests and causal artifacts, but the roadmap
acceptance asks for a durable workflow crash recovery example. Milestone 46
should add that example as a first-class executable and test.

CI currently runs causal artifacts, examples, and the package test gate. It
uploads causal artifacts on failure. Milestone 46 should make CI run the new
release gate and upload the release-gate report paths as well.

## Selected Architecture

Add a durable crash recovery example:

- `packages/zigeffect/examples/workflow_crash_recovery.zig`

The example writes a valid workflow prefix to a file-backed journal, simulates a
crash by appending a partial JSON row to the active segment, reopens the journal,
and proves recovery trims the partial tail while retaining the committed state.

Add a release report tool:

- `packages/zigeffect/tools/release_gate_report.zig`

The tool writes deterministic text and JSON reports under:

- `.zig-cache/release-gate/zigeffect-release-gate.txt`
- `.zig-cache/release-gate/zigeffect-release-gate.json`

The report names the release-gate command, included build steps, durable
workflow crash recovery proof, multi-runner cluster migration proof, and CI
artifact paths.

Add a single release command:

```bash
cd packages/zigeffect
zig build release-gate
```

The build step should depend on:

- `zig build test` via `test_step`;
- `zig build public-api-review`;
- `zig build storage-conformance`;
- `zig build property-crash`;
- `zig build performance-bounds`;
- `zig build examples`;
- `zig build causal-test`;
- the release-gate report tool and its tests.

Add root convenience:

```bash
bun run zigeffect:release
```

Update CI to run `zig build release-gate --summary none` and upload:

- `packages/zigeffect/.zig-cache/causal-artifacts/*.txt`
- `packages/zigeffect/.zig-cache/causal-artifacts/*.json`
- `packages/zigeffect/.zig-cache/causal-artifacts/*.dot`
- `packages/zigeffect/.zig-cache/release-gate/*.txt`
- `packages/zigeffect/.zig-cache/release-gate/*.json`

Add docs:

- README quickstart for the release gate;
- `packages/zigeffect/docs/migration-to-durable-runtime.md`;
- `docs/superpowers/reports/2026-06-10-zigeffect-milestone-46-completion.md`.

## Durable Crash Recovery Example

The example should expose a typed report:

- workflow id;
- execution id;
- committed event count;
- recovered partial byte count;
- final workflow status;
- whether the active segment no longer contains the partial row.

The test should assert:

- the recovered partial byte count is greater than zero;
- the final state remains `running`;
- committed events remain replayable;
- the partial row was removed from the segment.

## Release Report Tool

The text report should be readable in CI logs. The JSON report should be stable
enough for agents to parse. Both reports should include:

- schema name and version;
- release gate command;
- required build steps;
- acceptance proof labels;
- artifact paths;
- migration doc path;
- completion report path.

## Verification

The milestone gate is:

```bash
cd packages/zigeffect
zig build release-gate
cd ../..
bun run zigeffect:test
bun run zig:test
cd packages/zigeffect
zig build examples
zig fmt --check build.zig examples/workflow_crash_recovery.zig tools/release_gate_report.zig
cd ../..
git diff --check
```

The final marker scan should cover the new M46 files, edited README,
workflow file, build file, package.json, and roadmap checkboxes.

## Acceptance

Milestone 46 is accepted when the single release-gate command passes, the root
test wrappers still pass, examples pass, the crash recovery example passes, the
multi-runner cluster migration example passes, CI references the release-gate
artifact paths, README has a quickstart, migration notes exist, the completion
report exists, and the roadmap marks Milestone 46 complete.
