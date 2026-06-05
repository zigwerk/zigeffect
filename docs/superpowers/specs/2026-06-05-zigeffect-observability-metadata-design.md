# zigeffect Observability Metadata Design

## Goal

Harden logger and tracing services so structured records can carry the metadata
production systems need: timestamps, trace ids, span ids, and attributes.

## Chosen Approach

Keep metadata in the observability services. Runtime propagation remains future
work; this slice gives services stable data shapes and APIs that future runtime
integration can use.

## Contract

- Logger keeps the existing plain `entries` list for simple tests.
- Structured `LogEntry` gains optional `timestamp_ms`, `trace_id`, and
  `span_id`.
- `Logger.logWithContext` records level, message, fields, and optional metadata.
- `Logger.logFields` and `Logger.log` remain compatible and record metadata as
  null.
- Tracing spans get `trace_id` and owned attributes.
- Root spans allocate a new trace id. Child spans inherit the parent trace id.
- `Tracing.startSpanWithAttributes` records attributes and preserves the
  existing span start/end event stream.

## Tests

- Structured logs preserve timestamp, trace id, span id, and fields.
- Root and child spans share a trace id.
- Span attributes are copied and released by tracing deinit.
