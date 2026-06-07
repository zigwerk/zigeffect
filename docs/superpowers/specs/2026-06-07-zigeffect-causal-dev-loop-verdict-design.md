# zigeffect Causal Dev Loop Verdict Design

## Purpose

`zigeffect` now emits a structured CI verdict, but local development still asks
agents to read the after-phase advice report first. The self-improving
development loop should give local agents the same first-read artifact that CI
does.

This slice adds a local development verdict artifact written by
`zig build causal-dev-loop -- after [scenario]`.

## Current State

The local development loop already writes, after a baseline phase:

- before JSON;
- after JSON;
- compare report;
- executed query report;
- baseline-aware advice report;
- printed summary with artifact paths.

CI handoff separately writes:

- generated advice reports;
- generated compare reports for paired artifacts;
- `zigeffect-causal-ci-handoff.txt`;
- `zigeffect-causal-ci-verdict.json`.

The verdict formatter currently lives inside `tools/causal_handoff.zig`. Local
development should not duplicate that logic.

## Design

Create a shared tool module:

```text
packages/zigeffect/tools/causal_verdict.zig
```

It owns:

- `ArtifactVerdictInput`;
- action counting from advice report text;
- JSON string escaping;
- `formatVerdictJson`;
- tests for clear, observed, persisting, new, and escaped strings.

CI handoff imports this module and keeps its existing JSON shape:

```json
{
  "schema": "zigeffect.causal.ci-verdict.v1",
  "schema_version": 1,
  "status": "attention",
  "next_action": "inspect-observed-advice",
  "json_artifacts": 1,
  "baseline_pairs": 0,
  "actions": 4
}
```

The development loop imports the same module and writes:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-verdict.json
```

with schema:

```text
zigeffect.causal.dev-loop-verdict.v1
```

The local verdict should summarize the single after artifact for the selected
target. It should include before, after, advice, and compare paths through the
same `ArtifactVerdictInput` fields.

## Local Artifact Paths

Default dogfood loop:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
```

Scenario loop:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-verdict.json
```

The `causal-dev-loop -- after` summary should print:

```text
verdict: <path>
next: inspect verdict
```

The current advice, query, and compare paths should remain unchanged.

## Scope

This slice does not add automatic remediation, source-code edits, or severity
ranking. It makes the local loop self-explaining and keeps CI and local verdict
formatting consistent.

## Exit Criteria

- `causal_handoff.zig` uses shared `causal_verdict.zig`.
- `causal-dev-loop -- after` writes the local verdict JSON.
- The local summary prints the verdict path and says to inspect it first.
- `zig build causal-artifacts` lists default and scenario verdict artifacts.
- Agent docs explain that local agents should read the dev-loop verdict first.
- `zig build examples`, `zig build test --summary none`, `bun run zig:test`,
  and `git diff --check` pass.
