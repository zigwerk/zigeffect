# ZigEffect Runtime Introspection Implementation Plan

Date: 2026-07-15
Design: `docs/superpowers/specs/2026-07-15-zigeffect-runtime-introspection-design.md`

1. Add failing canonical-kernel tests for default causal recording, complete
   service/layer topology, dependency edges, memoized reuse, bounded snapshots,
   JSON output, and unified scope/resource aspect delivery.
2. Add a kernel-owned topology catalog populated by leaf layer construction and
   finalized against root outputs by `ManagedRuntime`.
3. Add a concurrency-safe combined causal inspection that clones one bounded
   event tail, findings, fiber states, and health counters under one lock.
4. Make `ManagedRuntime` create and own a bounded causal store by default while
   preserving explicit caller-owned stores.
5. Route canonical scope/resource lifecycle through the runtime aspect pipeline.
6. Add `ApplicationSnapshot`, JSON formatting, and `inspect` / `inspectJson` to
   managed runtimes and reusable runtime handles.
7. Add a reference-server introspection request that uses the existing managed
   runtime rather than rebuilding layers.
8. Run the focused canonical tests, full ZigEffect suite, public API review,
   Testing v2 migration guard, and inspect every generated Testing v2 receipt.
9. Record follow-on package/test migrations in the architecture review without
   introducing another causal report tool or parallel schema.
10. Add a guarded, size-bounded HTTP application-map handler that serializes the
    runtime snapshot directly and prove allow/deny behavior with Testing v2.
