# zigeffect Observability Reporting Design

Date: 2026-06-05

## Goal

Add a stable operations-style report for the existing logger, metrics, and
tracing services.

## Design

Create `packages/zigeffect/src/services/observability.zig` with:

```zig
formatObservabilityReport(
    allocator,
    label,
    logger,
    metrics,
    tracing,
)
```

The report includes:

- program label
- structured log count and entries
- metric counter and histogram snapshots
- trace event and span summaries

The formatter reads existing service state; it does not change logger, metrics,
or tracing storage semantics. It is suitable for deterministic tests, CLI
diagnostics, and agent-readable reports.

## Non-Goals

- Do not add exporters, network sinks, or OpenTelemetry wiring.
- Do not change service capture behavior.
- Do not introduce runtime-global observability state.

## Tests

Add a services test that records one structured log, counter, histogram, and
span tree, then asserts the formatted report includes each section and key
values.
