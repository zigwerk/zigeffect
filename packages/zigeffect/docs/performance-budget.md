# zigeffect Causal Performance Budget

`causal-performance-budget` is the deterministic operating-model report for
causal instrumentation overhead. It gives humans and agents one place to check
retention, string bounds, sampling posture, artifact limits, backend sink
posture, workbench direction, and release-review expectations before changing
the causal runtime.

It is not a wall-clock benchmark. The report is designed to be stable in local
development and CI.

## Command

```sh
cd packages/zigeffect
zig build causal-performance-budget
zig build causal-performance-budget -- --format json
```

The default text report is for human review. The JSON report uses schema
`zigeffect.causal.performance-budget.v1` and is the agent-readable contract.

## What The Budget Checks

Checked runtime constants:

- app request retention: `max_events=256`;
- app background-job retention: `max_events=1024`;
- app event string bound: `max_event_string_bytes=256`;
- workbench artifact read limit: `max_artifact_bytes=4194304`.

Documented operating budgets:

- plain `CausalStore` remains unbounded unless callers opt in to retention;
- sampling remains opt-in and limited to `log_recorded`, `metric_recorded`,
  and `span_recorded`;
- structural runtime events remain unsampled;
- CI uploads only causal `.txt`, `.json`, and `.dot` artifacts;
- CI artifact retention remains 14 days;
- backend adapters are sinks and must disclose failed writes without making the
  deterministic store unusable.

## How Agents Should Read It

Treat entries with `check=passed` as constants verified by the report. Treat
entries with `check=documented` as operating policy that must be backed by the
named docs, tests, or workflow before making a stronger claim.

When retention, sampling, truncation, or backend failure metadata says evidence
is incomplete, cite that limitation in diagnosis, remediation, release notes,
and workbench summaries.

Run the report before changing:

- causal store defaults;
- app-facing trace defaults;
- event redaction or truncation;
- sampling behavior;
- backend emission or failure handling;
- CI artifact upload rules;
- workbench artifact bounds or bridge behavior;
- causal schema families or compatibility posture.

## Release Notes Checklist

Add a causal runtime release-note entry whenever a change alters retained event
count, event string bounds, sampling behavior, backend emission, artifact
schema compatibility, workbench artifact bounds, workbench bridge behavior, CI
artifact upload globs, or CI artifact retention.

Use this verification set for broad causal-runtime changes:

```sh
cd packages/zigeffect
zig build causal-performance-budget
zig build causal-performance-budget -- --format json
zig build causal-schema-governance
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Workbench UI Direction

The workbench UI direction is SolidJS inside `webui-dev/zig-webui`: SolidJS
renders the interface, Bun/Vite builds it, and Zig plus `zig-webui` host the
native window or local server through a bounded read-only bridge.

React is not part of the current causal workbench direction. Add a React path
only when a concrete future adapter cannot fit the SolidJS plus `zig-webui`
boundary.

## Non-Goals

This budget report does not add:

- wall-clock latency gates;
- throughput benchmarks;
- production capacity planning;
- production dashboards;
- alerting or paging;
- live RBAC enforcement or encryption-at-rest implementation;
- source or config mutation authority;
- React workbench support;
- Cockroach adapter work.
