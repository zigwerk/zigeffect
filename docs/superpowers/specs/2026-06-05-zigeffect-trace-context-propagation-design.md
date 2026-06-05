# zigeffect Trace Context Propagation Design

## Goal

Propagate trace/span metadata through contexts created by regular runtimes,
fiber runtimes, and graph runtimes so effects can attach the active trace
context to logs or spans.

## Design

Add optional `trace_id` and `span_id` fields to `Context`. Runtimes carry the
same optional values and copy them into every context they construct.

Add `withTraceContext(trace_id, span_id)` to:

- `Runtime`
- `FiberRuntime`
- `LayerGraphRuntime`

`LayerGraphRuntime.context`, `runtime()`, `fiberRuntime()`, and startup builder
contexts propagate the graph trace context. Logger and tracing remain services;
runtime code only transports ids.

## Contract

- Trace context is metadata only. It does not start or end spans.
- Effects read `ctx.trace_id` and `ctx.span_id` when they need to attach
  metadata to service calls.
- Existing runtimes default to no active trace context.
- Fiber joins and graph runtime adapters preserve the metadata in their
  constructed contexts.

## Tests

Add tests that run effects through regular runtime, fiber runtime, and
graph-started runtime paths. Each effect logs through `Logger.logWithContext`
using `ctx.trace_id` and `ctx.span_id`, and the test asserts the structured log
entry preserves the ids.
