# zigeffect-postgres-libpq

Persistent native PostgreSQL adapter for ZigEffect using the reviewed system
`libpq` protocol implementation. It never interpolates bind values into SQL.
The driver capability is `production_candidate` on the checked-in,
content-bound PostgreSQL/CockroachDB live conformance receipt. It is not
`production_verified`; deployment qualification still depends on the selected
system libpq build, target database, credentials, network, and operational
bounds.

`SessionLayerConfig`, `PoolLayerConfig`, `sessionLayer()`, and `poolLayer()` are
the canonical adapter surface. Stable session and pool service tags compose as
scoped `fx.kernel.Layer` values; their scopes own connections and pool shutdown.
`applyMigrationsEffect` and `closePoolEffect` emit redacted semantic causal
facts. Direct `Session.init` and `Pool.initAlloc` remain imperative driver APIs
for focused adapter and conformance code, not application composition roots.
