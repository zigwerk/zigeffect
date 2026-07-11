# ZigEffect Production Application And Multi-Service Platform Roadmap

Date: 2026-07-11

Design:
`docs/superpowers/specs/2026-07-11-zigeffect-production-application-platform-design.md`

## Objective

Close the gap between ZigEffect's mature deterministic/agentic engine and the
real adapters, reference applications, evidence, CI, and operational lifecycle
required for agents to deliver production backend and multi-service systems.

This roadmap supersedes stronger completion labels in earlier local-first HTTP,
Postgres, transport, standard-library, and application-scaffold milestones. It
does not reopen their useful deterministic contracts.

## Release Rules

- Implement test-first and preserve the public facade.
- Use the Testing v2 server runner for every first-party test artifact.
- Read and validate the native suite receipt after every package test.
- No fake, model, subprocess-only, file-only, or in-process adapter may earn a
  production acceptance result.
- Live adapters require live conformance; skipped required infrastructure is
  incomplete, not passed.
- Do not add a new `packages/zigeffect/tools/*.zig` file for these milestones.
- Update generated templates and compatibility snapshots whenever their public
  contract changes.
- Each milestone ends with focused package gates, affected generated-project
  gates, docs honesty, secret scanning, and a bounded handoff record.

## Dependency Sequence

```text
M131 capability truth
  -> M132 errors/lifecycle contracts
  -> M133 HTTP server
  -> M134 native Postgres
  -> M135 live DB conformance
  -> M136 shared durable stores
  -> M137 real TLS transport
  -> M138 effectful streams
  -> M139 config/time/random/id/secrets
  -> M140 OTLP export
  -> M141 resilience/lifecycle
  -> M142 auth/security
  -> M143 Schema completion
  -> M144 cache/broker/object contracts
  -> M145 first production adapters
  -> M146 scaffold profiles
  -> M147 golden-path system
  -> M148 model/live fault integration
  -> M149 complete CI matrix
  -> M150 performance/operations/release
```

Some work can proceed in parallel after M132, but no downstream milestone may
claim completion without its listed predecessors.

## M131 — Executable Capability Truth

Goal: make adapter maturity and evidence enforceable rather than documentary.

- [x] Add failing `zstd.Capability` tests for ordered maturity, descriptor
  validation, feature/target matching, secret rejection, JSON round trips,
  duplicate adapters, and insufficient maturity.
- [x] Implement capability kinds for HTTP client/server, SQL database, workflow
  journal, message storage, lease storage, cluster transport, stream, config,
  clock, randomness, ids, secrets, telemetry, cache, broker, and object storage.
- [x] Add schema-versioned descriptors, requirement matching, resolution reports,
  limitations, and stable failure classifications.
- [x] Export `zstd.Capability` and lock it through public API tests.
- [x] Add optional manifest capability requirements and adapter-profile records
  with backwards-compatible decoding.
- [x] Add adapter identity/maturity/profile fields to test, project-check, and
  handoff receipts.
- [x] Mark existing Memory/Fake, abstract-model, file, `psql`, localhost, and
  serialization-only adapters truthfully.
- [x] Reject production checks backed by lower-maturity or stale conformance
  evidence.
- [x] Update CLI status/doctor/check output and Workbench capability gaps.
- [x] Replace misleading roadmap/cookbook wording and introduce deprecation
  aliases for in-process `Production*ClusterTransport` names.

Acceptance:

- A production HTTP-server requirement cannot resolve to `MemoryServer`.
- A production SQL requirement cannot resolve to `FakeDatabase` or `PsqlClient`.
- Existing v1 manifests without requirements remain valid and explicitly local.
- All descriptor/receipt JSON passes sentinel-secret and allocation-failure
  tests.

Implemented slice (2026-07-11):

- Descriptors cannot claim production maturity without real side effects and
  live-external conformance authority.
- Manifests now declare `execution_posture`, capability requirements, and named
  adapter profiles. Existing v1 JSON decodes as local with empty requirements
  and profiles.
- Profile resolution proves that `MemoryServer`, `FakeDatabase`, and
  `PsqlClient` cannot meet production requirements.
- Built-in HTTP, SQL, clock, process, filesystem, workflow journal, message,
  lease, cluster transport, Postgres subprocess, QUIC, and WebTransport
  adapters publish truthful descriptors.
- Test receipts, project command receipts, project status, and agent handoffs
  carry adapter profile evidence. Unresolved adapters make required test
  evidence incomplete and fail production project checks.
- Workbench parses and displays adapter maturity and capability gaps.
- The std root suite discovers the public boundary modules; its Testing v2
  receipt records 205/205 passed with zero leaks and zero log errors. Core is
  952/952, CLI is 34/34, QUIC is 6/6, and Workbench is 287/287.

Primary files:

- `packages/zigeffect-std/src/capability/root.zig`
- `packages/zigeffect-std/src/project/root.zig`
- `packages/zigeffect-std/src/testing/contract.zig`
- `packages/zigeffect-cli/src/root.zig`
- `packages/zigeffect-cli/src/templates.zig`
- `packages/zigeffect/workbench/src/*`

## M132 — Classified External Errors And Application Lifecycle Contracts

Goal: give every adapter one typed recovery vocabulary and one lifecycle model.

- [x] Add failing tests for timeout, unavailable, unauthorized, conflict,
  capacity, canceled, corrupt-data, unsupported, and internal classifications.
- [x] Add backend detail/cause attachment that remains redacted and bounded.
- [x] Define application start, ready, drain, stop, forced-stop, and failed
  states with idempotent transitions.
- [x] Add service-layer constructors and reverse-order scoped shutdown.
- [x] Add readiness/liveness snapshots and causal facts.
- [x] Remove avoidable `anyerror` from application-facing HTTP/SQL/transport
  contracts while retaining type-erased vtable internals.

Acceptance:

- Retry and circuit policies consume classifications, never backend strings.
- Duplicate drain/stop is safe and every acquired resource finalizes once.
- Cancellation and shutdown retain causal ownership.

Implemented (2026-07-11):

- `ExternalFailureClass` is owned by core and shared by std HTTP/SQL and cluster
  transport reports. Recovery policy consumes the enum's retry posture.
- `zstd.External.Failure` bounds and redacts backend, operation, detail, cause,
  retry metadata, and JSON.
- Classified HTTP and SQL effects keep backend failures in a typed result
  channel. Raw `anyerror` entry points remain compatibility seams only; erased
  transport vtables emit classified failure reports.
- `zstd.Application.Lifecycle.Manager` provides idempotent start, ready, drain,
  stop, forced-stop, and fail transitions, readiness/liveness snapshots,
  service-provider construction, causal lifecycle facts, and exactly-once
  reverse-order finalization.
- Verification receipts: core 953/953 and std 215/215, complete with zero leaks
  and zero log errors.

## M133 — Real HTTP Server Package

Goal: serve typed ZigEffect routes over real bounded sockets.

- [x] Create `packages/zigeffect-http` with a Testing v2 build and public facade.
- [x] Add parser/codec tests for request line, headers, content length, chunking,
  malformed input, limits, partial reads, keep-alive, and response streaming.
- [x] Implement `std.Io` bind/listen/accept with supervised connections.
- [x] Adapt existing `zstd.Http.Router` and typed JSON endpoints.
- [x] Add request/response body streams, connection/request deadlines, body and
  header limits, structured error mapping, and client disconnect cancellation.
- [x] Add middleware composition, request ids, causal/trace propagation, secure
  headers, CORS, compression negotiation, and rate-limit hook.
- [x] Add readiness, drain, graceful shutdown, and forced-shutdown evidence.
- [x] Add TLS provider contract and live TLS loopback conformance.
- [x] Add WebSocket upgrade after the base HTTP/1.1 release gate passes.
- [x] Run live client/server tests in separate processes.

Acceptance:

- A generated endpoint is reachable through an OS socket.
- Oversized, slow, malformed, and disconnected requests fail boundedly.
- Shutdown stops readiness, drains accepted work, and leaves no fibers/resources.
- The adapter earns `production_candidate` only in the live conformance lane.

Implemented slice (2026-07-11):

- Added the standalone `zigeffect-http` package with a Testing v2 build and an
  explicitly `local_development` capability descriptor.
- Added bounded HTTP/1.0 and HTTP/1.1 request-line, headers, content-length,
  chunked bodies/trailers, keep-alive/pipelining, hostile framing checks,
  partial reads, request deadlines, and fixed/chunked response codecs.
- Added real `std.Io` bind/listen/accept/read/dispatch/write ownership,
  supervised connection bounds, typed-router adaptation, structured failures,
  middleware/guards, request and trace ids, security/CORS/compression headers,
  readiness, graceful drain, deadline-driven forced stop, and allocation-fault
  coverage.
- Added a type-erased TLS provider boundary with a bounded handshake deadline.
  `zigeffect-http-tls-openssl` is a separate system dependency and has a live,
  certificate-verified TLS 1.3 request/response receipt; its descriptor is
  `production_candidate` with an explicit OpenSSL 3 limitation.
- Added RFC handshake validation, bounded masked-frame parsing, server framing,
  ping/pong, close, and a live WebSocket upgrade/echo/close session. Fragmented
  message reassembly remains deliberately unsupported and bounded.
- Added a separate-process HTTP conformance executable to the normal package
  gate. Current receipts: `zigeffect-http` 27/27 plus the separate-process run,
  and `zigeffect-http-tls-openssl` 1/1; all complete with zero leaks/log errors.
- Request and response bodies now expose owned `EffectStream` adapters with
  chunked collection and finalization tests; socket reads remain bounded by the
  HTTP parser limits and deadlines. The base HTTP descriptor is
  `production_candidate`, independently content-addressed from the TLS adapter.

## M134 — Native Postgres Driver

Goal: replace subprocess queries with safely bound persistent database sessions.

- [x] Select and pin a reviewed Zig Postgres/TLS dependency or implement the
  minimum protocol behind an internal package boundary.
- [x] Add protocol tests for startup, auth, TLS negotiation, bind/execute/sync,
  rows, notices, errors, cancellation, and connection loss.
- [x] Make ignored non-empty binds a typed error in `PsqlClient` immediately.
- [x] Implement value encoders and safe parameter binding.
- [x] Implement prepared statement lifecycle and bounded cache.
- [x] Implement persistent connections, pool leases, health checks, acquisition
  deadlines, idle/max lifetime, and graceful close.
- [x] Pin transactions to one lease through commit/rollback and cancellation.
- [x] Add typed row streams and Schema decoding.
- [x] Add classified Postgres/Cockroach errors and serialization retry evidence.
- [x] Implement migration checksums, advisory locking, plan/apply/status, and
  explicit rollback posture.

Acceptance:

- No query path interpolates untrusted values into SQL text.
- A transaction cannot cross connections or leak a lease.
- Cancellation terminates server work or invalidates the connection safely.
- Pool exhaustion and database loss are bounded and causally classified.

## M135 — Live Postgres And CockroachDB Conformance

Goal: prove the SQL contract against real databases.

- [x] Add reproducible local database orchestration outside request-path code.
- [x] Run binding coverage for null/bool/integer/float/text/bytes/time/decimal and
  arrays where supported.
- [x] Test prepared statements, transactions, rollback, nested-policy behavior,
  cancellation, reconnect, serialization conflict, migration locking, and
  concurrent pool use.
- [x] Run the same normalized suite against Postgres and CockroachDB.
- [x] Emit conformance receipts with server versions and limitations.
- [x] Add optional stress/soak lanes and bounded performance baselines.

Acceptance:

- Required cases are passed, not unsupported.
- The same application SQL effects run against fake, Postgres, and CockroachDB
  with declared semantic differences only.

## M136 — SQL-Backed Durable Runtime Storage

Goal: make workflows and clusters durable across machines and process restarts.

- [x] Create `packages/zigeffect-storage-postgres`.
- [x] Implement `JournalStore` with atomic monotonic append and idempotency.
- [x] Implement checkpoint/snapshot publication, compaction, retention, and
  schema migration.
- [x] Implement `MessageStorage` transactional submit/claim/ack/reply,
  visibility deadlines, and redelivery.
- [x] Implement `RunnerStorage` fenced lease CAS, refresh, release, and recovery.
- [x] Add outbox/inbox primitives for cross-service command dispatch.
- [x] Test crash windows before/after every database commit boundary.
- [x] Differentially compare file and SQL replay semantics.
- [x] Add live concurrent writers, lease loss, database restart, and failover
  conformance.

Acceptance:

- Workflow/statechart state and command receipts survive process/database
  restart without duplicate accepted decisions.
- Stale lease owners cannot append journal or message state.
- Redelivery remains idempotent and externally supplied keys are preserved.

Implemented slice (2026-07-11):

- Added native libpq-backed persistent sessions, bounded prepared caching and
  pools, pinned transactions, cancellation, classified SQLSTATE failures,
  serializable whole-transaction retries, and database-held migration leases.
- Extended the shared SQL value model and native binding path for null, bool,
  integer, float, text, binary bytes, timestamps, arbitrary-precision decimals,
  and text arrays. These are actual bound parameters in both live database
  suites rather than SQL literals.
- Added normalized PostgreSQL 18 and CockroachDB 26.2 conformance with real
  cancellation, conflicts, migrations, concurrent leases, and restart phases.
- Added `zigeffect-storage-postgres` implementing the public journal, message,
  and runner-store vtables plus checkpoints, archive/checkpoint retention,
  transactional outbox/inbox units of work, bounded visibility/redelivery,
  stale-epoch fencing, ambiguity-safe retries, and typed conflict mapping.
- Live storage receipts cover file/SQL differential replay, concurrent writers,
  lease movement, commit-reply loss, and full database restart through a fresh
  client process on PostgreSQL and CockroachDB. A three-node Cockroach failover
  run, every-store before/after-commit matrix, typed/Schema row streaming,
  versioned receipt metadata, and scheduled database stress lane close the
  remaining conformance work. Multi-region failover remains operator-owned.

## M137 — Real Authenticated Multi-Process Transport

Goal: connect separately running ZigEffect runners over a production protocol.

- [x] Rename current encoded in-process production transports to compatibility
  adapters while preserving schema readers.
- [x] Create `packages/zigeffect-transport` with client/server socket ownership.
- [x] Implement real arbitrary-endpoint TCP transport and bounded framing.
- [x] Implement TLS handshake, host/peer verification, certificate reload, and
  mTLS or rotated credential identity.
- [x] Add constant-time shared-secret comparison for compatibility mode.
- [x] Implement connection pools, deadlines, reconnect, backpressure, health
  checks, drain, and discovery refresh.
- [x] Run two- and three-process ask/reply/workflow/queue scenarios.
- [x] Capture separate causal artifacts and stitch origin lineage.
- [x] Inject partial frames, duplicates, reordering, disconnects, partitions,
  stale discovery, credential rotation, and lease movement.

Acceptance:

- No production transport delegates delivery to an in-process handler.
- TLS and authentication failures occur before storage mutation.
- Separate runner receipts establish end-to-end causal lineage.

## M138 — Effectful Streams And Backpressure

Goal: provide one resource-safe streaming substrate for all production IO.

- [x] Add failing stream tests for effectful pull, chunk, map/filter effect,
  flat-map, merge, buffer, debounce, timeout, retry, sinks, interruption, and
  finalization.
- [x] Implement `Stream<A,E,R>` over runtime suspension and scoped resources.
- [x] Add bounded queue/backpressure strategies and causal wait facts.
- [x] Add deterministic schedule/interleaving exploration.
- [x] Adapt HTTP bodies, SQL rows, broker deliveries, object data, JSONL, and
  telemetry batches.
- [x] Preserve the synchronous value stream under a clear compatibility name.

Acceptance:

- Slow consumers bound memory and propagate backpressure.
- Interruption finalizes the source and sink exactly once.
- Deterministic and real executors produce structurally equivalent lifecycle
  facts within documented bounds.

## M139 — Config, Clock, Randomness, IDs, And Secret Providers

- [x] Add process-environment and bounded file config providers with precedence,
  provenance, Schema decoding, and reload policy.
- [x] Add real wall/monotonic clock and deterministic test clock layers.
- [x] Add cryptographic and deterministic randomness services.
- [x] Add UUID/ULID-style id providers with deterministic tests.
- [x] Add secret-reference contract, environment/file development providers,
  provider rotation, access auditing, and redacted display.
- [x] Prevent raw secret material from entering descriptors, causal facts,
  receipts, snapshots, logs, or Workbench payloads.

Acceptance:

- Generated production services have no hard-coded config JSON.
- Tests can reproduce time/random/id decisions exactly.
- Secret scanning covers every serialization and failure boundary.

## M140 — Live OpenTelemetry Export

- [x] Create `packages/zigeffect-otel`.
- [x] Add W3C traceparent/tracestate propagation.
- [x] Implement OTLP/HTTP logs, metrics, and traces with batching, limits,
  deadlines, retry, backpressure, flush, and shutdown.
- [x] Define temporality/histogram/attribute-cardinality policy.
- [x] Correlate causal run/event ids without exporting secret payloads.
- [x] Run live collector conformance and outage/recovery scenarios.

Acceptance:

- A collector receives valid telemetry from two real services.
- Exporter outage cannot block application shutdown indefinitely or erase local
  causal evidence.

## M141 — Resilience And Service Lifecycle

- [x] Add typed retry/timeout/circuit-breaker/bulkhead/rate-limit policies.
- [x] Add virtual-time and real-time implementations with the same decisions.
- [x] Add readiness, liveness, OS signal handling, drain, shutdown deadline, and
  forced-stop layers.
- [x] Integrate HTTP, SQL, transport, broker, cache, object storage, and OTLP.
- [x] Add causal facts and Workbench surfaces for state transitions.

Acceptance:

- Policies use classified failures and never retry terminal errors.
- Shutdown ordering is dependency-aware and bounded.

## M142 — Authentication, Authorization, And Security Primitives

- [x] Add constant-time secret values and secure comparison helpers.
- [x] Add API-key, signed session, JWT/JWK, and authorization policy contracts.
- [x] Add secure cookie and CSRF helpers for HTTP.
- [x] Add password-hash adapter boundary using reviewed algorithms.
- [x] Add certificate/key rotation hooks and audit facts.
- [x] Add hostile-input, timing-posture, replay, expiry, rotation, and redaction
  tests.

Acceptance:

- No bespoke crypto algorithm is introduced.
- Auth context propagates across effects and services without raw credentials.

## M143 — Production Schema Completion

- [x] Add float/decimal, bytes, timestamp/duration, tuple, map/record, literal,
  tagged union, recursive/lazy, refinement, brand, and version/migration schemas.
- [x] Add JSON/config/SQL/CLI generation and detailed issue paths for each.
- [x] Add OpenAPI/JSON-Schema projection for lossless supported constructs and
  explicit projection-loss diagnostics otherwise.
- [x] Expand deterministic generation, invalid cases, boundaries, and shrinking.
- [x] Add compatibility snapshots and allocation-failure tests.

## M144 — Cache, Broker, And Object-Storage Contracts

- [x] Add `zstd.Cache` get/set/delete/CAS/TTL and distributed-lock contracts.
- [x] Add `zstd.Broker` publish/consume/ack/nack/redelivery/idempotency contracts.
- [x] Add `zstd.ObjectStorage` put/get/head/delete/list/multipart/checksum and
  streaming contracts.
- [x] Add deterministic providers, capability descriptors, classified errors,
  causal facts, and conformance suites.
- [x] Define transaction/outbox integration with SQL and workflow commands.

## M145 — First Production Cache, Broker, And Object Adapters

- [x] Implement Redis cache/lock/rate-limit/pubsub adapter.
- [x] Select and implement one production broker adapter, initially NATS unless
  dependency review chooses another.
- [x] Implement S3-compatible object storage adapter and local conformance target.
- [x] Add live failure, reconnect, redelivery, multipart, checksum, permission,
  and bounded-stream tests.
- [x] Record provider-specific limitations without changing std contracts.

## M146 — Honest Scaffold Profiles And Generators

- [x] Add `--profile local-fake|integration-real|production` to application,
  service, and system scaffolds.
- [x] Generate capability requirements and adapter profile records.
- [x] Keep local-fake fast but label every receipt and README clearly.
- [x] Generate a real HTTP listener, config layers, DB pool/migrations,
  telemetry, lifecycle, and production-check command for production profiles.
- [x] Add adapter-specific generators without importing private package internals.
- [x] Update compatibility schema/version and conflict-safe upgrades.
- [x] Compile and run every profile in Debug and ReleaseSafe.

Acceptance:

- Production scaffolds contain no direct router smoke call or `FakeDatabase`.
- `project check --agent` refuses unresolved production requirements.

## M147 — Golden-Path Multi-Service Reference System

- [x] Add a manifest-owned ZigEffect reference system with API, worker, and
  shared domain package.
- [x] Implement create/read order, durable statechart processing, outbox,
  idempotent command adapter, and object attachment.
- [x] Use real HTTP, Postgres/CockroachDB, shared durable stores, authenticated
  transport, telemetry, lifecycle, and selected broker/cache/object adapters.
- [x] Add local orchestration and production-shaped configuration.
- [x] Add required Testing v2 scenarios for duplicates, rollback, crash windows,
  redelivery, lease loss, database restart, network partition, drain, telemetry
  outage, migration, secret scan, and replay.
- [x] Expose project/capability/runtime evidence in Workbench.

Acceptance:

- Every requirement has a passing live scenario and no required gap.
- API and worker are separate OS processes and share no in-memory authority.

## M148 — Model-To-Live Fault And Differential Integration

- [x] Bind `FaultMatrix` cases to concrete HTTP/SQL/storage/transport/broker/
  cache/object/telemetry providers.
- [x] Compare virtual-world/model decisions to normalized live traces.
- [x] Add source-linked mutation points to the reference system.
- [x] Add schedule exploration around all shared state and recovery windows.
- [x] Preserve exact seeds, fault indices, adapter identities, and replay commands.
- [x] Reject required unsupported/truncated evidence.

## M149 — Complete CI And Release Evidence Matrix

- [x] Trigger on core, std, CLI, every adapter, generated templates, skills,
  Workbench, and reference-system changes.
- [x] Assert every public module's tests are discovered by its package-owned
  Testing v2 artifact; fail when expected suite coverage disappears.
- [x] Add fast affected-test and sharded package lanes.
- [x] Run Debug/ReleaseSafe native-receipt tests on Linux and macOS.
- [x] Add live Postgres/Cockroach, HTTP/TLS transport, Redis, broker, object
  storage, and OTLP services as their adapters land.
- [x] Validate every suite receipt and aggregate completeness without hiding
  unsupported required gates.
- [x] Add scaffold profile builds, Workbench checks, docs honesty, secret scans,
  tool hygiene, API compatibility, and diff checks.
- [x] Add scheduled fuzz, sanitizer, stress, soak, and performance jobs.
- [x] Publish bounded artifacts and an agent-readable failure handoff.

## M150 — Capacity, Operations, And Production Release

- [x] Define throughput, latency, memory, connection, pool, queue, replay, and
  artifact budgets for the reference system.
- [x] Run repeatable load, soak, restart, failover, partition, migration, and
  rollback exercises.
- [x] Add dashboards, alerts, runbooks, backup/restore, retention, credential
  rotation, and incident evidence.
- [x] Validate packaging, versioning, changelogs, install/upgrade, and supported
  platform matrix.
- [x] Remove or finalize deprecated misleading adapter names.
- [x] Run the full release matrix from a clean checkout and capture immutable
  receipts.
- [x] Publish only evidence-supported release claims.

## Immediate Execution Order

1. Complete M131 capability truth and docs correction.
2. Land M132 classified errors/lifecycle so HTTP and SQL share semantics.
3. Build M133 and M134 in parallel only after M132 stabilizes.
4. Use M135 to promote Postgres; then build M136 shared stores.
5. Build M137 with shared storage available for real runner tests.
6. Complete M138-M145 std/adapters before production scaffold generation.
7. Make M147 the integration oracle, then close model/live and CI gaps.
8. Earn the final release through M150; do not date-drive the claim.

## Program Completion Evidence

Completion ledger (2026-07-11):

- M131-M132: executable capability descriptors, profile resolution, verified
  receipt paths/digests, classified external failures, and lifecycle evidence
  are enforced by std/CLI tests and production `project check --agent`.
- M133-M140: HTTP/TLS, native libpq SQL, durable PostgreSQL storage,
  authenticated TCP/TLS transport, effect streams, system primitives, and OTLP
  have package-owned Testing v2 gates plus content-addressed live receipts.
- M135-M136 additionally run real PostgreSQL and CockroachDB suites, restart
  clients, concurrent writers, every-store commit ambiguity, and three-node
  Cockroach failover. Cockroach exercises password auth and required TLS.
- M137-M145 bind real provider failures and limitations for transport, Redis
  cache/Streams broker, S3-compatible object storage, lifecycle, security, and
  Schema. The HTTP parser has a native Zig fuzz target; the core concurrency
  gate is TSan-instrumented and executes in scheduled Linux CI (Zig/LLVM 0.16
  crashes before `main` on native macOS arm64, so macOS is compile-only for
  that optional sanitizer lane).
- M146 generates every application/service/system profile and library/package
  scaffolds, builds roots in Debug and ReleaseSafe, and builds system children
  in both modes. Production checks fail closed on unresolved capabilities.
- M147-M148 use the manifest-owned reference API/worker/shared system, real
  infrastructure, independent processes, provider-bound fault cases,
  source-linked mutations, complete schedule exploration, and a normalized
  live trace that the process topology verifies before differential use.
- M149-M150 are enforced by the Linux/macOS sharded workflow, live and
  scheduled lanes, affected selection, fuzz/TSan/stress/soak/performance jobs,
  immutable evidence registry, operational contracts, and the clean-snapshot
  release gate. Claims remain `production_candidate`; deployment-specific SLO,
  multi-region topology, HTTP/2, Redis Cluster, direct S3 TLS, and OTLP/gRPC are
  explicitly outside the demonstrated profile.

Populate each milestone with:

- changed public requirements and schemas;
- failing test introduced before implementation;
- native suite receipt paths and counts;
- live conformance environment/version;
- replay commands and relevant causal event ids;
- compatibility/migration decision;
- performance and limitation disclosure; and
- exact release claims newly allowed or still forbidden.

The program is complete only when every milestone is checked or an explicitly
approved scope change updates this roadmap and the governing design.
