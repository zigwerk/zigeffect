# zigeffect Span Lifecycle Checks Design

## Goal

Make tracing spans easier to inspect in deterministic tests by adding span
lookup and lifecycle assertions.

## Design

Add lightweight query helpers to `Tracing`:

- `span(id)`
- `spanEnded(id)`
- `spanParent(id)`
- `spanTrace(id)`

Add `TestEnv` assertions:

- `expectSpanEnded(id)`
- `expectSpanParent(child, parent)`
- `expectSpanTrace(id, trace_id)`

The tracing service remains an in-memory deterministic service. The helpers do
not create or end spans; they only inspect state already recorded by
`startSpan*` and `endSpan`.

## Tests

Add service tests that start a root span and child span, end the child, and
assert ended state, parent relationship, and shared trace id through `TestEnv`.
