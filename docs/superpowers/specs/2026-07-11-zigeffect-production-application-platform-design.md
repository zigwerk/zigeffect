# ZigEffect Production Application And Multi-Service Platform Design

Date: 2026-07-11

Status: accepted implementation direction

Supersedes production-readiness claims in earlier local-first milestones where
the delivered implementation was a fake, deterministic model, local subprocess,
file store, encoded in-process boundary, or localhost-only adapter.

## Goal

Make ZigEffect sufficient for coding agents and humans to build, verify, deploy,
and operate real backend services and multi-service systems without inventing
the final application architecture or silently substituting local evidence for
production evidence.

The completed platform must preserve ZigEffect's deterministic engine and causal
evidence model while adding real, separately packaged production adapters. A
generated system must be able to listen for network traffic, execute safely
bound database queries, persist workflow and cluster state outside one process,
communicate across authenticated TLS connections, export telemetry, recover
after crashes, and prove those behaviors through the same manifest-owned tests
used by agents.

## Problem Statement

ZigEffect's core runtime, causal graph, workflow/statechart implementation, and
agent protocol are substantially more mature than its deployed application
boundaries. Earlier roadmaps intentionally delivered local-first seams:

- the HTTP milestone delivered a typed router and memory server, not a socket
  listener;
- the Postgres milestone explicitly excluded a wire driver and live database CI;
- the production cluster transports serialized production-shaped bytes but
  routed them through an in-process handler;
- durable workflow, message, and runner stores ship memory and local-file
  implementations but no shared database implementation;
- generated application and system scaffolds invoke a router directly and use a
  fake database;
- advanced distributed testing models do not automatically drive the concrete
  production adapters; and
- the repository's main CI workflow does not cover all ZigEffect packages or a
  live multi-service reference system.

Those outcomes remain useful development adapters and compatibility models. The
problem is that their names, roadmap status, and generated acceptance evidence
can be mistaken for production capability.

## Governing Principles

1. **No maturity ambiguity.** Every external adapter declares what kind of
   evidence it can earn. A fake can never satisfy a production requirement.
2. **Contracts stay in std; integrations stay optional.** `zigeffect-std` owns
   portable contracts and deterministic providers. Network/database/cloud
   integrations live in adapter packages.
3. **One program across fake and real providers.** Application behavior imports
   public std contracts. Tests and deployments swap layers, not domain code.
4. **Live conformance is mandatory.** A production-candidate adapter must pass
   its contract against the real external system in CI or a declared release
   environment.
5. **Distributed claims require separate processes.** Encoding and decoding in
   one process is compatibility evidence, not network evidence.
6. **Typed recovery survives adapter erasure.** Public application failures use
   stable classifications; backend-specific details remain redacted evidence.
7. **Receipts name the execution profile.** Every acceptance receipt records the
   adapter identities, maturity levels, target, platform, and real/fake authority.
8. **The reference system is the release oracle.** Production readiness is not
   inferred from isolated modules; it is earned by the golden-path system.

## Capability Maturity Model

Add an application-facing capability contract under `zstd.Capability`.

### Levels

- `fake`: deterministic canned behavior; never contacts an external system.
- `deterministic_model`: executes a bounded semantic model or virtual world.
- `local_development`: contacts a real local dependency or process but lacks the
  complete production lifecycle or conformance record.
- `production_candidate`: implements the production protocol and passes live
  conformance, recovery, redaction, and bounded-load checks.
- `production_verified`: additionally passes the repository release matrix on
  every supported platform and the reference-system operational gates.

Maturity is ordered, but matching also requires a capability kind. A verified
HTTP client does not satisfy a verified HTTP server requirement.

### Descriptor

Each adapter exposes a descriptor containing:

- stable adapter id and capability kind;
- maturity level;
- implementation package and semantic version;
- supported feature flags;
- deterministic and real side-effect posture;
- conformance suite/schema version;
- supported targets/platforms;
- known limitations; and
- an optional receipt/artifact reference.

Descriptors must be bounded, redacted, schema-versioned, and deterministic when
serialized. Credentials, connection strings, and host-local absolute paths are
forbidden.

### Manifest And Receipt Enforcement

`zigeffect.project.json` gains production requirements without breaking current
manifests. A component may require, for example, an `http_server` and
`postgres_database` at `production_candidate` or above. Project validation
rejects unknown capability kinds and maturity values. Test and project receipts
record resolved adapters. A required check is incomplete when:

- no adapter resolves;
- the adapter maturity is below the requirement;
- live conformance is required but missing or stale;
- the target/platform is unsupported; or
- evidence was truncated or produced under a different adapter profile.

## Package Architecture

### Core: `packages/zigeffect`

The core remains deterministic-by-default and owns:

- effect/runtime/layer/scope contracts;
- classified external failure and cancellation semantics;
- effectful stream machinery that depends only on runtime capabilities;
- durable workflow/statechart and cluster contracts;
- backend capability diagnostics; and
- causal facts required to relate production adapter operations.

The core does not embed Postgres, TLS certificates, cloud SDKs, or deployment
platform clients.

### Standard facade: `packages/zigeffect-std`

Std owns application contracts and deterministic providers for:

- capability maturity and resolution;
- HTTP client/server request, response, route, middleware, streaming, and
  lifecycle contracts;
- SQL sessions, prepared statements, transactions, pools, migrations, and typed
  row streams;
- configuration sources, clock, randomness, identifiers, secrets, telemetry,
  resilience, authentication, cache, broker, and object storage;
- service layer constructors and unified application lifecycle; and
- conformance-suite interfaces shared by fake and production adapters.

Std must provide one documented application-facing choice for concepts that
currently have runtime, workflow, and cluster variants. Durable and local forms
remain distinct types but are selected through explicit constructors and
capability requirements.

### Production adapter packages

Create or extend optional packages:

- `zigeffect-http`: real HTTP/1.1 server/client lifecycle over Zig `std.Io`, with
  a path for HTTP/2 where dependencies mature;
- `zigeffect-postgres`: native protocol connection, binding, prepared statement,
  pool, transaction, migration, cancellation, TLS, and row streaming support;
- `zigeffect-storage-postgres`: Postgres/CockroachDB implementations of workflow
  journal, message, runner lease, checkpoint, and idempotency storage;
- `zigeffect-transport`: separately processable TCP/TLS cluster transport,
  discovery, pooling, health checking, authentication, and causal propagation;
- `zigeffect-otel`: live OTLP/HTTP exporter with batching, retry, deadlines,
  backpressure, flush, and shutdown;
- `zigeffect-redis`: cache, lock, rate-limit, and pub/sub adapters;
- `zigeffect-nats` or another selected first broker adapter behind `zstd.Broker`;
- `zigeffect-object-storage`: S3-compatible object storage first, with provider
  adapters added without changing application contracts.

The first implementation may reuse a reviewed upstream Zig protocol library,
but the wrapper must own capability descriptors, typed error classification,
redaction, causal facts, deterministic fakes, and conformance.

## Production HTTP Boundary

The server package must provide:

- socket bind/listen/accept and a bounded connection supervisor;
- request-line/header/body parsing with explicit byte and time limits;
- response streaming and connection close/keep-alive policy;
- router adaptation without changing existing typed endpoints;
- middleware for request ids, tracing, body limits, error mapping, CORS, auth,
  rate limits, compression negotiation, and secure headers;
- WebSocket upgrade and framed transport after the base server is stable;
- graceful drain with readiness transition and a bounded shutdown deadline;
- TLS through a replaceable provider; and
- deterministic server harness plus live loopback conformance.

The existing `MemoryServer` remains `fake`. The existing router is reusable.
No type named `Production*` may contain an in-process transport without a name
or descriptor that says so.

## Production SQL And Postgres Boundary

`zstd.Sql.Statement.binds` becomes mandatory for non-empty bind lists. Adapters
must reject unsupported binding rather than ignore values. The production
Postgres package must provide:

- native startup/auth/TLS protocol;
- parameter binding with correct text/binary encoding;
- prepared statement lifecycle and statement cache limits;
- persistent pooled connections with health checks and acquisition deadlines;
- transaction leases that pin one connection until commit/rollback;
- cancellation, server errors, serialization conflicts, and retry
  classification;
- typed row decoding and bounded streaming;
- migration locking, checksums, plan/apply receipts, and rollback posture; and
- live Postgres and CockroachDB conformance.

The `psql` adapter is retained as `local_development`. It must either implement
safe binds or return a typed `UnsupportedBinding` error. It cannot satisfy
production database requirements.

## Shared Durable Storage

The Postgres storage package implements existing vtables without introducing a
second workflow model. Required guarantees include:

- atomic append with monotonic per-execution sequence;
- idempotency-key uniqueness;
- consistent snapshot/checkpoint publication;
- lease compare-and-swap with fenced epochs;
- transactional message claim/ack/reply;
- redelivery after lease expiry;
- retention and compaction without erasing required deduplication identity;
- online schema compatibility and explicit migration; and
- concurrency, crash-window, and failover tests against real databases.

## Real Multi-Process Transport

The transport package replaces misleading in-process `production_http` and
`production_socket` implementations with either renamed compatibility adapters
or actual remote adapters. Production-candidate transport requires:

- arbitrary governed endpoints rather than localhost-only validation;
- real client and server sockets in separate processes;
- TLS handshake and peer/host verification;
- credential rotation or mTLS identity;
- constant-time secret comparison where shared secrets remain supported;
- bounded framing, pooling, reconnect, deadlines, health checks, backpressure,
  and graceful drain;
- service-discovery refresh from a real provider;
- duplicate/reordered/partial-frame handling;
- origin causal ids and separately captured runner lineage; and
- live two-runner and three-runner conformance.

## Standard-Library Completion

### Effectful streams

Add `Stream<A,E,R>` sources whose pulls are effects, with chunking,
backpressure, interruption, scoped finalization, merge, buffer, debounce,
timeout, retry, map/filter effect, sinks, and deterministic schedule tests.
HTTP bodies, SQL rows, broker deliveries, object data, and telemetry batches use
this one streaming abstraction.

### Configuration, time, randomness, ids, and secrets

Provide real and deterministic layers for:

- process environment and bounded config files;
- precedence, typed Schema decoding, reload policy, and provenance;
- monotonic and wall clocks;
- cryptographic and deterministic randomness;
- UUID/ULID-style ids;
- secret references and providers without exposing secret values in receipts;
- rotation notifications and zeroization where platform semantics permit.

### Observability

Unify log, metrics, tracing, and causal correlation. Add W3C trace propagation,
bounded metric attributes, histogram buckets, batching, exporter health,
flush/shutdown, and a real OTLP/HTTP adapter. Serialization-only OTLP evidence
remains `deterministic_model` or `local_development`.

### Resilience and lifecycle

Provide typed policies for retry, timeout, circuit breaker, bulkhead, rate
limit, hedging where safe, readiness, liveness, signal handling, drain, and
shutdown. Policies emit stable causal facts and work with virtual time.

### Schema and security

Extend Schema with floats/decimals, bytes, timestamps/durations, tuples, maps,
tagged unions, literals, recursive/lazy schemas, refinements, domain brands, and
version/migration helpers. Add constant-time secret primitives, JWT/JWK support,
API-key and session contracts, password-hash adapter boundaries, secure cookie
support, and authorization policy hooks. Cryptographic algorithms should come
from Zig std or reviewed dependencies, not bespoke implementations.

### Broker, cache, and object storage

Standard contracts cover message publish/consume/ack/nack, delivery identity,
cache get/set/delete/CAS/TTL, distributed locks, object put/get/head/delete/list,
multipart upload, checksums, and streaming. The first production adapter for
each contract must pass a live conformance suite before scaffolds may require it.

## Production Scaffold Profiles

Generated applications and systems support explicit profiles:

- `local-fake`: deterministic, no real side effects;
- `integration-real`: live local dependencies with bounded authority;
- `production`: production-candidate or verified adapters only.

The default introductory command may remain `local-fake`, but generated docs and
receipts must say so. A production profile includes real config loading, HTTP
listener, database pool, migrations, telemetry, lifecycle, and capability
validation. `project check --agent` fails if a required production adapter is
resolved to a lower maturity.

## Golden-Path Reference System

Add a repository-owned ZigEffect reference system, separate from the TypeScript
Yachdee applications, with:

- API service accepting and reading orders;
- worker service executing a durable statechart/workflow;
- shared public domain package;
- Postgres/CockroachDB canonical storage;
- broker-backed or database-outbox work dispatch;
- object attachment path;
- real OTLP export;
- two separately supervised processes using authenticated transport;
- idempotent external command simulation;
- manifest requirements, acceptance checks, and Testing v2 scenarios; and
- reproducible local orchestration.

Required scenarios include create/read, concurrent duplicate submission,
transaction rollback, process crash between decision and command receipt,
redelivery, lease loss, database restart, network partition/recovery, graceful
drain, telemetry outage, secret scan, migration upgrade, and exact replay of
every deterministic inner decision.

## Testing And Evidence

Every adapter has three layers:

1. deterministic contract tests with fake services;
2. live conformance tests against the real dependency; and
3. golden-path reference-system acceptance tests.

Testing v2 facilities must bind to concrete adapters. `VirtualWorld` remains an
abstract model, but differential tests compare its normalized decisions with
live adapter traces where semantics overlap. Fault matrices inject through real
provider seams. Mutation points target application requirements, and production
checks reject unsupported required cases.

Suite receipts are required for every first-party `b.addTest` artifact. A pass
requires complete matching receipts with no pending tests, leaks, logged errors,
secret findings, missing adapter identity, or required coverage gaps.

## CI And Release Matrix

Replace the core-only trigger with workflows that cover changes to every
ZigEffect package, generated template, skill, reference system, and workbench.
Required lanes:

- fast deterministic affected tests;
- Debug and ReleaseSafe package tests with native suite receipts;
- generated scaffold compatibility;
- live Postgres and CockroachDB;
- live HTTP and multi-process TLS transport;
- broker/cache/object-storage conformance as adapters land;
- Linux and macOS, with architecture coverage where supported;
- sanitizer/fuzz capability reported as pass, fail, or unsupported;
- workbench tests/typecheck/build;
- tool hygiene, docs honesty, secret scans, and `git diff --check`;
- bounded performance and soak jobs outside the fast PR lane; and
- a release-candidate golden-path deployment/recovery run.

No release script may claim success when a required lane was skipped or timed
out. Local release output records duration and the slowest suites so agents can
choose focused checks during development.

## Migration And Naming Corrections

- Preserve old schemas with explicit readers or migrations.
- Deprecate misleading `ProductionHttpClusterTransport` and
  `ProductionSocketClusterTransport` names until they cross a real process
  boundary; expose compatibility names immediately.
- Mark `PsqlClient`, `MemoryServer`, file stores, OTLP serializers, and abstract
  testing worlds with truthful maturity descriptors.
- Revise roadmap/cookbook/architecture claims to distinguish `contract`,
  `local`, `production_candidate`, and `production_verified`.
- Do not delete deterministic adapters; they remain the preferred fast-test
  providers.

## Completion Definition

ZigEffect may claim readiness for real agentic backend development when:

- the capability model prevents fake/local evidence from satisfying production
  requirements;
- a generated production-profile service listens on a real socket, uses safely
  bound pooled Postgres, exports telemetry, drains cleanly, and passes live
  conformance;
- shared workflow/message/lease state survives process and database restarts;
- at least two separately running services communicate over authenticated TLS;
- the golden-path manifest has no required gaps and its recovery scenarios pass;
- all supported CI platforms pass the complete package and adapter matrix; and
- public docs contain no stronger claim than the captured evidence supports.

Multi-node production readiness additionally requires live failover, discovery,
pool maintenance, partition recovery, separately captured lineage, capacity
evidence, and an operational runbook validated against the reference system.

## Non-Goals

- Do not move external SDKs into the deterministic core.
- Do not implement cryptographic primitives from scratch.
- Do not require every cloud/vendor adapter before the first production release.
- Do not treat Kubernetes or a hosted control plane as the definition of
  production.
- Do not weaken human approval for deployment, migration, credential, or
  production mutation authority.
- Do not add report-about-report tools under `packages/zigeffect/tools`.
