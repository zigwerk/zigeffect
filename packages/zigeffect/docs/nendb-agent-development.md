# NenDB-backed agent development

Every canonical ZigEffect application owns one embedded NenDB causal graph
through `zstd.ManagedRuntime`. There is no daemon, Docker container, optional
export step, or application-owned graph wiring. The runtime records structural
engine events and redacted semantic application facts into the same graph while
it executes.

## What is stored

NenDB's allocator-owned struct-of-arrays engine holds the hot node and
parent-edge topology. The crash-safe JSONL WAL holds each node's complete
bounded properties and is the recovery source for the embedded engine. Runtime
health reports the exact upstream revision used by the Zig 0.16 port, engine
counts, failed writes, retention, sampling, and truncation.

The in-memory `CausalStore` retains a bounded recent window for live
inspection. Durable NenDB recording is independent of that window: every event
offered to a healthy application runtime is persisted until the configured
graph or WAL bound is reached. Crossing a bound degrades causal health and
makes checked runtime shutdown fail.

## One discovery query

`runtime.agentMapJsonAlloc` returns
`zigeffect.agent.application-map.v5`. A guarded
`zigeffect-http.ApplicationMapHandler` exposes the same document without
creating another model. It contains:

- root layer topology, services, dependencies, operations, and memoized reuse;
- lifecycle, unresolved fibers, findings, and bounded recent semantic events;
- embedded NenDB summary and exact engine provenance;
- durable-write health and incomplete-evidence counters; and
- the supported `since`, event, child, path and typed-lineage query vocabulary
  plus ID spaces.

The route must be authenticated and response-bounded. It must not expose raw
payloads, credentials, personal data, or an arbitrary graph filesystem path.

## Before-and-after development loop

1. Validate the manifest and read the guarded application map when the
   application is running.
2. Run `zigeffect graph status --json` and retain
   `newest_durable_event_id` as the baseline.
3. State a counterfactual from the requirement, scope, service topology, and
   current graph: which services, boundaries, facts, and descendants should
   appear after the change, and which graph slices must remain unchanged.
4. Add the failing deterministic acceptance scenario, then run the smallest
   manifest-owned affected test.
5. Read the Testing v2 receipt and query:

   ```sh
   zigeffect graph since <baseline-event-id> --limit 256 --json
   zigeffect graph event <durable-event-id> --json
   zigeffect graph children <durable-event-id> --json
   ```

   For an authorized domain-value lookup, derive its opaque typed reference
   inside the application with `runtime.lineageReference(Key, value)`, then page
   `runtime.graphLineageJsonAlloc`. Continue from `next_after_event_id` whenever
   the result is truncated; raw identity values never enter the query result.

   Assertion IDs are directly queryable only when the receipt declares
   `causal_event_id_space: "graph_durable"` and a non-zero
   `causal_graph_session_id`. Canonical generated acceptance tests establish
   that identity by sharing the `TestContext` store with the one managed
   runtime and mapping IDs before shutdown.

6. Compare the ordered delta with the counterfactual and acceptance contract.
   If `truncated` is true, continue from `next_event_id`. Missing, dropped,
   unhealthy, unexpectedly broad, or unread evidence is not a pass.
7. Hand off the requirement receipt, replay command, baseline and final graph
   cursors, and relevant durable event IDs.

This workflow lets an agent plan from the actual composed application, test a
bounded hypothesis, and inspect what the runtime caused instead of inferring
execution from source layout or terminal logs.

## Ownership and implementation reference

The official upstream source is pinned at
`packages/references/nen-db`. Production packages never import that checkout.
The reviewed port and its license/provenance live under
`packages/zigeffect-std/src/vendor/nendb`; the standard-library runtime owns its
lifecycle and durable WAL.

`fx.kernel.ManagedRuntime` remains intentionally I/O-free and therefore owns
only its bounded memory recorder. Use it directly only for framework tests or a
deliberate custom platform integration. Applications, APIs, servers, workers,
jobs, and generated projects use `zstd.ManagedRuntime`.
