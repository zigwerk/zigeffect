# Changelog

## Unreleased

- Added the canonical `kernel.Service`, fluent `kernel.Effect`, composable
  `kernel.Layer`, and single process-level `zstd.ManagedRuntime` application
  architecture over the I/O-free kernel interpreter.
- Added runtime defaults/aspects, semantic causal parents, bounded application
  inspection, and the compile-checked multi-endpoint reference server.
- Packed retained causal event text into one owned allocation and excluded
  internal storage from public JSON.
- Added the runtime-owned embedded NenDB topology, durable property WAL,
  checked shutdown, application map, and ordered before/after graph queries.
- Migrated local application and service roots plus composable library layers
  to template v10; the production adapter bridge remains explicit migration
  debt.
- Reorganized public documentation around one canonical application model and
  marked environment/layer-graph examples as compatibility or migration
  material.

## 0.1.0 production-candidate platform — 2026-07-11

- Added executable capability maturity, profile resolution, content-addressed
  conformance receipts, and production manifest enforcement.
- Added classified external failures, application lifecycle and signal handling,
  effectful streams, layered configuration, real clock/CSPRNG/IDs, secret
  providers, resilience, security, Schema projection/generation/shrinking, and
  cache/broker/object/outbox boundary contracts.
- Added real HTTP/OpenSSL, native libpq Postgres/Cockroach, SQL durable storage,
  TLS process transport, OTLP HTTP, Redis, and S3-compatible adapter packages.
- Added the independent-process reference orders system, provider fault matrix,
  normalized model/live differential, load/soak gates, operations contracts,
  complete CI matrix, and immutable production evidence registry.
- Corrected the legacy `ProductionHttpClusterTransport` and
  `ProductionSocketClusterTransport` posture. They remain deprecated aliases of
  explicitly in-process model adapters; use `zigeffect-transport` for real
  network transport.

Compatibility: Zig 0.16.0. Adapter maturity is capability-specific and follows
the checked-in descriptor, receipt, and limitations. No adapter is implied to
be `production_verified` by inclusion in this release. See
`zigeffect-reference-system/docs/release.md` for the platform matrix and
upgrade/rollback contract.
