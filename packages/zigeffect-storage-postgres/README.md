# zigeffect-storage-postgres

PostgreSQL/CockroachDB-backed durable implementations of ZigEffect workflow
journals, cluster messages, fenced runner leases, checkpoints, and transactional
outbox/inbox primitives.

The package uses the native `zigeffect-postgres-libpq` adapter. Table names are
generated only from a validated identifier prefix; application values are always
passed as bound parameters.

The capability remains `local_development` until restart/failover and sustained
concurrency lanes are complete. Run unit tests with `zig build test`, and the
required disposable-database lane through the scripts under `tests/`.
