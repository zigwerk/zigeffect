# zigeffect-postgres-libpq

Persistent native PostgreSQL adapter for ZigEffect using the reviewed system
`libpq` protocol implementation. It never interpolates bind values into SQL.
The driver capability is `production_candidate` on the checked-in,
content-bound PostgreSQL/CockroachDB live conformance receipt. It is not
`production_verified`; deployment qualification still depends on the selected
system libpq build, target database, credentials, network, and operational
bounds.

`SessionLayerConfig`, `PoolLayerConfig`, `sessionLayer()`, and `poolLayer()` are
the current compatibility bridge. Their scope owns connections and pool
shutdown, while `applyMigrationsEffect` and `closePoolEffect` emit redacted
causal operation facts. They still use the legacy environment-shaped layer
kernel and are not a template for new application roots.

The canonical migration will publish stable session/pool tags and scoped
`fx.kernel.Layer` values. Direct `Session.init` and `Pool.initAlloc` remain
imperative driver APIs for focused adapter code.
