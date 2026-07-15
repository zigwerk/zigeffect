# ZigEffect gRPC Excellence Implementation Plan

**Goal:** Complete every requirement in the 2026-07-13 excellence design and
promote only evidence-backed capability slices.

**Method:** Framework-mode ZigEffect development, public-boundary TDD, Testing
v2 receipts, deterministic providers before real integrations, and live gates
after deterministic behavior passes.

## Milestone 0: Truthful baseline and roadmap

- [x] Audit the public facade, generated output, native transport, middleware,
      standard services, web package, CI, and receipts.
- [x] Record complete requirements and acceptance boundaries in the excellence
      design.
- [x] Split capability descriptors by ephemeral, persistent unary, persistent
      streaming, Connect, server, generated, and Cloud Run behavior.
- [x] Remove or downgrade every feature claim not exercised by its receipt.
- [ ] Replace the stale v1 receipt with a schema-v2 candidate only after its
      declared checks run on committed source.

## Milestone 1: Complete wire semantics

- [x] Add failing deterministic tests for initial/trailing/repeated/binary
      metadata, percent status messages, rich status details, and trailers-only
      responses.
- [x] Preserve request metadata through server call context and response
      metadata/status details through native client/server transport.
- [x] Parse and enforce `grpc-timeout`; propagate remote cancellation and
      handler deadline.
- [x] Validate request/response pseudoheaders, HTTP status, content type,
      schemes, encodings, header counts, and byte bounds.
- [x] Implement correct HTTP-to-gRPC fallback status mapping.
- [x] Add per-message response compression selection and negotiation tests.

## Milestone 2: Typed generated API

- [x] Add failing compile/runtime tests for generated method descriptors,
      typed client methods, server registration, and typed status errors.
- [x] Extend generation with a ZigEffect service companion for all four call
      shapes.
- [x] Generate one-call service registration and method policy descriptors.
- [x] Add typed owned/scoped headers, trailers, status, and streaming handles.
- [x] Cover imports, well-known types, custom options, maps, oneofs, optional,
      unknown fields, and Buf breaking compatibility.

## Milestone 3: Persistent incremental client streaming

- [x] Add deterministic capacity-one client-stream tests for fragmentation,
      backpressure, half-close, cancellation, deadline, and trailers.
- [x] Generalize persistent-channel operations from unary-only calls to all
      call shapes.
- [x] Expose incremental send/receive handles with bounded ownership.
- [x] Apply client interceptors and telemetry across stream lifetime.
- [x] Prove simultaneous unary and streaming calls share one connection without
      head-of-line serialization or cross-stream failure.

## Milestone 4: Channel state, resolution, and service policy

- [x] Implement an inspectable connectivity statechart and deterministic state
      transition tests.
- [x] Add URI targets, resolver interface, deterministic resolver, DNS refresh,
      address updates, `pick_first`, and `round_robin`.
- [x] Parse bounded service-config JSON with per-method timeout,
      wait-for-ready, retry, hedging, health, and load-balancing settings.
- [x] Add configured safe-call retries, deterministic jittered backoff,
      throttling, pushback, and bounded safe-method hedging.
- [x] Add explicit HTTP/2 commitment tracking before enabling transparent
      retry for failures that occur after response headers arrive.
- [x] Add client Health Watch gating and channel/subchannel snapshots.

## Milestone 5: Identity, TLS, and Cloud Run security

- [x] Add composable channel/per-call credential interfaces and deterministic
      token sources.
- [x] Implement Google metadata-server ID-token provider with audience, cache,
      pre-expiry single-flight refresh, timeout, and redacted failures.
- [x] Generalize strict OIDC/JWKS verification and retain IAP as a profile.
- [x] Add mTLS client/server certificates, trust bundles, peer identity, and
      atomic rotation tests.
- [x] Add Cloud Run service-to-service integration using generated clients and
      an injected fake metadata server in deterministic CI.

## Milestone 6: Server admission and lifecycle policy

- [x] Add global and per-method concurrency/rate/admission limits with typed
      overload outcomes.
- [x] Add connection idle, maximum age/grace, keepalive enforcement, and abuse
      limits.
- [x] Scope handlers and stream workers under supervised shutdown.
- [x] Prove readiness, health shutdown notification, GOAWAY drain, forced
      cancellation, and zero pending work.

## Milestone 7: Standard services and observability

- [x] Replace Health Watch polling with an event-driven bounded broadcast.
- [x] Complete reflection v1/v1alpha filename, symbol, and extension indexes.
- [x] Implement Channelz-compatible snapshots and generated service binding.
- [x] Replace handcrafted middleware JSON with typed `zigeffect-otel` spans,
      metrics, logs/events, bounded attributes, and verified secure export.
- [x] Add native OTLP histograms, attempt/connection instruments, propagation
      links, and exemplars where supported by the OTLP/HTTP schema.
- [x] Add bounded-cardinality and secret-redaction acceptance tests.
- [x] Emit causal facts for resolve/connect/pick/attempt/stream/handler/drain.

## Milestone 8: Connect and Solid completeness

- [x] Add Connect metadata, compression, timeout, end-stream metadata/details,
      and incremental streaming tests.
- [x] Build Connect conformance client/server adapters and run every applicable
      stable test with explicit unsupported cases.
- [x] Verify Connect-ES unary, server streaming, cancellation, errors,
      compression, and CORS directly against the Zig server.
- [x] Generate Solid Query query/mutation/subscription helpers with stable keys,
      abort propagation, and SSR-safe transport construction.

## Milestone 9: Conformance, fuzzing, and differential evidence

- [x] Implement official gRPC interoperability client/server executables and
      run every applicable case in plaintext and TLS.
- [x] Add grpc-go plus Python differential matrix.
- [x] Add deterministic property tests and coverage-guided fuzz targets for
      framing, headers, metadata, status, Connect, service config, and state.
- [x] Use ZigEffect VirtualWorld/FaultMatrix/Schedules for retry, streaming,
      GOAWAY, RST, partition, rotation, and shutdown exploration.
- [x] Store minimized seeds/replay commands and bounded redacted receipts.

## Milestone 10: Performance and production qualification

- [x] Add reproducible grpc-go/tonic/C++ benchmarks for unary and all streaming
      shapes with latency, throughput, CPU, allocation, and RSS metrics.
- [x] Optimize only from profiles: remove measured ordered-removal, polling,
      worker-creation, flow-control, and handoff costs; evaluate framing,
      TLS-context, and lock costs without speculative lifetime changes.
- [x] Define Linux amd64/arm64 ReleaseSafe and ReleaseFast CI.
- [x] Add a self-contained native-preflight plus five-segment 24-hour
      qualification workflow with defensive and memory evidence.
- [x] Add an authenticated private Cloud Run service-to-service qualification
      workflow using a metadata-server ID token and every RPC shape.
- [ ] Run that workflow on committed source and check in the native Linux
      qualification receipts.
- [x] Run Cloud Run container deployment smoke and faulted rolling shutdown.
- [ ] Run the 24-hour mixed-shape soak with churn and memory bounds.
- [x] Review and prepare a content-bound schema-v2 working-tree candidate
      receipt without promoting unrun external gates.
- [ ] Publish a semver release and promote each qualifying capability slice.

## Repository verification gates

- [x] `zig fmt --check` for all changed Zig sources.
- [x] `zig build test` for `zigeffect-grpc`, then inspect its Testing v2 receipt.
- [x] `zig build external-test`, official interop, grpc-go differential,
      Connect server conformance (120/120), Connect client conformance (55/55),
      and Connect-ES.
- [x] `zig build test` and examples for `zigeffect-std`, then inspect receipt.
- [x] Generated web package typecheck and tests.
- [x] Focused Ziac gRPC tests and full package test.
- [x] `packages/zigeffect/scripts/check_testing_v2_migration.sh`.
- [x] `packages/zigeffect/tools/check_tool_hygiene.sh`.
- [x] Root `bun run check` and `git diff --check`.
- [x] Report every external or unrun gate; absence of evidence is never a pass.

## Final audit gap closure

- [x] Check in an immutable Buf descriptor baseline, add one gate that accepts
      the current public schema and rejects a breaking mutation, and run it.
- [x] Add production `stream` causal emission at native stream lifecycle
      boundaries and prove it through a real client/server stream.
- [x] Generate the Connect `ClientCompat` protocol, add a Zig client-under-test
      adapter and an honest supported-feature matrix, then run every applicable
      stable client case with the official runner.
- [x] Rerun affected Testing v2, external conformance, formatting, hygiene, and
      package gates; inspect complete receipts rather than relying on exit code.
- [x] Regenerate the content-bound schema-v2 candidate after all source changes,
      preserving every unrun committed-source/external gate as incomplete.
