# zigeffect Observability Services Design

Date: 2026-06-05

## Goal

Deliver a focused roadmap section 10 slice that makes logger, metrics, and
tracing more credible while preserving existing deterministic test APIs.

## Contracts

- Logger keeps plain `entries` for compatibility and also records structured
  entries with level, message, and optional fields.
- Metrics keeps counters/gauges and adds histograms plus snapshot objects that
  tests can inspect deterministically.
- Tracing keeps plain event strings and adds span records with ids, parent ids,
  names, and ended status.

## Non-Goals

- No timestamps yet.
- No trace/span propagation across runtimes yet.
- No OpenTelemetry export format yet.
- No metric tags yet.

## Tests

- Structured logger entries preserve level and fields.
- Metrics histograms capture count, sum, min, max and appear in snapshots.
- Tracing spans assign stable ids, parent ids, and ended status.
