# zigeffect-storage-postgres

PostgreSQL/CockroachDB-backed durable implementations of ZigEffect workflow
journals, cluster messages, fenced runner leases, checkpoints, and transactional
outbox/inbox primitives.

The package uses the native `zigeffect-postgres-libpq` adapter. Table names are
generated only from a validated identifier prefix; application values are always
passed as bound parameters.

The workflow-journal, message-storage, and lease-storage descriptors are
`production_candidate`. That status is backed by the checked-in live external
receipt in `conformance/storage-restart-live.v1.json`; it is not a blanket
production guarantee. The adapter requires a compatible system `libpq`, and
multi-region failover remains the database provider's responsibility.

Run unit tests with `zig build test`, and run the disposable-database lanes
through the scripts under `tests/` before promoting a deployment.
