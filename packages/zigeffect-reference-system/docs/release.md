# Reference Orders Release Contract

The reference system is versioned with semantic versions and requires Zig
0.16.0, a compatible system libpq, OpenSSL 3, Postgres 17/18 or CockroachDB
26.2, Redis 8, and an S3-compatible service. The checked-in conformance receipt
and its SHA-256 digest are the release authority; package names or documentation
alone are not.

This system currently uses the generated production compatibility bridge for
HTTP, Postgres, and OTLP. Its receipts qualify the recorded platform behavior;
they do not qualify that legacy wiring as the canonical ZigEffect application
architecture. Composition promotion additionally requires those adapters to
publish canonical kernel layers and the reference system to use one
`fx.kernel.ManagedRuntime` root.

Supported evidence matrix:

| Target | Unit and ReleaseSafe | Live adapters | Process topology |
| --- | --- | --- | --- |
| macOS arm64 | required | required | required |
| Linux x86_64 | required in CI | required in CI | required in CI |

Before a version is tagged, run the production workflow, generated-scaffold
matrix, Workbench checks, evidence digest gate, bounded load, restart drills,
and clean-snapshot release script. Update the changelog with API, migration,
capability, limitation, and operational changes. An upgrade must validate the
manifest before applying migrations; a rollback follows the expand/contract
procedure in `docs/operations.md`.

No claim beyond `production_candidate` is made. HTTP/2, Redis Cluster, direct
S3 endpoint TLS, OTLP/gRPC, and framework-operated multi-region database
failover remain explicit limitations. The ThreadSanitizer gate executes on
Linux CI; Zig/LLVM 0.16's TSan runtime terminates before `main` on macOS arm64,
where the same gate is compile-verified instead.
