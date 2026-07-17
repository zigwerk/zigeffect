# ZigEffect Typed Data Lineage Implementation Plan

1. Add failing core tests for typed reference determinism, privacy rejection,
   scoped multi-key attachment, structural event enrichment, child-handle
   inheritance, raw-value absence, and OTEL filtering.
2. Implement the allocation-free lineage key/reference/set model and export it
   through ZigEffect and `zigeffect_std`.
3. Add `.track(Key, value)` to the canonical effect fluent API, emit the
   runtime-owned `lineage_bound` event, and carry causal context through every
   structural runtime event.
4. Add in-memory reference filtering plus a bounded paginated durable NenDB
   lineage query and advertise it in the managed runtime agent map.
5. Add bounded opaque W3C baggage formatting/parsing, standard gRPC client
   injection, and generated server runtime-context propagation with focused
   tests.
6. Document the developer contract and agent query loop, update public API
   stability checks, and keep generated application guidance synchronized.
7. Run package-native ZigEffect, standard-library, gRPC, architecture, Testing
   v2 migration, formatting, diff, and receipt gates; commit only this work and
   preserve concurrent zgraph/parser changes.
