# Changelog

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

Compatibility: Zig 0.16.0. All production adapters remain
`production_candidate`; their checked-in receipts and limitations define the
supported claim. See `zigeffect-reference-system/docs/release.md` for the
platform matrix and upgrade/rollback contract.
