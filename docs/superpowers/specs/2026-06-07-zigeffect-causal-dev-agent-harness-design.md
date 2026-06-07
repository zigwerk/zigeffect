# zigeffect Causal Development Agent Harness Design

## Purpose

`zigeffect` now writes local causal development-loop verdict JSON artifacts.
Agents still have to manually decide which generated file to inspect next:
advice, query output, compare report, or the causal JSON itself.

This slice adds the first deterministic local development-agent harness:

```sh
zig build causal-dev-agent -- local [scenario]
```

The command reads the existing local dev-loop verdict artifact and prints a
small, text-first inspection plan. It does not run tests, mutate source, apply
fixes, call network services, or invent diagnoses. It makes the current
self-improvement loop easier to use by turning the verdict into an explicit
agent workflow.

## Current State

The local workflow is:

```sh
zig build causal-dev-loop -- baseline [scenario]
zig build causal-dev-loop -- after [scenario]
```

The after phase writes:

- before JSON;
- after JSON;
- compare report;
- query report;
- advice report;
- verdict JSON.

The verdict JSON has schema `zigeffect.causal.dev-loop-verdict.v1` and includes:

- aggregate `status`;
- aggregate `next_action`;
- aggregate action counts;
- one artifact entry with `json_path`, `baseline_path`, `advice_report_path`,
  `compare_report_path`, and per-artifact counts.

Agents should read the verdict first, but there is no command that turns that
machine-readable verdict into a deterministic local development handoff.

## Goals

- Add `zig build causal-dev-agent -- local [scenario]`.
- Read the default or scenario-specific local dev-loop verdict JSON.
- Validate the verdict schema before using it.
- Print an agent-readable plan that names:
  - target;
  - verdict path;
  - status;
  - next action;
  - aggregate counts;
  - artifact paths;
  - recommended inspection order;
  - exact follow-up commands.
- Derive the query report path from the after-artifact path using the same
  dev-loop naming convention.
- Fail cleanly when the verdict is missing, malformed, has an unsupported
  schema, or no artifact entry exists.

## Non-Goals

- No source edits or automatic remediation.
- No rerunning `causal-dev-loop`; the command only reads existing artifacts.
- No CI mode in this slice. CI already writes a text handoff; local
  self-improvement is the missing gap.
- No JSON output for the harness yet. The first consumer is an agent reading
  text in the terminal or saved logs.
- No semantic parsing of advice report bodies beyond verdict-provided action
  counts and paths.

## Command Shape

Default dogfood target:

```sh
zig build causal-dev-agent -- local
```

Scenario target:

```sh
zig build causal-dev-agent -- local causal-scoped-fiber
```

Usage errors should print:

```text
causal-dev-agent error: <error-name>
usage: zig build causal-dev-agent -- local [scenario]
```

Missing verdict should print a clean error. The executable uses usage-style
exit code `2`; when invoked through `zig build`, the outer build command reports
the failed step:

```text
causal-dev-agent error: MissingVerdictArtifact
usage: zig build causal-dev-agent -- local [scenario]
```

The command should not require package tests or examples to pass at invocation
time. It is an artifact reader, so the authoritative evidence is whatever the
previous dev-loop run wrote.

## Output Shape

For an attention verdict:

```text
zigeffect causal development agent
mode: local
target: dogfood
verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
status: attention
next_action: inspect-persisting-advice
actions: 4
new_actions: 0
persisting_actions: 4
observed_actions: 0

artifact 1:
json: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json
baseline: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json
compare report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt
query report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt
advice report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt
actions: 4
new_actions: 0
persisting_actions: 4
observed_actions: 0

recommended inspection order:
- read advice report first; prioritize status=persisting actions
- read query report for cited event ids
- read compare report before claiming behavior changed
- query JSON artifact for additional cause or lineage details

commands:
- zig build causal-advice -- --before .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json --file .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json
- zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json snapshot
- zig build causal-compare -- .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json
```

For a clear verdict:

```text
recommended inspection order:
- no advice actions; inspect compare report if the patch claims runtime behavior changed
- read query report only if a specific event id needs citation
- rerun package tests before finalizing
```

## Path Rules

Default verdict:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
```

Scenario verdict:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-verdict.json
```

The query report path is derived from each artifact `json_path`:

- `...-after.json` becomes `...-queries.txt`;
- any other `.json` becomes `...-queries.txt`.

The default and scenario after-artifact naming rules both satisfy the
`...-after.json` case.

## Data Model

Create a local parser type inside `tools/causal_dev_agent.zig`:

```zig
const DevAgentVerdict = struct {
    schema: []const u8,
    schema_version: u32,
    status: []const u8,
    next_action: []const u8,
    json_artifacts: usize,
    baseline_pairs: usize,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    observed_actions: usize,
    artifacts: []Artifact,
};

const Artifact = struct {
    json_path: []const u8,
    baseline_path: ?[]const u8,
    advice_report_path: []const u8,
    compare_report_path: ?[]const u8,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    observed_actions: usize,
};
```

The parsed string slices are owned by the `std.json.parseFromSlice` arena.
Formatting functions may borrow them until the parsed object is deinitialized.

## Architecture

Create one new tool:

```text
packages/zigeffect/tools/causal_dev_agent.zig
```

Responsibilities:

- parse CLI args;
- derive verdict path;
- read verdict file;
- parse and validate verdict JSON;
- derive query report path for artifact entries;
- format an agent-readable inspection plan.

Modify `packages/zigeffect/build.zig` to add:

- `causal_dev_agent_tool_module`;
- executable `zigeffect-causal-dev-agent`;
- build step `causal-dev-agent`;
- tool tests included in `zig build examples`;
- import `causal_run` so scenario names can be validated and artifact dir
  stays centralized.

No existing causal runtime module needs to change.

## Error Handling

The executable should convert these conditions to usage-style exit code `2`.
When invoked through `zig build`, the outer build process reports the failed
step while preserving the tool's error text:

- missing mode;
- unknown mode;
- too many args;
- unknown scenario;
- missing verdict artifact;
- unsupported verdict schema;
- empty verdict artifact list;
- invalid verdict artifact path while deriving query report path.

Allocator or IO errors other than missing verdict should be returned normally.

## Testing

Unit tests in `causal_dev_agent.zig` should cover:

- default local verdict path;
- scenario local verdict path;
- query report path derivation from `-after.json`;
- unsupported schema validation;
- empty artifact list validation;
- report text for attention verdict;
- report text for clear verdict.

Integration verification should cover:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
zig build causal-dev-agent -- local
```

And scenario mode:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
zig build causal-dev-agent -- local causal-scoped-fiber
```

Both outputs should include `recommended inspection order` and the matching
verdict path.

## Documentation

Update:

- `packages/zigeffect/docs/agent-guide.md`;
- `packages/zigeffect/docs/causal-scenarios.md`;
- `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`;
- `packages/zigeffect/docs/roadmap.md`.

The docs should state that after running the after phase, agents can run
`zig build causal-dev-agent -- local [scenario]` to get the deterministic local
inspection plan.

## Exit Criteria

- `zig build causal-dev-agent -- local [scenario]` reads existing local verdicts
  and prints a deterministic inspection plan.
- Missing or invalid verdicts fail cleanly with usage text.
- `zig build examples` covers the new tool tests.
- The default and scenario dev-loop verification commands pass.
- `bun run zig:test` passes from the repository root.
