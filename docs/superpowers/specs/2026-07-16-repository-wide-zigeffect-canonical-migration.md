# Repository-wide canonical ZigEffect migration

**Date:** 2026-07-16
**Status:** accepted by direct user instruction

## Objective

Make every first-party ZigEffect application and adapter package follow one
composition model:

- stable `fx.kernel.Service` tags define substitutable capabilities;
- operations return requirement-typed `fx.kernel.Effect` descriptions;
- live and deterministic implementations are supplied by canonical
  `fx.kernel.Layer` values, with scoped acquisition for resources;
- a deployable process builds one root layer and one `zstd.ManagedRuntime`;
- request, command, job, and workflow execution uses that owning runtime or a
  requirements-limited handle rather than constructing another interpreter;
- the runtime owns causal recording, the embedded NenDB graph, application-map
  projection, observability aspects, supervision, and checked shutdown; and
- Testing v2 receipts and controlled causal proof are required for acceptance.

Pure schemas, codecs, graph compilers, statechart transition functions,
planning algorithms, and data transformations remain ordinary Zig. The
migration applies at side-effect, dependency, resource, process, and agent
boundaries rather than wrapping pure functions for appearance.

## Current-state constraints

The workspace contains uncommitted Zgraphy semantic-schema, operational-
contract, and threat-model work. Those files are an owned baseline and must be
preserved. Zgraphy composition changes are applied around that work and must
not discard or rewrite its new contracts.

The canonical gRPC surface already satisfies the target architecture and is a
reference implementation. The existing standard-library ratchets and Testing
v2 allowlists are insufficient because they permit known debt and omit active
packages.

## Architecture

### Library boundary

Each effectful package exports:

1. a stable service tag and implementation-independent API;
2. effect constructors whose requirements contain only the services used by
   the operation;
3. configuration/value layers;
4. live scoped layers that acquire and finalize drivers once per runtime;
5. deterministic layers or driver adapters usable by tests; and
6. a public facade without an embedded application runtime.

Imperative `init`, `deinit`, and protocol methods may remain as private or
explicit low-level driver APIs below the layer. They are not the application
composition surface.

### Application boundary

Each application or service exports a root layer and root effect. The process
entry point creates one `zstd.ManagedRuntime`, executes the root effect, drains,
checks causal health, flushes evidence, and shuts down exactly once. Long-lived
servers derive runtime handles for requests and jobs. No application manually
creates a causal store or graph backend.

### Default and aspect boundary

Clock, ConfigProvider, Console, Random, and Tracer are runtime defaults.
Logging, metrics, tracing, supervision, and structural causal recording are
runtime aspects. Application operations do not request duplicate ordinary
services merely to become observable.

### Production scaffolding

Local, integration-real, and production profiles generate the same canonical
program structure. Profiles differ only in the concrete layers and declared
authority. Generated libraries never own runtimes. Generated acceptance tests
run the real root effect with deterministic replacement layers and map
assertion event IDs into the project graph before publication.

### Reference system

The API and worker are rebuilt as actual composed applications. Database,
cache/broker, object storage, transport, workflow storage, OTEL, HTTP, config,
secrets, lifecycle, and domain handlers are acquired through scoped layers.
The application-map snapshot must expose their service and dependency topology
from the owning runtime.

### Ziac and Zgraphy

Ziac state backends and provider RPC clients become memoized scoped layers;
commands share requirement-typed effects across CLI, MCP, dashboard, and
workers. Pure resource graph compilation remains pure.

Zgraphy command routing becomes effect selection over explicit repository,
project, storage, benchmark, and output capabilities. One root layer replaces
the current empty-layer runtime wrapper. Existing semantic and security
contracts remain pure data/validation modules.

## Executable conformance policy

The repository architecture guard discovers every first-party package rather
than relying on a hand-maintained allowlist. It rejects application-facing
legacy environment APIs, hidden runtimes, manual causal backends, and adapter
packages without declared canonical facades. Explicit framework-internal test
fixtures may be scoped by path and rationale; package source has no numeric
legacy allowance.

The Testing v2 guard discovers every tracked `build.zig` and generated build
template. Every `b.addTest` artifact must use the exported
`zigeffect_test_runner` in server mode. Direct private source paths and default
test runners are rejected.

## Acceptance criteria

- Architecture policy has zero legacy allowances for first-party public
  package source.
- Every side-effecting adapter has stable service/effect/layer facades and
  scoped resource tests.
- Production scaffolds contain no `EffectEnv`, provider tuples, `LayerGraph`,
  `ctx.runEffect`, manual causal stores, or per-handler runtimes.
- The reference API and worker each own exactly one managed runtime and expose
  their complete application map.
- Ziac has no transitional `cli.Env` dependency at canonical command
  boundaries; provider/state resources are runtime-owned layers.
- Zgraphy uses a non-empty root composition and effectful command services.
- Every tracked Zig test artifact uses Testing v2 through an exported module.
- Debug and ReleaseSafe package gates, generated-project matrices, controlled
  requirement scenarios, graph queries, architecture checks, and repository
  checks pass with complete receipts and no pending tests, leaks, logged
  errors, required gaps, or unexplained unsupported evidence.

## Delivery rule

No compatibility requirement preserves a legacy application-facing API. The
migration may delete or replace it and update all first-party consumers in the
same change. External protocol and persisted-data compatibility changes remain
separate and require their existing schema/conformance gates.
