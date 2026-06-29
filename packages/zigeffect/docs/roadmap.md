# zigeffect Roadmap

Date: 2026-06-24

`zigeffect` is a Zig-native Effect-inspired engine whose primary debugging
interface is a deterministic, queryable **causal event graph** that LLM agents
query structurally (cause, lineage, resources, fibers, requirements, retries,
findings) instead of parsing logs. The goal is not API cloning; it is a
production-grade Zig shape for direct-style programs, typed errors, service
requirements, scoped resources, dependency layers, an agent-observable causal
runtime, and real async execution.

The deterministic, semantic-first philosophy is deliberate: the **core** must be
testable without threads, IO, or wall-clock time. Real async/concurrent execution
lives in backend adapters (and now real OS-thread / zio-coroutine executors) that
obey the same Scope / Exit / Cause / event contracts — proven by the invariant
that the same program produces a structurally-equivalent causal trace under every
executor. In the current checker, "structurally-equivalent" means the same event
kinds, cause and parent edge kinds, id-insensitive same-scope/resource/fiber
ownership facts, finding-evidence owner states, and per-fiber terminal lifecycle
states, independent of concrete event ids and scheduler ordering. It is still a
semantic fact comparison, not exact event-id graph isomorphism.

## Status at a glance

| # | Pillar | Status | Where |
|---|--------|--------|-------|
| 1 | Effect core + typed errors | **done** | `src/effect/effect.zig`, `src/core/result.zig`, `src/core/context.zig` |
| 2 | DI layers + layer graph | **done** | `src/layer/layer.zig`, `src/layer/graph.zig`, `src/dependency/*` |
| 3 | Scoped resources + finalizers | **done** | `src/core/scope.zig`, `src/effect/resource.zig` |
| 4 | Fiber runtime + concurrency | **real backends** (deterministic, zio coroutines, OS-thread pool) | `src/runtime/fiber.zig`, `src/runtime/thread_pool_executor.zig`, `src/effect/ergonomics.zig`, `packages/zigeffect-zio` |
| 5 | Causal store + event graph + queries | **done** | `src/services/causal.zig` |
| 6 | Causal dev loop (compare/advice/verdict) | **done** | `tools/causal_dev_loop`, `causal_compare`, `causal_advice`, `causal_verdict` |
| 7 | Guarded remediation + agent interventions | **closed loop, gate-off by default** | `src/services/policy_engine.zig`, `src/services/agent_intervention.zig`, `tools/causal_*remediation*` |
| 8 | App-facing causal trace | **done** | `src/services/causal_app_runtime.zig` |
| 9 | Visual workbench (SolidJS / zig-webui) | **live-attach + dev-session UX** (static + streaming via collector plus host-frame ingest, host apply adapter, host runner bundle, supervised host loop, NDJSON fact tap, host request router, runtime runner, and local agent development health/timeline/issues view) | `workbench/`, `workbench/src/collector/` |
| 10 | Export adapters (JSONL/DOT/OTel/OTLP/graph-history/NenDB) | **OTLP + collector live end-to-end** | `src/services/causal_*_backend.zig`, `causal_otlp_json.zig` |
| 11 | Durable workflows + clustering | **scheduler runs on zio; workflow journal appends can live-mirror into causal stores; loopback + remote socket wrappers cross the transport boundary; discovery JSON/file/HTTP snapshots, caller-owned HTTP refresh loops, and auth-epoch-aware selection feed the local registry** | `src/workflow/*`, `src/cluster/*` |
| 12 | Agent-operable runtime layer | **bounded interventions, counterfactuals, invariants, evals, semantic diffs, live command executor/tap, poll bridge, local daemon/HTTP engine bridge, eval diff artifacts/links/manifests, dev-loop/remediation-decision/patch-proposal eval persistence** | `src/services/agent_intervention.zig`, `counterfactual.zig`, `causal_invariant.zig`, `agent_eval.zig`, `causal_diff.zig`, `causal_live_command.zig` |
| 13 | Production-operable guardrails | **live commands, concurrency facts, transport policy/discovery registry, ops storage/alert policy, gated ops artifact responses, alert delivery/webhook/provider envelopes, provider secret injection and retry reporting, endpoint-aware runbooks** | `workbench/src/collector`, `src/services/causal_concurrency.zig`, `src/services/causal_ops.zig`, `causal_ops_storage.zig`, `causal_ops_alert.zig`, `src/cluster/transport.zig` |
| 14 | Multi-runner causal evidence | **local lineage stitcher plus deployment artifact metadata** | `src/services/causal_runner_lineage.zig` |
| 15 | Effect-grade standard library | **M1-M19 delivered**: service kernel, production Schema, production Schema-powered CLI, effect-native config/JSON/secrets, streams/queues/pubsub/sinks, local process/workspace/FS adapters, observability recorder/artifacts, HTTP/WebSocket contracts/adapters, Schema-coded local HTTP router, SQL contracts plus local Postgres adapter, typed SQL row decoding, Postgres migration planning/apply SQL, experimental QUIC/HTTP3/WebTransport adapter, local WebTransport workbench bridge, local agent toolkit, real local-tool cookbook examples, local agent supervisor, and workbench dev-session UX | `packages/zigeffect-std`, `packages/zigeffect-postgres`, `packages/zigeffect-quic`, `packages/zigeffect-std/docs/cookbook.md`, `docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md` |

## What is real today

- Direct-style effects with typed success/failure channels; `Exit`/`Cause`/`CauseTree`.
- Dependency injection gates, layer startup/teardown, heterogeneous graph startup
  with memoization, and readable dependency diagnostics.
- Deterministic scoped cleanup with reverse-order, exit-aware finalizers.
- **Structured concurrency on three executors, one abstraction.** `fork`/`join`/
  `interrupt`, `forEachPar`/`zipPar`, and the race family — `raceFirst`/`raceAll`/
  `race` (prefer-success) / `both` (fail-fast) — run on the deterministic backend,
  on **real zio coroutines**, OR on a **real OS-thread pool** (`ThreadPoolExecutor`)
  via the `FiberExecutor` vtable. The D2 invariant holds across all three: the same
  program yields a structurally-equivalent causal trace in the stronger semantic
  fact sense defined above.
- **Thread-safe state primitives.** `CausalStore`/`Ref`/`Hub` are lifted to
  thread-safe with a `SpinLock`, proven by an 8-thread × 2000-op stress test +
  mutation testing. STM (`TRef`, `Stm.atomically`) with optimistic conflict-retry,
  including **heterogeneous transactions** (`atomicallyMixed` over `TRef`s of
  different value types). Fiber-local `FiberRef` with **auto-propagation** across
  `fork` (inline `Context` slots for `@sizeOf(T) <= 8`).
- A bounded, opt-in **causal event model** (`CausalStore`) with structural /
  finding-evidence / sampleable taxonomy, secret redaction, retention/sampling/
  truncation disclosure, and the structural queries agents rely on.
- The causal **dev loop** and the **closed remediation loop**: `findings()` →
  remediation → `PolicyEngine.decide()` (gate OFF by default) → `ApplyBoundary`
  (action + structural verify) → `applied` earned only when approve AND verify,
  with per-kind executors (retry/interrupt/replace-provider/replay).
- A bounded **agent intervention protocol**: `AgentInterventionPolicy` is
  default-deny/default-record-only, records every request and decision, and only
  emits `remediation_applied` plus an effect event when apply is enabled and the
  action kind is explicitly approved.
- A deterministic **counterfactual trace fork**: `runCounterfactual` replays a
  baseline causal trace into before/after stores, applies an approved
  intervention to the after store, and reports finding deltas plus structural
  equivalence.
- A reusable **causal invariant builder** over graph facts: resource
  acquisition/finalization, suspended-fiber resolution, pending fibers after
  scope close, and assertion failures.
- A first **agent eval harness**: `runAgentEval` scores an intervention by graph
  improvement plus invariant cleanliness rather than prose plausibility.
- **Semantic causal graph diffs.** `diffCausalGraphs` explains which findings,
  fiber terminal facts, resource finalization facts, and lineage edges changed
  between two traces; counterfactuals and evals now carry diff summaries.
- **Visual semantic diff UX.** Workbench artifacts can carry
  `semantic_diff` data and the Solid workbench renders a read-only Diff tab with
  summary counters plus clickable finding/fiber/resource/lineage entries that
  select graph events.
- **Semantic diff artifact emission.** `formatCausalGraphDiffJson` emits the
  portable `zigeffect.causal.semantic-diff.v1` JSON shape consumed by the
  workbench Diff tab.
- **Eval-linked diff artifacts.** `runAgentEvalWithDiffArtifact` returns the
  normal graph-improvement eval result plus a portable
  `zigeffect.causal.agent-eval-diff.v1` artifact with remediation event ids and
  an embedded semantic diff object.
- **Eval diff artifact writer sink.** `runAgentEvalAndWriteDiffArtifact` emits
  the same linked diff artifact to a caller-provided sink, giving dev-loop tools
  a persistence hook without putting filesystem writes in the core service.
- **Eval diff artifact link JSON.** `formatAgentEvalDiffArtifactLinkJson` emits
  `zigeffect.causal.agent-eval-diff-link.v1`, a compact cross-link shape that
  ties persisted eval diff artifacts back to remediation event ids.
- **Linked eval diff artifact writer.**
  `runAgentEvalAndWriteLinkedDiffArtifact` writes both the eval diff artifact
  and its remediation-chain link through caller-owned sinks.
- **Linked eval diff manifest.** `formatAgentEvalLinkedDiffManifestJson` emits
  `zigeffect.causal.agent-eval-linked-manifest.v1` to point at the diff artifact
  and link artifact from one manifest.
- **Linked eval diff manifest writer.**
  `runAgentEvalAndWriteLinkedDiffManifest` writes the eval diff artifact,
  remediation link, and linked manifest through caller-owned sinks in one eval
  flow.
- **Dev-loop linked eval artifact persistence.** The real `causal_loop` after
  phase writes a built-in bounded eval diff artifact, remediation link, and
  linked manifest through the same core writer.
- **Remediation-decision linked eval artifact persistence.** Approved
  `causal-remediation-decision` runs write bounded eval diff, remediation link,
  and linked manifest artifacts beside the decision artifacts through the same
  core manifest writer; rejected decisions stay record-only.
- **Patch-proposal linked eval artifact persistence.** Approved
  `causal-patch-proposal` runs write bounded eval diff, remediation link, and
  linked manifest artifacts beside the proposal artifacts; draft proposals stay
  record-only.
- **Bidirectional live debugging transport primitives.** The Bun collector now
  accepts `POST /command`, broadcasts redacted command frames, and the workbench
  live layer can send bounded command requests. Applying commands still belongs
  to the engine's `AgentInterventionPolicy`.
- **Network-facing collector command inbox.** The collector now retains sanitized
  command frames and exposes `GET /commands?after=<sequence>` so a running engine
  command tap can poll by cursor without binding the core to Bun/WebSocket.
- **Typed command inbox client and core poll bridge.** `fetchLiveCommands`
  validates collector command inbox responses in local tooling, and
  `runCausalLiveCommandPolledBatch` applies decoded command envelopes while
  carrying the next inbox cursor through the engine policy boundary.
- **Local command polling loop.** `runLiveCommandPollingLoop` repeatedly fetches
  collector command batches from local TypeScript tooling, advances the inbox
  cursor, calls a caller-owned handler, and stops on an empty batch or fixed
  poll budget.
- **Local command daemon harness.** `runLiveCommandDaemon` repeats local command
  polling cycles, honors a caller-owned stop signal, awaits a caller-owned delay
  hook between non-empty cycles, and reports cycle/poll/command/error counts.
- **Daemon lifecycle evidence.** `runLiveCommandDaemon` can emit caller-owned
  lifecycle events for start, cycle, error, and stop transitions.
- **Live engine command daemon bridge.** `runLiveEngineCommandDaemon` wires the
  local command daemon to a caller-owned engine bridge, aggregates tap counters,
  and forwards engine-produced `LiveFrame`s to a caller-owned emitter.
- **HTTP live-engine command bridge and frame ingest.**
  `createHttpLiveEngineCommandBridge` posts command batches to a host-owned apply
  endpoint and can forward returned frames to the collector's `POST /frames`
  endpoint for WebSocket broadcast.
- **Live engine apply request adapter.** `serveLiveEngineCommandApplyRequest`
  gives host processes a tested `Request` -> validated command inbox -> engine
  bridge -> JSON response path with fixed JSON/no-store/nosniff headers.
- **Live engine host runner bundle.** `createLiveEngineHost` groups the tested
  host apply request adapter with the local command daemon bridge, so a host
  process can expose `handleApplyRequest(request)` and run collector polling
  through the same caller-owned engine bridge.
- **Supervised live engine host loop.** `runLiveEngineHostSupervisor` wraps a
  host's command daemon in a bounded restart loop, emits lifecycle events, and
  returns aggregate command/apply/frame counters.
- **Continuous NDJSON fact tap.** `runLiveEngineNdjsonTap` reads engine NDJSON
  byte streams, posts complete lines to the collector's ingest endpoint, flushes
  trailing partial lines, and reports chunk/line/post/ingest counts.
- **Live engine host request router.** `serveLiveEngineHostRequest` routes a
  configured apply endpoint to the host bridge, exposes fixed-header JSON health,
  and rejects wrong methods/paths with JSON errors.
- **Live engine host runtime runner.** `runLiveEngineHostRuntime` composes the
  supervised command loop and optional NDJSON fact tap in one host-owned runtime
  call and returns both reports.
- **Bounded live command poll loop.** `runCausalLiveCommandPollLoop` repeatedly
  calls a caller-provided poller up to a fixed limit, applies decoded command
  batches through engine policy, aggregates tap counters, and stops on an empty
  batch.
- **Engine-applied live command executor.** `applyCausalLiveCommand` translates
  bounded command frames into `AgentInterventionRequest`s, invokes
  `AgentInterventionPolicy`, and records unknown command attempts as alert facts.
- **Live engine command tap.** `runCausalLiveCommandTapBatch` processes ordered
  command envelopes through the engine policy boundary and reports processed,
  applied, rejected, and human-review counts.
- **Concurrency and STM annotation helpers.** `CausalConcurrencyRecorder` records
  race winner/loser facts, `both` completion facts, and STM conflict/retry/commit
  facts as causal events.
- **Ops policy core.** `CausalOpsPolicy` validates deployment metadata, checks
  actor/scope read access, and emits retention threshold alerts as causal facts.
- **Ops storage adapter.** `readCausalOpsArtifact` applies `CausalOpsPolicy` to
  NenDB-backed causal artifact reads, and `checkCausalOpsStorageRetention` turns
  durable storage posture into retention decisions plus alert events.
- **Access-controlled ops artifact response.** `formatCausalOpsArtifactResponseJson`
  formats allowed/denied operator artifact reads as redacted JSON, with event
  evidence present only when `CausalOpsPolicy` grants access.
- **HTTP-shaped ops artifact response.** `formatCausalOpsArtifactHttpResponse`
  wraps the same policy-gated JSON in an adapter-friendly status/body pair: 200
  for allowed reads, 403 for denied reads, without hosting an HTTP server in the
  core.
- **Ops artifact HTTP request adapter.** `serveCausalOpsArtifactHttpRequest`
  rejects unsupported methods and paths before delegating valid requests to the
  same policy-gated status/body formatter.
- **Ops artifact response headers.** Ops artifact HTTP responses carry fixed
  `content-type: application/json`, `cache-control: no-store`, and
  `x-content-type-options: nosniff` headers for host adapters to forward.
- **Ops alert/runbook adapter.** `emitCausalOpsAlerts` forwards alert facts to a
  caller-provided sink, and `formatCausalOpsRunbookJson` emits a redacted local
  operator runbook artifact.
- **Ops alert delivery envelope.** `formatCausalOpsAlertDeliveryJson` turns an
  alert fact into redacted `zigeffect.causal.ops-alert-delivery.v1` JSON that
  external delivery adapters can send without seeing raw sentinel text.
- **Ops alert delivery sink.** `deliverCausalOpsAlert` formats the redacted
  delivery envelope and hands it to a caller-provided delivery sink.
- **Ops alert webhook request adapter.** `deliverCausalOpsAlertWebhook` formats a
  redacted alert delivery body, attaches fixed JSON/no-store/nosniff headers,
  and hands the `POST` request shape to a caller-owned HTTP sink.
- **Provider-shaped ops alert requests.** `formatCausalOpsAlertProviderRequest`
  formats generic webhook, Slack webhook, and PagerDuty Events v2 request bodies
  without sending network traffic from the deterministic core.
- **Provider alert secret injection.** `deliverCausalOpsAlertProviderWithSecret`
  resolves PagerDuty routing keys through a caller-owned secret resolver and
  keeps the resolved value limited to the transient outbound request body passed
  to the caller-owned HTTP sink.
- **Provider alert retry reporting.**
  `deliverCausalOpsAlertProviderWithSecretRetrying` retries transient sink
  failures under a bounded policy and returns attempts/delivered/failure
  metadata while rebuilding each transient secret-bearing request per attempt.
- **Endpoint-aware ops runbooks.** `formatCausalOpsRunbookJson` can include
  artifact endpoint path, alert delivery kind, and alert endpoint id metadata for
  live operator surfaces.
- **Multi-runner lineage stitching.** `stitchCausalRunnerLineage` merges
  runner-labeled causal traces and reports cross-runner `cause_event_id` edges as
  structured facts for agents.
- **Runner lineage deployment artifacts.** `formatCausalRunnerLineageJson` emits
  `zigeffect.causal.runner-lineage.v1` with deployment id, runner service/
  environment/region/health/auth metadata, and stitched cross-runner edges.
- **Runner deployment metadata validation.** `validateCausalRunnerDeployments`
  reports missing TLS, missing address, unhealthy runners, and stale auth epochs
  before deployment metadata is trusted as lineage evidence.
- **Transport service-discovery validation.**
  `validateClusterTransportServiceDiscovery` checks discovered remote transport
  endpoints for host, port, TLS, health, and auth epoch before pool candidates
  are trusted.
- **Transport service-discovery selection.**
  `selectClusterTransportServiceDiscoveryEndpoint` chooses the first endpoint
  that satisfies host, port, TLS, health, and auth-epoch requirements while still
  returning the full validation report.
- **In-memory service-discovery registry.**
  `InMemoryClusterTransportServiceDiscovery` owns discovered endpoint host
  strings, supports upsert, and selects safe candidates against the configured
  requirements.
- **External service-discovery snapshot refresh.**
  `refreshFromSnapshot` imports caller-provided discovered endpoints into the
  owned registry and returns source metadata plus the validated selection.
- **Service-discovery snapshot JSON adapter.**
  `parseClusterTransportServiceDiscoverySnapshotJson` parses
  `zigeffect.cluster.service-discovery-snapshot.v1` into an owned snapshot that
  can refresh the local registry safely.
- **File-backed service-discovery snapshot loader.**
  `loadClusterTransportServiceDiscoverySnapshotJsonFile` reads a governed
  snapshot from a caller-provided directory/path and reuses the same owned
  parser plus registry refresh path.
- **HTTP-shaped service-discovery snapshot provider.**
  `formatClusterTransportServiceDiscoveryHttpRequest` and
  `parseClusterTransportServiceDiscoveryHttpResponse` define the fixed `GET`
  request and governed response parser a host-owned HTTP client can use before
  refreshing the local registry.
- **Caller-owned HTTP discovery refresh.**
  `refreshClusterTransportServiceDiscoveryFromHttp` formats the discovery
  request, calls a caller-owned fetcher, parses the governed response, and
  refreshes the in-memory registry while keeping source metadata stable.
- **Bounded HTTP discovery refresh loop.**
  `runClusterTransportServiceDiscoveryHttpRefreshLoop` retries caller-owned
  discovery fetches up to a fixed count, records transient failures, and can stop
  once a safe endpoint is selected.
- **Freshest auth-epoch discovery selection.**
  `selectFreshestClusterTransportServiceDiscoveryEndpoint` keeps the first-safe
  selector intact while offering an auth-rotation-aware choice of the safe
  endpoint with the highest auth epoch.
- **Schema governance for the agentic artifact surface.** The schema governance
  inventory now tracks semantic diff, eval diff, eval diff links, ops artifact
  response, ops runbook, ops alert delivery, and runner lineage artifact
  families.
- App-facing causal traces (`CausalAppTrace`) emitting `zigeffect.causal.v1` from
  Worker-shaped request/job paths.
- Export adapters as sinks (JSONL, DOT, OTel-shaped, **OTLP/JSON**, graph-history,
  NenDB write-contract, async stream) with per-adapter conformance gates.
- **The real zio backend** (`packages/zigeffect-zio`): `blockingSleep` parks a
  coroutine on the event loop; the full `AsyncBackend` vtable is implemented
  (suspend/wake/schedule-timer/interrupt/register-io/complete-io/poll-wake) as a
  registration + wake-queue with real zio timer coroutines; real socket IO via
  `zio.net`. Engine fibers run as interleaving zio coroutines.
- **The workflow scheduler runs on the zio backend.** A `real_clock` capability +
  `WorkflowScheduler.pumpAsyncUntilIdle` reconcile the virtual-clock PULL model
  with zio's real-clock PUSH model (yield the event loop for real timers to fire).
- **Live-attach end-to-end.** `CausalNdjsonTap` streams recorded events as NDJSON;
  a Bun WebSocket collector (`workbench/src/collector/`) maps them to `LiveFrame`s
  and fans out one-per-message; the SolidJS workbench consumes them via
  `?live=ws://…/live`. Proven with real engine bytes through to the client.
- **One real loopback socket transport.** `LoopbackSocketClusterTransport` sends
  the existing `ZIGFX/1` cluster frame over localhost TCP, accepts it on a server
  thread, routes through the same message-storage handler, and parses the response
  frame back through the public transport vtable.
- **A hardened remote socket wrapper.** `RemoteSocketClusterTransport` keeps the
  same socket frame path but adds endpoint validation, auth preflight before
  durable submission, nonzero pool validation, TLS/pool/backpressure policy
  validation, reconnect attempts, origin causal event propagation, lifecycle
  metrics, and redacted failure reports.

## Boundary decisions (intentional non-goals, for now)

- **The core stays zio-free and deterministic-by-default.** Real suspension/IO/
  threads live in `packages/zigeffect-zio` and the `ThreadPoolExecutor`; the core
  `packages/zigeffect` still passes all tests without them, so it remains testable
  without threads, IO, or wall-clock time. `LocalAsyncBackendState` is the
  deterministic reference every real executor is checked against.
- **Thread-pool `interrupt` is cooperative.** OS threads can't be async-preempted,
  so a thread-pool race/both returns the correct result but does not short-circuit
  a loser's work (zio's coroutine cancel does). Documented in the executor.
- **Remote socket transport is still not a deployment platform.**
  `LoopbackSocketClusterTransport` crosses localhost TCP and
  `RemoteSocketClusterTransport` adds the operational envelope for auth,
  retries, and metrics, but long-lived multi-node deployment, TLS, load
  balancing, and full connection pooling remain out of scope.
- **The remediation loop's apply gate is OFF by default** and never mutates source
  unless a human-approved policy turns it on; structural verify is mandatory.
- **Agent interventions are record-only by default.** The runtime records what an
  agent asked for and what the policy decided; it does not apply an effect unless
  the master apply gate and kind policy both allow it.
- `requires` stays Zig-native metadata + validation; `Exit` stays a lightweight
  by-value result.

## The frontier now

The original "single biggest gap" - real async/concurrency under the causal graph
- is **substantially closed**. The second gap - an agent-operable runtime that
can explain and audit its own interventions - now has a tested local substrate
and local operator-facing adapters. The next frontier is turning these local
substrates into real deployed systems:

1. **Network-connected command taps.** `applyCausalLiveCommand`,
   `runCausalLiveCommandTapBatch`, the collector's pollable command inbox,
   typed inbox client, local TypeScript polling loop, local daemon harness with
   lifecycle evidence, core poll bridge, bounded engine poll loop, and
   `runLiveEngineCommandDaemon` bridge exist. Local tooling also has an HTTP
   engine bridge client, host apply request adapter, and collector `POST /frames`
   endpoint, and `createLiveEngineHost` bundles apply handling with collector
   command polling. The supervised host loop and continuous NDJSON fact tap
   exist as testable inner-loop helpers, and the host request router/runtime
   runner now compose those pieces behind local `Request`/runtime boundaries.
   Next is a real long-lived host process with OS-level lifecycle management,
   socket binding, and deployment wiring.
2. **Real multi-node cluster deployment.** The transport validates TLS/pool/
   backpressure policy and propagates origin causal ids, and
   `stitchCausalRunnerLineage` can merge runner traces, emit deployment metadata
   artifacts, validate metadata posture, reject unsafe discovered endpoints,
   select the first safe candidate, keep an in-memory discovery registry, refresh
   it from external discovery snapshots, parse snapshot JSON documents, and load
   governed snapshots from local files. The HTTP-shaped discovery request/
   response seam, caller-owned fetcher refresh helper, bounded refresh loop, and
   freshest-auth selector exist; next are real TLS handshakes, concrete HTTP
   discovery clients, live health-checked pool maintenance, connection pooling,
   and stitched lineage from separate runner processes.
3. **Diff/eval integration.** The workbench renders portable `semantic_diff`
   payloads, evals can emit linked diff artifacts, the new artifact schemas are
   governed, evals can write artifacts to caller sinks, the runtime can write
   remediation-chain artifact links alongside diff artifacts, a manifest can bind
   both artifact paths, one helper can write all three artifacts through caller
   sinks, the real dev-loop after phase persists a bounded smoke eval artifact
   set, approved remediation decisions persist linked eval artifacts beside
   decision artifacts, and approved patch proposals persist linked eval artifacts
   beside proposal artifacts. Next: feed real before/after remediation traces
   into evals and broaden the remaining remediation/app tools.
4. **External operator integrations.** `CausalOpsPolicy`, NenDB reads, alert
   sinks, access-controlled artifact responses, local runbook JSON, alert
   delivery envelopes, delivery-sink hooks, HTTP-shaped artifact responses,
   method/path-gated request adapters, fixed security/cache headers, webhook
   request shapes for alert providers, provider-shaped Slack/PagerDuty bodies,
   provider secret injection, provider retry reporting, and endpoint-aware
   runbooks exist. Next: real network sending, served artifact endpoints,
   deployment metadata ingestion from real deployments, and runbook generation
   from live deployment metadata.

5. **Local agentic development cockpit.** Before any hosted control plane, the
   local workbench must become the place where Codex, Claude Code, and
   zigeffect's own causal tools share development evidence. The first pass
   reuses `zigeffect.causal.dev-session.v1` and teaches the workbench to render
   agents, checks, commands, artifact links, guardrails, and next actions. The
   ordered sequence is M72 through M77 below.

## Local agentic development roadmap

This is the local-first sequence for making zigeffect useful as the development
engine for local projects and standard-library work. It intentionally comes
before hosting or broad distributed orchestration.

Status on 2026-06-25: M72 through M74 are implemented in the workbench and
`causal-dev-session`; M76 and M77 have local JSONL adapter docs/fixtures and a
`bun run zigeffect:local-agent-gate` command. M75 has the local session-event
parser/apply layer; the remaining live step is wiring those events through the
collector WebSocket so the Agents tab updates during an active stream.

### M72 - Local development session protocol

**Goal:** normalize existing dev-session receipts into a workbench-native local
session model.

**Work:**
- Reuse `zigeffect.causal.dev-session.v1`.
- Add a Solid workbench parser/model for session goal, phase, agents, checks,
  commands, artifact links, next actions, guardrails, and warnings.
- Derive useful fallback agents/checks from existing command records so older
  receipts render.

**Acceptance:**
- Existing session receipts parse without migration.
- Extended receipts parse with explicit agent/check rows.
- Partial receipts render as an empty or degraded local session, not a crash.

### M73 - Workbench agent cockpit view

**Goal:** give local agentic development a first-class read-only workbench tab.

**Work:**
- Add an Agents tab to the existing workbench.
- Render local session status, agents, checks, commands, artifacts, guardrails,
  and next actions.
- Keep non-session artifacts usable by showing an empty state.

**Acceptance:**
- The Agents tab appears beside Timeline, Graph, Diff, Chain, Queries, and
  Metadata.
- A dev-session artifact is visually inspectable from the workbench without
  leaving the local machine.

### M74 - Dogfood session receipt enrichment

**Goal:** make `causal-dev-session` emit enough structure for Codex/Claude/
zigeffect local runs to be reviewed by another agent.

**Work:**
- Add deterministic session identity, title, goal, agent records, and check
  receipts to the JSON artifact.
- Keep existing command and artifact fields stable.
- Update text receipts with concise local-agent status.

**Acceptance:**
- `start`, `assess`, missing-baseline, and failure paths all emit valid enriched
  receipts.
- Zig tests cover JSON and text output.

### M75 - Live agent runtime feed

**Goal:** let live local workbench sessions show agent state changes while engine
NDJSON is streaming.

**Work:**
- Define local session frames for agent start/stop, tool run, check result, graph
  query, and verification.
- Route frames through the existing collector redaction boundary.
- Update the workbench session model from live frames.

**Acceptance:**
- A live session updates the Agents tab without a static artifact reload.
- Secret-shaped frame fields are redacted before browser delivery.

### M76 - Local Codex and Claude Code adapters

**Goal:** represent external local agents without building a hosting platform.

**Work:**
- Define a small append-only JSONL or JSON adapter contract.
- Add fixtures and parser tests for Codex and Claude Code activity.
- Document ownership, redaction, and failure semantics.

**Acceptance:**
- A Codex or Claude Code local run can be shown as an agent in the workbench.
- Adapter ingestion is local-file or stdin based.

### M77 - Local reliability gate

**Goal:** make a local session honest enough for another agent to continue.

**Work:**
- Add one local verification command that checks session parsing, Zig
  dev-session receipts, redaction, hygiene, and required artifact links.
- Extend the existing honesty gate only for stale local-session claims and
  missing evidence.

**Acceptance:**
- The gate fails on stale session status claims, leaked sentinel secrets, or
  missing artifact evidence.
- The gate requires no network access.

## Hardening milestone roadmap

This is the next work sequence. It deliberately hardens the proof surface before
adding broad product surface area.

### M0 — Status truth and roadmap hygiene

**Goal:** keep the repository's claims internally consistent while the project
moves quickly.

**Work:**
- Fix stale comments/docs as they are found, especially statements that say a
  shipped collector, backend method, or scheduler path is "not yet built".
- Keep `roadmap.md`, the future-agent briefing, package READMEs, and workbench
  comments aligned on the current frontier.
- Extend the honesty gate only when it prevents a real failure mode; avoid new
  report-only tools.

**Acceptance:**
- Targeted `rg` sweeps show no current docs contradict the live collector,
  scheduler-on-zio, structural-equivalence definition, or tool hygiene policy.
- `tools/check_tool_hygiene.sh` still passes.

### M1 — Stronger structural equivalence

**Status:** initial hardening delivered on 2026-06-24. The comparator now rejects
parent-lineage, resource-pairing, fiber-scope ownership, and finding-owner false
positives while preserving the existing executor-equivalence suite.

**Goal:** make the three-executor invariant harder to fake by comparing more of
the causal graph shape.

**Work:**
- Add regression traces that the current comparator falsely accepts.
- Expand `causalStructurallyEquivalent` beyond event-kind, cause-kind, and
  terminal-fiber facts to include parent/lineage shape, scope/resource lifecycle
  pairings, fiber ownership, interruption/finalizer facts, and important
  finding-evidence ownership.
- Keep ids and scheduler order abstract; compare semantic structure, not exact
  event numbers.

**Acceptance:**
- Tests reject mismatched parent trees with the same event kinds.
- Tests reject resources finalized under the wrong scope/resource identity.
- Tests reject fiber lifecycle events that have the same terminal state but
  belong to different scope/parent structure.
- Tests reject missing or reassigned finding-evidence ownership where the event
  taxonomy says the event matters diagnostically.
- Existing deterministic/zio/thread-pool structural-equivalence tests stay green.

### M2 — Live debugging browser proof

**Status:** browser proof delivered on 2026-06-24 at
`docs/superpowers/specs/2026-06-24-zigeffect-live-debugging-browser-proof.md`.
Automated collector-to-WebSocket-client coverage exists, and the proof doc now
includes a captured workbench screenshot from the live collector stream.

**Goal:** prove the browser debugging path, not only the collector contract.

**Work:**
- Exercise engine NDJSON -> Bun collector -> WebSocket -> Solid workbench render.
- Prefer an automated Bun/Playwright DOM test; if browser automation is blocked,
  add a repeatable visual proof doc with exact commands and screenshots.
- Fix live-attach docs/comments while touching the path.

**Acceptance:**
- A real live frame appears in the workbench timeline/graph DOM from a collector
  WebSocket, not from a static `?sample=` fixture.
- The verification artifact records exact commands, ports, and expected visible
  UI state.

### M3 — One real loopback cluster transport

**Status:** initial core transport delivered on 2026-06-24 via
`LoopbackSocketClusterTransport`; it crosses localhost TCP and preserves envelope
fields through the existing `ClusterTransport` vtable. A regression test compares
an in-process transport trace to the loopback socket trace with
`causalStructurallyEquivalent`.

**Goal:** cross the distributed boundary once without broadening into a full
deployment platform.

**Work:**
- Put a loopback TCP/socket transport behind the existing `ClusterTransport`
  shape, preferably in the zio adapter where real socket IO already lives.
- Compare the same cluster scenario through in-memory and loopback transports.
- Keep serialization, backpressure, timeout, and shutdown semantics explicit.

**Acceptance:**
- A loopback transport conformance test sends and receives real socket bytes.
- The in-memory and loopback runs produce structurally-equivalent causal traces.
- Transport errors redact endpoint credentials and produce actionable causal
  events.

### M4 — Secret and trace redaction hardening

**Status:** delivered on 2026-06-24. Sentinel coverage now spans stored causal
events, reports, JSON, DOT, JSONL, NDJSON live-feed bytes, OTel/OTLP payloads,
transport auth metadata, and workbench `LiveFrame` labels.

**Goal:** prevent real transport/storage work from leaking credentials into
causal artifacts, workbench payloads, or exported traces.

**Work:**
- Add sentinel-secret tests that inject fake API keys, bearer tokens, cookies,
  database URLs, and passwords into event labels/details and transport/storage
  metadata.
- Assert JSONL, DOT/tooltip text, OTLP/JSON, live frames, CI reports, and
  workbench-facing artifacts do not contain the sentinel strings.
- Redact at the causal boundary rather than only in one exporter.

**Acceptance:**
- A single sentinel corpus proves known secret shapes do not escape any supported
  causal export path.
- Regression tests fail if a new exporter bypasses the redaction boundary.

### M5 — Broader agent honesty gate

**Status:** delivered on 2026-06-24. `check_tool_hygiene.sh` now rejects known
stale current-status claims, caps report-named tool proliferation, and carries
regression fixtures for stale docs and repeated report-tool naming.

**Goal:** catch motion-shaped work before it reaches the repo.

**Work:**
- Extend the existing hygiene checker with narrow checks for stale status claims,
  generated-report proliferation, and forbidden "future/not yet" contradictions
  in current docs.
- Keep the gate small, source-backed, and cheap to run in CI/pre-commit.
- Prefer editing `src/` with tests over adding tools; any new tool must satisfy
  the runtime-import rule.

**Acceptance:**
- CI fails on a current-status doc that claims a shipped capability is missing.
- CI fails on repeated report-tool naming patterns before line-count limits are
  reached.
- The gate has regression tests and does not require network access.

### M6 — Agent intervention protocol

**Status:** delivered on 2026-06-24 via
`src/services/agent_intervention.zig`.

**Goal:** let an agent request bounded runtime actions without letting it claim
or perform mutations that policy did not approve.

**Work:**
- Add a fixed intervention action set: interrupt fiber, fire timer, pause runner,
  replace provider, replay scenario, and inject failure.
- Record `remediation_requested` and `remediation_decided` for every request.
- Keep the default policy record-only; emit `remediation_applied` plus an
  action-specific effect event only when apply is enabled and the kind policy is
  auto-approved.

**Acceptance:**
- Default policy records request/decision but no apply/effect event.
- Approved `interrupt_fiber` records request, decision, apply, and
  `fiber_interrupted`.

### M7 — Counterfactual re-executor

**Status:** delivered on 2026-06-24 via `src/services/counterfactual.zig`.

**Goal:** let an agent test a proposed intervention against a deterministic
causal trace fork before treating it as improvement.

**Work:**
- Replay a baseline trace into before/after `CausalStore`s.
- Apply an approved intervention only to the after store.
- Return finding counts, finding delta, structural equivalence, and an
  `improved` bit.

**Acceptance:**
- A suspended-fiber baseline plus an approved interrupt reduces findings and
  reports `improved = true`.

### M8 — Runtime invariant DSL

**Status:** delivered on 2026-06-24 via `src/services/causal_invariant.zig`.

**Goal:** give agents reusable graph checks without introducing a separate
invariant language.

**Work:**
- Add a Zig builder for resource finalization, suspended-fiber resolution,
  pending fibers after scope close, and assertion failures.
- Return structured `CausalInvariantViolation` records.

**Acceptance:**
- The builder detects unfinalized resources, unresolved suspended fibers, and
  pending fibers at scope close.
- The builder passes when resource and fiber lifecycles close.

### M9 — Remote socket transport hardening

**Status:** delivered on 2026-06-24 via `RemoteSocketClusterTransport`.

**Goal:** close more of the real transport gap without jumping to a distributed
platform.

**Work:**
- Add a remote-socket wrapper behind the existing `ClusterTransport` shape.
- Validate endpoint, auth, limits, pool size, and reconnect attempts before
  durable submission.
- Record metrics and redacted failures through the production-socket transport
  kind.

**Acceptance:**
- Wrong auth is rejected before durable submission.
- Matching auth sends over the socket path and updates metrics.

### M10 — Agent eval harness

**Status:** delivered on 2026-06-24 via `src/services/agent_eval.zig`.

**Goal:** score debugging agents by graph improvement and invariant cleanliness.

**Work:**
- Compose the counterfactual re-executor with the invariant builder.
- Pass only when the intervention is applied, expected improvement holds, and
  no invariant violations remain.

**Acceptance:**
- Approved interrupt over a suspended-fiber trace passes.
- Denied policy does not pass.

### M11 — Semantic causal graph diffs

**Status:** delivered on 2026-06-24 via `src/services/causal_diff.zig`.

**Goal:** explain what changed between two causal traces in graph facts, not only
finding counts.

**Work:**
- Compare resolved/introduced findings.
- Compare added/removed fiber terminal facts.
- Compare added/removed resource finalization facts.
- Compare added/removed parent/cause lineage facts.
- Feed diff summaries into counterfactual and agent eval results.

**Acceptance:**
- A before/after trace with an interrupted hung fiber and finalized resource
  reports resolved findings, terminal fiber facts, resource finalization, and
  added lineage edges.

### M12 — Bidirectional live debugging command lane

**Status:** delivered on 2026-06-24 via the workbench live attach and collector.

**Goal:** let the browser/collector carry bounded intervention requests without
making the browser the policy authority.

**Work:**
- Add `LiveCommandRequest` and `LiveCommandFrame`.
- Add `sendLiveCommand` with injectable fetcher.
- Add collector `POST /command` that validates shape, redacts command text, and
  broadcasts command frames to live subscribers.

**Acceptance:**
- Workbench tests parse command frames and post commands.
- Collector tests prove `POST /command` broadcasts a redacted command frame.

### M13 — Race/both and STM causal annotations

**Status:** delivered on 2026-06-24 via `src/services/causal_concurrency.zig`.

**Goal:** expose important concurrency decisions as causal facts agents can
query.

**Work:**
- Add event kinds for race start, winner selection, loser interruption,
  `both` start/completion, and STM transaction/conflict/retry/commit.
- Add `CausalConcurrencyRecorder` to record those facts into a `CausalStore`.

**Acceptance:**
- Tests prove race, both, and STM retry facts are recorded with run/scope/fiber
  ownership.

### M14 — Remote transport policy hardening

**Status:** delivered on 2026-06-24 via `RemoteSocketClusterTransport` policy
extensions.

**Goal:** add real deployment policy seams without pretending this is already a
hosted multi-node platform.

**Work:**
- Add TLS policy metadata, connection pool policy, and backpressure policy.
- Validate TLS/pool policy at init.
- Reject sends under reject-style backpressure before durable submission.
- Propagate `origin_causal_event_id` through request/response JSON and message
  envelopes.

**Acceptance:**
- Tests reject invalid TLS and pool policy.
- Tests reject backpressured sends before storage submission.
- Tests preserve origin causal ids across the socket path.

### M15 — Durable retention and ops hardening

**Status:** delivered on 2026-06-24 via `src/services/causal_ops.zig`.

**Goal:** create a small tested policy core for deployment metadata, causal
artifact access, retention decisions, and alert emission.

**Work:**
- Validate deployment metadata before access checks pass.
- Check actor/scope read access.
- Decide retention trim/keep actions.
- Emit `alert_emitted` causal facts for retention threshold breaches.

**Acceptance:**
- Tests prove actor/scope access decisions.
- Tests prove retention threshold alerts are recorded in the causal graph.

### M16 — Engine-applied live command executor

**Status:** delivered on 2026-06-24 via
`src/services/causal_live_command.zig`.

**Goal:** make live command frames executable by the engine without moving
policy authority into the browser or collector.

**Work:**
- Add `CausalLiveCommandRequest` and `CausalLiveCommandResult`.
- Translate known command kinds into `AgentInterventionRequest`s.
- Invoke `AgentInterventionPolicy` for every known command.
- Record unknown command attempts as `alert_emitted` facts.

**Acceptance:**
- Tests prove an approved `interrupt_fiber` command records request, decision,
  apply, and effect facts.
- Tests prove an unknown command is rejected and recorded as alert evidence.

### M17 — Visual semantic diff UX

**Status:** delivered on 2026-06-24 in the Solid workbench.

**Goal:** let humans and agents inspect graph diff evidence from portable
artifacts, not only Zig APIs.

**Work:**
- Add `deriveSemanticDiffModel` for embedded `semantic_diff` payloads.
- Add a read-only Diff tab to the workbench.
- Render summary counters plus finding, fiber, resource, and lineage entries.

**Acceptance:**
- Workbench tests parse a semantic diff artifact and expose the Diff tab.
- Workbench typecheck passes with the new model and UI.

### M18 — Durable ops storage adapter

**Status:** delivered on 2026-06-24 via
`src/services/causal_ops_storage.zig`.

**Goal:** attach ops policy to durable causal artifact reads and retention
checks over the existing NenDB-backed storage state.

**Work:**
- Add `readCausalOpsArtifact` for policy-gated full or scoped snapshots.
- Add `checkCausalOpsStorageRetention` to map storage posture into
  `CausalOpsPolicy`.
- Keep the adapter local and explicit; no hosted ops service is implied.

**Acceptance:**
- Tests prove unauthorized reads return no snapshot.
- Tests prove authorized scoped reads return only the requested scope.
- Tests prove retention threshold checks emit alert facts.

### M19 — Multi-runner causal lineage stitcher

**Status:** delivered on 2026-06-24 via
`src/services/causal_runner_lineage.zig`.

**Goal:** make cross-runner causal origin queryable before building a full
multi-node deployment platform.

**Work:**
- Add runner-labeled trace inputs.
- Merge cloned event snapshots.
- Report cross-runner `cause_event_id` edges as structured lineage facts.

**Acceptance:**
- Tests prove a response event from one runner can be stitched back to a cause
  event recorded by another runner.

### M20 — Live engine command tap

**Status:** delivered on 2026-06-24 via
`src/services/causal_live_command.zig`.

**Goal:** process ordered live command batches through the engine's policy
boundary without binding the core to a particular transport.

**Work:**
- Add command envelopes with sequence numbers.
- Add a batch tap runner over `applyCausalLiveCommand`.
- Report processed, applied, rejected, and human-review counts.

**Acceptance:**
- Tests prove a batch with an approved command and an unknown command records
  both the intervention facts and alert evidence.

### M21 — Zig semantic diff artifact emission

**Status:** delivered on 2026-06-24 via `formatCausalGraphDiffJson`.

**Goal:** emit the same portable semantic diff artifact shape that the workbench
renders.

**Work:**
- Add `zigeffect.causal.semantic-diff.v1` JSON formatting.
- Include summary counters and finding/fiber/resource/lineage sections.

**Acceptance:**
- Tests prove a graph diff formats parseable JSON with before/after labels,
  summary counts, resource finalization entries, and lineage entries.

### M22 — Graph-linked Diff UX

**Status:** delivered on 2026-06-24 in the Solid workbench.

**Goal:** make diff evidence navigable, not only readable.

**Work:**
- Add selectable event-id extraction for semantic diffs.
- Convert Diff entries to read-only selection buttons.
- Reuse the existing selected-event state.

**Acceptance:**
- Workbench tests prove selectable event ids are derived from diff evidence.
- Workbench tests/typecheck pass with clickable Diff rows.

### M23 — Ops alert sink and runbook artifact

**Status:** delivered on 2026-06-24 via
`src/services/causal_ops_alert.zig`.

**Goal:** turn local alert facts and ops posture into operator-facing evidence.

**Work:**
- Add callback-based alert sinks.
- Emit only `alert_emitted` causal facts to the sink.
- Format redacted `zigeffect.causal.ops-runbook.v1` JSON.

**Acceptance:**
- Tests prove alert sinks receive alert facts only.
- Tests prove runbook JSON summarizes deployment/retention posture without
  leaking sentinel secrets.

### M24 — Collector command inbox

**Status:** delivered on 2026-06-24 in the Bun live-attach collector.

**Goal:** give a running engine tap a network-facing command cursor without
binding the Zig core to Bun or WebSocket.

**Work:**
- Retain sanitized command frames posted to `POST /command`.
- Add `commandsSince(afterSequence)` for in-process tests.
- Add `GET /commands?after=<sequence>` returning `{ commands, next_after }`.

**Acceptance:**
- Collector tests prove two posted commands can be polled by sequence and an
  up-to-date cursor returns an empty command batch.

### M25 — Eval-linked semantic diff artifact

**Status:** delivered on 2026-06-24 via `runAgentEvalWithDiffArtifact`.

**Goal:** make eval evidence portable and cross-linked to remediation events.

**Work:**
- Keep `runAgentEval` as the lightweight result-only API.
- Add `zigeffect.causal.agent-eval-diff.v1` JSON artifact emission.
- Embed the portable semantic diff object and remediation requested/decided/
  applied/effect event ids.

**Acceptance:**
- Tests prove the artifact includes the eval schema, embedded semantic diff,
  resolved finding count, and remediation event links.

### M26 — Access-controlled ops artifact response

**Status:** delivered on 2026-06-24 via
`formatCausalOpsArtifactResponseJson`.

**Goal:** turn policy-gated NenDB reads into an operator-facing JSON response
without leaking event evidence to denied readers.

**Work:**
- Format allowed/denied artifact read results as
  `zigeffect.causal.ops-artifact-response.v1`.
- Include compact event evidence only when `CausalOpsPolicy` permits the read.
- Redact sentinel-like labels/status/type names before they leave the endpoint
  response shape.

**Acceptance:**
- Tests prove denied responses omit events and allowed responses redact sentinel
  secrets while reporting the expected event count.

### M27 — Runner lineage deployment artifact

**Status:** delivered on 2026-06-24 via
`formatCausalRunnerLineageJson`.

**Goal:** preserve deployment context around stitched multi-runner causal edges.

**Work:**
- Add runner deployment metadata for service/environment/region/address/health,
  TLS flag, and auth epoch.
- Emit `zigeffect.causal.runner-lineage.v1` with deployment id, event count,
  cross-runner edge count, runner metadata, and stitched edges.

**Acceptance:**
- Tests prove the artifact includes deployment id, runner metadata, TLS/auth
  fields, and cross-runner edge endpoints.

### M28 — Typed command inbox client

**Status:** delivered on 2026-06-24 in the workbench live attach module.

**Goal:** make command inbox polling a validated client contract, not a loose
`fetch` convention.

**Work:**
- Add `LiveCommandInboxResponse` and `isLiveCommandInboxResponse`.
- Add `fetchLiveCommands(url, afterSequence)` to append the cursor and validate
  returned command frames.

**Acceptance:**
- Tests prove valid inbox responses are accepted, invalid command frames are
  rejected, and the `after` cursor is sent on the request URL.

### M29 — Core polled command batch bridge

**Status:** delivered on 2026-06-24 via
`runCausalLiveCommandPolledBatch`.

**Goal:** let decoded collector inbox batches cross into the engine policy
boundary with cursor accounting.

**Work:**
- Add `CausalLiveCommandPollBatch` and `CausalLiveCommandPollResult`.
- Run decoded envelopes through `runCausalLiveCommandTapBatch`.
- Return the next inbox cursor alongside the tap summary.

**Acceptance:**
- Tests prove a polled command applies through policy and returns the expected
  cursor plus tap counters.

### M30 — Schema governance for agentic artifacts

**Status:** delivered on 2026-06-24 in `causal_schema_governance.zig`.

**Goal:** keep the growing artifact surface discoverable and reviewable without
creating new report-only tools.

**Work:**
- Register `semantic-diff`, `agent-eval-diff`, `ops-artifact-response`,
  `ops-runbook`, `ops-alert-delivery`, and `runner-lineage` schemas.
- Update schema governance tests and report counts.

**Acceptance:**
- Tests prove the inventory includes 42 schemas and the new artifact families
  appear in text and JSON governance reports.

### M31 — Ops alert delivery envelope

**Status:** delivered on 2026-06-24 via
`formatCausalOpsAlertDeliveryJson`.

**Goal:** provide a redacted payload contract for external alert adapters without
sending alerts from the core.

**Work:**
- Add `zigeffect.causal.ops-alert-delivery.v1`.
- Include deployment, endpoint, delivery kind, and alert event evidence.
- Redact sensitive alert text before formatting.

**Acceptance:**
- Tests prove the envelope contains delivery metadata and event id while
  redacting sentinel secrets.

### M32 — Bounded command poll loop

**Status:** delivered on 2026-06-24 via
`runCausalLiveCommandPollLoop`.

**Goal:** provide the repeatable command polling core a real daemon can call
without embedding network or process-supervision concerns in the core.

**Work:**
- Add a callback-based `CausalLiveCommandPoller`.
- Poll up to `max_polls`, apply decoded batches through engine policy, aggregate
  tap counters, and stop on an empty batch.

**Acceptance:**
- Tests prove multiple batches are processed, cursors advance, and the loop stops
  after an empty batch.

### M33 — Eval diff artifact writer sink

**Status:** delivered on 2026-06-24 via
`runAgentEvalAndWriteDiffArtifact`.

**Goal:** let dev-loop tools persist linked eval diff artifacts without learning
eval internals or putting filesystem writes in the core service.

**Work:**
- Add `AgentEvalDiffArtifactSink`.
- Wrap `runAgentEvalWithDiffArtifact`, write the JSON artifact to the sink, and
  return the normal eval result.

**Acceptance:**
- Tests prove the sink receives the eval diff artifact and that the eval result
  still passes.

### M34 — Runner deployment metadata validation

**Status:** delivered on 2026-06-24 via
`validateCausalRunnerDeployments`.

**Goal:** make deployment metadata reviewable before stitched lineage artifacts
are treated as deployment evidence.

**Work:**
- Add validation requirements for TLS, address, healthy state, and minimum auth
  epoch.
- Return a compact count-based validation report.

**Acceptance:**
- Tests prove missing TLS, missing address, unhealthy runners, and stale auth
  epochs are reported.

### M35 — Ops alert delivery sink

**Status:** delivered on 2026-06-24 via `deliverCausalOpsAlert`.

**Goal:** bridge redacted alert delivery envelopes to caller-owned external
delivery adapters without sending alerts directly from the core.

**Work:**
- Add `CausalOpsAlertDeliverySink`.
- Format the redacted delivery envelope and pass it to the sink.

**Acceptance:**
- Tests prove the sink receives the delivery schema and does not see sentinel
  secrets.

### M36 — Local command polling loop

**Status:** delivered on 2026-06-24 via `runLiveCommandPollingLoop`.

**Goal:** let local tooling repeatedly poll the collector command inbox without
inventing a daemon or binding the Zig core to Bun.

**Work:**
- Add a TypeScript async loop around `fetchLiveCommands`.
- Advance the command cursor, call a caller-provided handler, and stop on empty
  batches or `maxPolls`.

**Acceptance:**
- Tests prove multiple command batches are handled, cursors advance, and polling
  stops when an empty batch arrives.

### M37 — Eval diff artifact remediation link

**Status:** delivered on 2026-06-24 via
`formatAgentEvalDiffArtifactLinkJson`.

**Goal:** give remediation chains a compact, governed JSON reference to persisted
eval diff artifacts without embedding whole artifacts everywhere.

**Work:**
- Add `zigeffect.causal.agent-eval-diff-link.v1`.
- Include artifact path/id, pass/fail state, remediation event ids, and diff
  summary counts.
- Register the schema in causal schema governance.

**Acceptance:**
- Tests prove the link includes the artifact path and remediation event ids, and
  schema governance tracks the new artifact family.

### M38 — Remote transport service discovery validation

**Status:** delivered on 2026-06-24 via
`validateClusterTransportServiceDiscovery`.

**Goal:** check discovered remote transport endpoints before they become
connection-pool candidates.

**Work:**
- Add endpoint facts for host, port, TLS, health, and auth epoch.
- Return a compact count-based validation report for unsafe candidates.

**Acceptance:**
- Tests prove missing host, invalid port, missing TLS, unhealthy endpoints, and
  stale auth epochs are reported.

### M39 — HTTP-shaped ops artifact response

**Status:** delivered on 2026-06-24 via
`formatCausalOpsArtifactHttpResponse`.

**Goal:** provide adapter-ready status/body semantics for policy-gated ops
artifact reads without hosting HTTP inside the core service.

**Work:**
- Wrap `formatCausalOpsArtifactResponseJson` in a status/body response object.
- Return 200 for allowed reads and 403 for denied reads.

**Acceptance:**
- Tests prove allowed reads return 200 with event counts and denied reads return
  403 without event bodies.

### M40 — Local command daemon harness

**Status:** delivered on 2026-06-24 via `runLiveCommandDaemon`.

**Goal:** provide the reusable local loop a real engine-side process wrapper can
call without introducing process supervision into the workbench module.

**Work:**
- Compose repeated `runLiveCommandPollingLoop` cycles.
- Honor a caller-owned stop signal and delay hook.
- Return cycle, poll, command, cursor, and error counters.

**Acceptance:**
- Tests prove cursors advance across cycles, the delay hook runs between
  non-empty cycles, and the stop signal terminates the harness.

### M41 — Linked eval diff artifact writer

**Status:** delivered on 2026-06-24 via
`runAgentEvalAndWriteLinkedDiffArtifact`.

**Goal:** let dev-loop callers persist eval diff artifacts and remediation-chain
links together through caller-owned sinks.

**Work:**
- Add link write options.
- Write the eval diff artifact, format the link from the same result, and write
  the link artifact.

**Acceptance:**
- Tests prove both schemas are written and the link contains remediation event
  ids plus the artifact path.

### M42 — Service-discovery endpoint selection

**Status:** delivered on 2026-06-24 via
`selectClusterTransportServiceDiscoveryEndpoint`.

**Goal:** turn validation into a first usable candidate-selection primitive.

**Work:**
- Return the full validation report.
- Select the first endpoint satisfying host, port, TLS, health, and auth epoch.

**Acceptance:**
- Tests prove unsafe candidates are skipped and all-unsafe candidate sets select
  nothing.

### M43 — Ops artifact HTTP request adapter

**Status:** delivered on 2026-06-24 via
`serveCausalOpsArtifactHttpRequest`.

**Goal:** provide host adapters with method/path-gated artifact read semantics
without hosting HTTP inside the core.

**Work:**
- Reject non-GET requests with 405.
- Reject unsupported paths with 404.
- Delegate valid requests to `formatCausalOpsArtifactHttpResponse`.

**Acceptance:**
- Tests prove 405, 404, 403, and 200 responses are produced for method, path,
  policy-denied, and policy-allowed cases.

### M44 — Daemon lifecycle evidence

**Status:** delivered on 2026-06-24 via `runLiveCommandDaemon`.

**Goal:** make local command daemon runs observable without owning a process
supervisor in the workbench module.

**Work:**
- Add `onLifecycle` events for start, cycle, error, and stop.
- Keep lifecycle delivery caller-owned.

**Acceptance:**
- Tests prove lifecycle events are emitted in order.

### M45 — In-memory service-discovery registry

**Status:** delivered on 2026-06-24 via
`InMemoryClusterTransportServiceDiscovery`.

**Goal:** provide a real local service-discovery backend before an external
registry exists.

**Work:**
- Own endpoint host strings.
- Upsert endpoints by host/port.
- Select a safe candidate using service-discovery requirements.

**Acceptance:**
- Tests prove upsert replaces endpoints and selection sees the safe candidate.

### M46 — Linked eval diff manifest

**Status:** delivered on 2026-06-24 via
`formatAgentEvalLinkedDiffManifestJson`.

**Goal:** give dev-loop tools one manifest that references both eval diff and
remediation-link artifacts.

**Work:**
- Add `zigeffect.causal.agent-eval-linked-manifest.v1`.
- Include flat artifact paths and remediation event ids.
- Register the schema in governance.

**Acceptance:**
- Tests prove both artifact paths and remediation ids appear, and schema
  governance tracks the manifest.

### M47 — Ops HTTP response headers

**Status:** delivered on 2026-06-24 via `CausalOpsArtifactHttpResponse`.

**Goal:** make host adapters forward safe, cache-resistant response metadata.

**Work:**
- Add fixed JSON/no-store/nosniff headers to all ops artifact HTTP responses.

**Acceptance:**
- Tests prove allowed, denied, method-error, and path-error responses carry the
  expected headers.

### M48 — Live engine command daemon bridge

**Status:** delivered on 2026-06-24 via `runLiveEngineCommandDaemon`.

**Goal:** connect the local collector polling daemon to a caller-owned running
engine bridge without importing Zig into the workbench tooling.

**Work:**
- Delegate non-empty command inbox batches to a caller-owned `applyBatch`.
- Aggregate processed/applied/rejected/human-review counts.
- Forward engine-produced `LiveFrame`s to a caller-owned emitter.

**Acceptance:**
- Bun tests prove command batches are applied, causal frames are emitted, and tap
  counters are aggregated.

### M49 — External service-discovery snapshot refresh

**Status:** delivered on 2026-06-24 via
`InMemoryClusterTransportServiceDiscovery.refreshFromSnapshot`.

**Goal:** let external discovery providers feed the local registry as data while
preserving deterministic validation and selection.

**Work:**
- Add a snapshot shape with source and observation metadata.
- Upsert snapshot endpoints into the owned registry.
- Return source/import counts, registry size, and validated endpoint selection.

**Acceptance:**
- Tests prove a snapshot imports unsafe and safe endpoints, keeps source
  metadata, and selects the safe endpoint.

### M50 — Linked eval diff manifest writer

**Status:** delivered on 2026-06-24 via
`runAgentEvalAndWriteLinkedDiffManifest`.

**Goal:** make dev-loop/remediation artifact persistence one call rather than
three duplicated sink writes.

**Work:**
- Run the eval and build the existing semantic diff artifact.
- Write diff artifact, remediation link artifact, and linked manifest through
  caller-owned sinks.

**Acceptance:**
- Tests prove one eval call writes exactly one diff, one link, and one manifest
  artifact with the expected schema/path evidence.

### M51 — Ops alert webhook request adapter

**Status:** delivered on 2026-06-24 via `deliverCausalOpsAlertWebhook`.

**Goal:** give external alert providers a redacted HTTP request shape without
embedding network IO in the deterministic core.

**Work:**
- Format a `POST` request with fixed JSON/no-store/nosniff headers.
- Use the existing redacted `ops-alert-delivery.v1` body.
- Send the request shape to a caller-owned HTTP sink.

**Acceptance:**
- Tests prove the request method, endpoint, headers, schema body, and sentinel
  redaction.

### M52 — HTTP live-engine bridge and frame ingest

**Status:** delivered on 2026-06-24 via
`createHttpLiveEngineCommandBridge` and collector `POST /frames`.

**Goal:** give a real running engine host a local HTTP contract for applying
collector command batches and streaming mapped facts back to the browser.

**Work:**
- Validate engine apply responses with tap counters and `LiveFrame`s.
- Post command inbox batches to a host-owned apply endpoint.
- Let the collector broadcast already-mapped `LiveFrame` JSON via `POST /frames`.

**Acceptance:**
- Bun tests prove command batches are posted, returned frames are validated and
  posted, and WebSocket clients receive `POST /frames` payloads.

### M53 — Service-discovery snapshot JSON adapter

**Status:** delivered on 2026-06-24 via
`parseClusterTransportServiceDiscoverySnapshotJson`.

**Goal:** let concrete discovery providers feed the transport registry through a
stable JSON snapshot shape.

**Work:**
- Add `zigeffect.cluster.service-discovery-snapshot.v1`.
- Parse snapshots into owned endpoint host storage with explicit `deinit`.
- Refresh the existing in-memory registry from the parsed snapshot.

**Acceptance:**
- Tests prove parsed JSON imports endpoints and selects the safe endpoint through
  the existing validation requirements.

### M54 — Dev-loop linked eval artifact persistence

**Status:** delivered on 2026-06-24 via `causal_loop` after-phase eval artifact
writing.

**Goal:** make the real dev-loop persist linked eval diff artifacts using the
core manifest writer.

**Work:**
- Add stable eval diff/link/manifest paths to dev-loop artifacts.
- Run a bounded built-in suspended-fiber smoke eval during the after phase.
- Write diff, link, and manifest artifacts through
  `runAgentEvalAndWriteLinkedDiffManifest`.

**Acceptance:**
- Tool tests prove the manifest is written with the expected schema and artifact
  paths, and `zig build examples` includes the tool test.

### M55 — Operator runbook endpoint metadata

**Status:** delivered on 2026-06-24 via `CausalOpsRunbookEndpointMetadata`.

**Goal:** let runbooks point operators at the artifact endpoint and alert
provider seam used by a live deployment.

**Work:**
- Add optional endpoint metadata to `CausalOpsRunbookOptions`.
- Render artifact endpoint path, alert delivery kind, and alert endpoint id.

**Acceptance:**
- Tests prove runbook JSON includes endpoint metadata without breaking existing
  retention/redaction output.

### M56 — Live engine apply request adapter

**Status:** delivered on 2026-06-24 via
`serveLiveEngineCommandApplyRequest`.

**Goal:** give engine host processes a tested local HTTP apply endpoint adapter
without moving policy authority into the workbench or collector.

**Work:**
- Validate `LiveCommandInboxResponse` request bodies.
- Delegate valid batches to a caller-owned `LiveCommandEngineBridge`.
- Return validated `LiveCommandEngineBatchResult` JSON with fixed security/cache
  headers.

**Acceptance:**
- Bun tests prove valid batches call the bridge and invalid methods/payloads are
  rejected with JSON errors.

### M57 — Remediation decision eval artifact persistence

**Status:** delivered on 2026-06-24 via
`causal-remediation-decision` eval artifact writing.

**Goal:** attach linked eval diff artifacts to approved remediation decisions,
not only to the generic dev-loop after phase.

**Work:**
- Add stable remediation eval diff/link/manifest paths for default and scenario
  decisions.
- Reuse `runAgentEvalAndWriteLinkedDiffManifest` with a bounded built-in eval.
- Keep rejected decisions record-only.

**Acceptance:**
- Tool tests prove approved decisions write one diff artifact, one link artifact,
  and one manifest artifact with schema/path evidence.

### M58 — File-backed service-discovery snapshot loader

**Status:** delivered on 2026-06-24 via
`loadClusterTransportServiceDiscoverySnapshotJsonFile`.

**Goal:** provide one concrete local discovery provider seam before network
discovery is introduced.

**Work:**
- Read a governed discovery snapshot JSON file from a caller-provided directory.
- Parse it through the existing owned snapshot parser.
- Refresh the in-memory registry from the loaded snapshot.

**Acceptance:**
- Tests prove a real file-backed snapshot imports endpoints and selects the safe
  candidate through the existing requirements.

### M59 — Provider-shaped ops alert request adapter

**Status:** delivered on 2026-06-24 via
`formatCausalOpsAlertProviderRequest`.

**Goal:** give host-owned external alert adapters provider-shaped request bodies
without sending network traffic from the deterministic core.

**Work:**
- Add generic webhook, Slack webhook, and PagerDuty Events v2 request shapes.
- Keep fixed JSON/no-store/nosniff headers.
- Use secret references and redacted delivery evidence instead of raw secrets.

**Acceptance:**
- Tests prove Slack and PagerDuty bodies are provider-shaped and sentinel secrets
  are redacted.

### M60 — Live engine host runner bundle

**Status:** delivered on 2026-06-24 via `createLiveEngineHost`.

**Goal:** make the tested live apply adapter and command daemon bridge one
host-facing bundle without starting a server in local tooling.

**Work:**
- Expose `handleApplyRequest(request)` as a thin wrapper around
  `serveLiveEngineCommandApplyRequest`.
- Expose `runCommandDaemon(url, options, fetcher)` as a thin wrapper around
  `runLiveEngineCommandDaemon`.
- Keep the caller-owned engine bridge as the policy/apply authority.

**Acceptance:**
- Bun tests prove apply requests delegate to the bridge and daemon runs return
  tap counters plus emitted frames.

### M61 — HTTP-shaped service-discovery snapshot provider

**Status:** delivered on 2026-06-24 via
`formatClusterTransportServiceDiscoveryHttpRequest` and
`parseClusterTransportServiceDiscoveryHttpResponse`.

**Goal:** let host-owned HTTP discovery clients feed governed snapshot JSON into
the existing owned registry refresh path.

**Work:**
- Add a fixed `GET` request shape with JSON accept metadata.
- Reject non-200 responses before parsing.
- Reuse the governed snapshot parser and registry refresh flow.

**Acceptance:**
- Tests prove a 200 snapshot response refreshes the in-memory registry and a
  non-200 response is rejected.

### M62 — Patch-proposal eval artifact persistence

**Status:** delivered on 2026-06-24 via `causal-patch-proposal` eval artifact
writing.

**Goal:** attach linked eval diff artifacts to approved patch proposals, not
only to dev-loop and remediation-decision flows.

**Work:**
- Add stable patch-proposal eval diff/link/manifest paths for default and
  scenario proposals.
- Reuse `runAgentEvalAndWriteLinkedDiffManifest` with a bounded built-in eval.
- Keep draft proposals record-only.

**Acceptance:**
- Tool tests prove approved proposals write one diff artifact, one link artifact,
  and one manifest artifact with schema/path evidence.

### M63 — Provider alert secret injection

**Status:** delivered on 2026-06-24 via
`deliverCausalOpsAlertProviderWithSecret`.

**Goal:** let host-owned alert delivery resolve provider secrets at send time
without storing or logging those secrets in the deterministic core.

**Work:**
- Add `CausalOpsAlertProviderSecretResolver`.
- Resolve PagerDuty routing keys only for transient outbound request bodies.
- Preserve fixed JSON/no-store/nosniff headers and redacted alert evidence.

**Acceptance:**
- Tests prove the resolver is called with the secret reference, PagerDuty gets
  the resolved routing key, the secret-ref field is omitted from the outbound
  body, and sentinel alert evidence remains redacted.

### M64 — Supervised live engine host loop

**Status:** delivered on 2026-06-24 via `runLiveEngineHostSupervisor`.

**Goal:** give a live engine host a bounded restart/reporting loop around the
collector command daemon without claiming OS process supervision.

**Work:**
- Run a host's command daemon through a bounded restart loop.
- Emit lifecycle events for start, daemon failure, restart, success, and stop.
- Aggregate command/apply/frame counters across the successful run.

**Acceptance:**
- Bun tests prove a transient daemon failure is restarted once, counters are
  returned, lifecycle events are emitted, and the restart limit is honored.

### M65 — Continuous NDJSON fact tap

**Status:** delivered on 2026-06-24 via `runLiveEngineNdjsonTap`.

**Goal:** give a live engine host a tested stream-to-collector fact tap for
engine NDJSON output.

**Work:**
- Read chunked engine NDJSON bytes.
- Post complete lines to the collector ingest endpoint.
- Flush a trailing partial line and report chunk/line/post/ingest/error counts.

**Acceptance:**
- Bun tests prove complete lines are posted, trailing partials flush, and counts
  are accurate.

### M66 — HTTP discovery refresh with caller-owned fetcher

**Status:** delivered on 2026-06-24 via
`refreshClusterTransportServiceDiscoveryFromHttp`.

**Goal:** compose the HTTP-shaped discovery request/response seam with the owned
registry refresh path while keeping real HTTP ownership in host code.

**Work:**
- Add `ClusterTransportServiceDiscoveryHttpFetcher`.
- Format the fixed discovery request and call the caller-owned fetcher.
- Parse governed responses, reject non-200 responses, refresh the registry, and
  keep refresh source metadata stable.

**Acceptance:**
- Zig tests prove the fetcher sees GET/accept/url metadata, a 200 response
  refreshes the registry, and a non-200 response is rejected.

### M67 — Provider alert retry reporting

**Status:** delivered on 2026-06-24 via
`deliverCausalOpsAlertProviderWithSecretRetrying`.

**Goal:** let host-owned alert delivery retry transient provider sink failures
with a bounded attempts report.

**Work:**
- Add `CausalOpsAlertProviderDeliveryPolicy` and
  `CausalOpsAlertProviderDeliveryReport`.
- Retry secret-backed provider delivery up to a fixed attempt count.
- Rebuild the transient secret-bearing request per attempt and preserve redacted
  alert evidence.

**Acceptance:**
- Zig tests prove a transient first failure is retried, the final delivery
  succeeds, attempts/failures are reported, and sentinel alert evidence stays
  redacted.

### M68 — Live engine host request router

**Status:** delivered on 2026-06-24 via `serveLiveEngineHostRequest`.

**Goal:** give a local host process a tested `Request` router for apply and
health endpoints without owning a server socket.

**Work:**
- Route a configured apply path to `host.handleApplyRequest`.
- Expose fixed-header JSON health metadata.
- Return JSON 405/404 responses for wrong methods and unknown paths.

**Acceptance:**
- Bun tests prove apply delegation, health JSON, wrong-method handling, and
  not-found handling.

### M69 — Live engine host runtime runner

**Status:** delivered on 2026-06-24 via `runLiveEngineHostRuntime`.

**Goal:** compose the supervised command loop and optional NDJSON fact tap as one
host-owned runtime call.

**Work:**
- Run `runLiveEngineHostSupervisor` against the collector command inbox.
- Optionally run `runLiveEngineNdjsonTap` against a provided engine stream.
- Return both reports from one runtime helper.

**Acceptance:**
- Bun tests prove the supervisor and fact tap both run and report through the
  composed helper.

### M70 — Bounded HTTP discovery refresh loop

**Status:** delivered on 2026-06-24 via
`runClusterTransportServiceDiscoveryHttpRefreshLoop`.

**Goal:** let host-owned discovery fetchers refresh the registry repeatedly with
failure accounting and a bounded stop condition.

**Work:**
- Add loop options/report types.
- Record transient fetch/parse failures without losing later refresh attempts.
- Stop early once a safe endpoint is selected when configured.

**Acceptance:**
- Zig tests prove one transient failure is recorded, a later governed snapshot
  refreshes the registry, and the loop stops on selection.

### M71 — Freshest auth-epoch discovery selection

**Status:** delivered on 2026-06-24 via
`selectFreshestClusterTransportServiceDiscoveryEndpoint`.

**Goal:** support auth-rotation-aware endpoint selection while preserving the
existing first-safe selector.

**Work:**
- Keep `selectClusterTransportServiceDiscoveryEndpoint` first-safe.
- Add a new selector that chooses the safe endpoint with the highest auth epoch.
- Preserve validation reporting in the returned selection.

**Acceptance:**
- Zig tests prove first-safe behavior remains and the new selector chooses the
  freshest safe auth epoch.

## Delivered since 2026-06-20

The forward sequence from the prior roadmap is largely done. Tracked in
`docs/superpowers/plans/`:

- zio backend built; `Queue`/`Semaphore`/`Deferred` suspend/resume on it; engine
  fibers run as zio coroutines (D1/D2).
- OTLP/JSON serialization + the live-attach collector make the causal graph leave
  the in-memory world against a real consumer.
- The workbench has a live-attach path (not just `?sample=` fixtures), with a
  committed browser screenshot proof of a real collector stream.
- Six final-completion tracks (race+both, thread-pool executor, heterogeneous STM,
  FiberRef auto-propagation, the zio vtable fill, workbench live-attach) plus the
  collector and scheduler-on-zio, each adversarially reviewed and hardened.
- One loopback cluster transport crosses localhost TCP, and the remote socket
  wrapper adds auth preflight, reconnect attempts, transport policy validation,
  origin causal ids, metrics, and redacted failure handling.
- The M6-M71 agentic engine layer now covers bounded interventions,
  counterfactual trace forks, reusable invariants, semantic graph diffs, live
  command transport primitives plus engine execution/taps, collector polling,
  typed inbox validation, local polling and daemon harnesses with lifecycle
  evidence, live engine bridge wiring, HTTP engine bridge clients, host apply
  request adapters, host runner bundles, supervised host loops, continuous
  NDJSON fact taps, host request routers, runtime runners, collector frame
  ingest, poll-batch cursor bridging, and bounded poll loops, concurrency
  annotations, transport hardening plus
  service-discovery validation/selection, an in-memory registry, snapshot
  refresh, snapshot JSON parsing, file-backed snapshot loading, and HTTP-shaped
  discovery response parsing plus caller-owned HTTP fetcher refresh, bounded
  discovery refresh loops, and freshest-auth endpoint selection, ops
  guardrails/storage/alert/artifact/delivery adapters with delivery sinks,
  webhook and provider-shaped request bodies, endpoint-aware runbooks,
  provider secret injection, provider retry reporting, HTTP-shaped responses,
  fixed headers, and method/path-gated request adapters,
  schema-governed visual/emitted/eval-linked diff evidence with writer sinks,
  remediation links, linked manifests, a manifest writer, dev-loop eval artifact
  persistence, remediation-decision eval artifact persistence, patch-proposal
  eval artifact persistence, and multi-runner lineage stitching with deployment
  artifact metadata and validation.

## June 2026 cleanup note

An autonomous self-improvement loop over-generated ~120 record-only governance
tools (counter-tier `*_level_*` clones and `*_evaluation_report_evaluation_report_*`
recursion chains), plus ~340 dedicated docs/plans. All were removed; the engine
`src/` was untouched and verified green. Guardrails now prevent recurrence:
`tools/check_tool_hygiene.sh` (CI + pre-commit hook), the Tool Hygiene Policy in
`AGENTS.md`/`CLAUDE.md`, and the approval gate in [tool-roadmap.md](tool-roadmap.md).
The checker now also rejects new `.zig` tools that do not import or explicitly
exercise runtime symbols, unless a human adds a narrow no-runtime-import
justification. It also rejects known stale current-status claims and caps
report-named tool proliferation so report generators do not become their own
growth path.
