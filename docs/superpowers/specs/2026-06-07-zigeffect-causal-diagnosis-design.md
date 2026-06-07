# zigeffect Causal Diagnosis Design

## Purpose

`zigeffect` now uses its own causal runtime to produce local development-loop
artifacts, verdicts, and deterministic agent inspection plans. The remaining
Milestone 7 gap is richer automation that summarizes selected advice and query
evidence into a patch-ready diagnosis.

This slice adds a deterministic, non-mutating diagnosis layer:

```sh
zig build causal-diagnosis -- local [scenario]
```

The command reads the existing dev-loop verdict, advice report, query report,
and compare report. It then writes and prints a concise diagnosis artifact that
groups evidence by action, cites event ids, names the likely subsystem and fix
category, and tells the agent what kind of patch or test to propose.

It does not generate source patches, edit files, call an LLM, or approve
remediation. It gives a development agent a better starting brief.

## Current State

The current self-improvement lane is:

```sh
zig build causal-dev-loop -- baseline [scenario]
zig build causal-dev-loop -- after [scenario]
zig build causal-dev-agent -- local [scenario]
```

The after phase writes:

- `*-before.json`;
- `*-after.json`;
- `*-compare.txt`;
- `*-queries.txt`;
- `*-advice.txt`;
- `*-verdict.json`.

`causal-dev-agent` reads the verdict and prints an inspection order plus exact
follow-up commands. Agents still need to manually open the advice/query/compare
reports and turn those facts into a diagnosis.

## Design Alternatives

### Option A: Extend `causal_advice.zig`

`causal_advice` already maps causal events to deterministic actions.

Trade-off: extending it would blur two responsibilities. Advice should stay a
small action selector that can run on a single artifact. Diagnosis needs the
whole dev-loop bundle: verdict, advice, query output, compare output, and
before/after status.

### Option B: Extend `causal_dev_agent.zig`

`causal_dev_agent` already reads verdicts and knows the local artifact naming
rules.

Trade-off: it would make the dev-agent handoff tool too broad. The handoff
should remain the first-read router; diagnosis is the second step after a user
or agent wants a patch-ready brief.

### Option C: Add `causal_diagnosis.zig`

Create a focused artifact synthesizer that reads the existing local bundle and
outputs a deterministic diagnosis report.

This is the recommended path. It keeps advice, verdict, dev-agent handoff, and
diagnosis separate, while letting diagnosis reuse the same local path rules and
action vocabulary.

## Command Shape

Default dogfood target:

```sh
zig build causal-diagnosis -- local
```

Scenario target:

```sh
zig build causal-diagnosis -- local causal-scoped-fiber
```

The command should read the matching local dev-loop verdict and artifact paths.
It should write and print:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-diagnosis.txt
```

Usage errors should print:

```text
causal-diagnosis error: <error-name>
usage: zig build causal-diagnosis -- local [scenario]
```

The executable uses usage-style exit code `2` for missing or invalid local
diagnosis inputs. When invoked through `zig build`, the outer build process
reports a failed step while preserving the tool's error text.

## Diagnosis Report Shape

Example attention report:

```text
zigeffect causal diagnosis
mode: local
target: dogfood
diagnosis: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
status: attention
next_action: inspect-persisting-advice
actions: 4
new_actions: 0
persisting_actions: 4
observed_actions: 0

summary:
- diagnosis status: attention
- dominant evidence: persisting
- patch posture: existing causal findings remain; do not claim this patch fixed them
- compare posture: no before/after event or finding delta

evidence:
- action provide-missing-service status=persisting event=3 kind=service_required label=Config
  subsystem: service_resolution
  fix category: code-or-layer-provider
  diagnosis: a required service has no matching provider in the captured run
  patch prompt: inspect service requirements and provider declarations; add or wire the missing provider if this is not an intentional fixture
  citations: event=3 advice=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt query=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt

next patch brief:
- cite event ids from the evidence section
- explain whether evidence is new, persisting, or observed
- use the compare posture before claiming behavior changed
- propose code, config, layer, test, or scenario-registry changes only
```

Example clear report:

```text
summary:
- diagnosis status: clear
- dominant evidence: none
- patch posture: no advice actions were selected from the after artifact
- compare posture: inspect compare report before claiming behavior changed

evidence:
- no causal advice actions selected
```

## Input Artifacts

Diagnosis reads these existing files:

- verdict JSON from `causal-dev-loop -- after`;
- advice report from the verdict artifact entry;
- query report derived from the after JSON path;
- compare report from the verdict artifact entry when present.

It does not rerun `causal-query`, `causal-advice`, `causal-compare`, package
tests, or scenarios. The diagnosis is a deterministic summary of the already
captured bundle.

## Parsing Rules

### Verdict

Parse the same schema used by `causal_dev_agent.zig`:

```text
zigeffect.causal.dev-loop-verdict.v1
```

Reject missing verdicts, unsupported schema versions, empty artifact lists, or
invalid artifact paths.

### Advice

Parse action lines:

```text
- action <action> status=<status> event=<id> kind=<kind> label=<label>
```

The parser should capture:

- action name;
- status;
- event id;
- event kind;
- optional label.

Unknown actions should still appear in the report with subsystem `unknown` and
fix category `inspect-evidence`.

### Query Report

The first slice should not deeply parse causal query bodies. It should verify
that the query report exists, count `query:` lines, and cite the report path.
Future slices can attach selected query excerpts per event id.

### Compare Report

The first slice should parse high-signal lines if present:

- `event delta:`;
- `finding delta:`;
- `added events:`;
- `removed events:`;
- `changed events:`.

The diagnosis should state whether compare output shows no delta, improvement,
regression, or unknown.

## Action Mapping

Use the existing advice action vocabulary:

- `provide-missing-service`
  - subsystem: `service_resolution`
  - fix category: `code-or-layer-provider`
  - diagnosis: required service has no matching provider
- `close-resource`
  - subsystem: `scope_lifecycle`
  - fix category: `resource-finalizer`
  - diagnosis: acquired resource lacks matching finalization evidence
- `resolve-scoped-fiber`
  - subsystem: `fiber_runtime`
  - fix category: `structured-concurrency`
  - diagnosis: scoped fiber remains active in captured evidence
- `inspect-retry-exhaustion`
  - subsystem: `schedule_retry`
  - fix category: `retry-policy-or-failure-specificity`
  - diagnosis: retry schedule exhausted its budget
- `inspect-command-failure`
  - subsystem: `development_command`
  - fix category: `test-or-command-failure`
  - diagnosis: development command recorded a failed assertion
- `inspect-finalizer-failure`
  - subsystem: `scope_lifecycle`
  - fix category: `finalizer-error-handling`
  - diagnosis: cleanup finalizer failed

## Status Semantics

The diagnosis should preserve before-aware advice status:

- `new`: prioritize as a possible regression introduced by the current patch;
- `persisting`: existing evidence remained across before/after; do not claim
  it was fixed by the current patch;
- `observed`: evidence exists without a baseline comparison;
- no actions: diagnosis is clear for selected advice actions.

Dominant evidence order:

1. `new`;
2. `observed`;
3. `persisting`;
4. `none`.

## Architecture

Create one new tool:

```text
packages/zigeffect/tools/causal_diagnosis.zig
```

Responsibilities:

- parse CLI args;
- validate optional scenario names with `causal_run.scenarioByName`;
- derive local verdict and diagnosis paths;
- parse verdict JSON;
- read advice/query/compare reports;
- parse advice action lines;
- summarize compare posture;
- format and write a diagnosis report.

Modify `packages/zigeffect/build.zig` to add:

- `causal_diagnosis_tool_module`;
- executable `zigeffect-causal-diagnosis`;
- build step `causal-diagnosis`;
- tool tests included in `zig build examples`;
- import `causal_run`.

The first implementation can duplicate the small verdict parser from
`causal_dev_agent.zig`. A later cleanup can extract shared local artifact path
helpers if a third tool needs them.

## Safety

- Non-mutating by default and by design.
- No patch generation.
- No network calls.
- No LLM calls.
- No secret expansion beyond already-redacted causal artifacts.
- All claims must cite report paths and event ids where available.

## Testing

Unit tests should cover:

- default and scenario diagnosis paths;
- advice action line parsing;
- unknown action mapping;
- dominant evidence selection;
- compare posture parsing for no delta and regression;
- attention report formatting;
- clear report formatting;
- missing advice/query/compare file failure mapping where practical.

Integration verification should cover:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
zig build causal-diagnosis -- local
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
```

And scenario mode:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
zig build causal-diagnosis -- local causal-scoped-fiber
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt
```

## Documentation

Update:

- `packages/zigeffect/docs/agent-guide.md`;
- `packages/zigeffect/docs/causal-scenarios.md`;
- `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`;
- `packages/zigeffect/docs/roadmap.md`.

Docs should place diagnosis after `causal-dev-agent`:

```sh
zig build causal-dev-agent -- local [scenario]
zig build causal-diagnosis -- local [scenario]
```

## Exit Criteria

- `zig build causal-diagnosis -- local [scenario]` reads existing local
  dev-loop artifacts and writes a deterministic diagnosis report.
- The report includes status, dominant evidence, compare posture, action-level
  diagnosis, fix category, and event citations.
- Missing or invalid inputs fail cleanly with usage text.
- `zig build examples` covers the new tool tests.
- Default and scenario integration checks pass.
- `bun run zig:test` passes from the repository root.
