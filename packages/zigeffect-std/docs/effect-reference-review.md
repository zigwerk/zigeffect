# Effect Standard-Library Reference Review

**Reference tree:** `packages/references/effect`
**Pinned revision:** `80b539f8aba68f478c75c35c2b4140c4ffc4fada`
**Examples tree:** `packages/references/effect-examples` at `91e24b045af2bcdbeb2e78e075825ed20a0038a7`
**Reviewed version:** Effect `4.0.0-beta.98`
**Review date:** 2026-07-16

## What Effect Actually Does

### Required services and default references are different types

`packages/references/effect/packages/effect/src/Context.ts` defines required
`Context.Service` keys and
defaulted `Context.Reference` keys. Both are type-safe runtime identities, but
a missing Service is an error while a Reference resolves a cached default.

Clock, Console, and Random use Reference semantics in
`packages/references/effect/packages/effect/src/internal/effect.ts` and
`packages/references/effect/packages/effect/src/internal/random.ts`. Ordinary clock, console, and random
operations consequently do not add a service requirement to every Effect type.
Overrides are inherited through the fiber context.

ZigEffect maps this distinction to:

- `fx.kernel.Service` for explicit application capabilities; and
- `fx.kernel.DefaultServices` plus `DefaultOverrides` for runtime defaults.

### Portable service methods are effectful

`packages/references/effect/packages/effect/src/FileSystem.ts` defines a stable
FileSystem service key and
an interface whose operations return Effect, Stream, or Sink descriptions.
`FileSystem.make` accepts a smaller platform implementation and derives safe
convenience operations. `FileSystem.makeNoop` and `layerNoop` provide focused
test substitution without changing the program.

`packages/references/effect/packages/platform-node/src/NodeFileSystem.ts`
exports only the Node-backed layer. The portable program continues to depend on
the FileSystem key, not on Node's implementation type.

ZigEffect maps this to a stable tag, a driver API beneath the boundary,
module-level typed effects, and live/deterministic layer constructors. The
module-level effect is important: directly wrapping an imperative provider
after application code has selected its concrete environment is not equivalent
to an effectful service.

### Layers are constructors, not bags of initialized values

`packages/references/effect/packages/effect/src/Layer.ts` keeps three types
visible: outputs, build errors,
and inputs. `Layer.provide` satisfies construction inputs, `mergeAll` combines
outputs, scoped layers acquire resources, and memoization shares a layer by
identity inside one build.

ZigEffect's canonical `Layer<Output, Error, Input>` equivalent uses comptime
service sets, explicit `provide`/`provideMerge`, identity memoization, and
reverse finalization. A standard-library layer must declare only construction
dependencies; consumers of the built service require only its stable output
tag.

### ManagedRuntime is the application bridge

`packages/references/effect/packages/effect/src/ManagedRuntime.ts` builds a
layer lazily, caches its
context, runs many effects against that context, supervises fibers in its
scope, and disposes layer resources once.

ZigEffect builds eagerly at `ManagedRuntime.make`, which is a deliberate Zig
choice: startup failure is explicit before a server reports readiness. The
I/O-free interpreter is `fx.kernel.ManagedRuntime`; canonical processes use
`zstd.ManagedRuntime`, which also owns the embedded NenDB causal graph and
checked persistence shutdown. The important invariant is the same—one root
graph, one owned application scope, many request/job runs, one disposal.

### Official applications keep executable roots small

The pinned monorepo template puts schemas and API contracts in
`packages/domain`, repository and server layers in `packages/server`, clients
in `packages/cli`, and leaves `server.ts` and `bin.ts` as small composition
edges. ZigEffect follows the same dependency direction: libraries publish
tags, effects, schemas, and layers; deployable applications choose
implementations once and launch one runtime.

### Observability belongs in the interpreter

Effect's logging, metrics, tracer, and supervision facilities are attached to
fiber/runtime interpretation and can be configured with layers or references.
Service business logic does not request four observability dependencies merely
to become visible.

ZigEffect uses RuntimeAspect fanout. Structural runtime events and semantic
standard-library/application events both reach custom aspects, logger,
metrics, tracer, supervisor where applicable, and the runtime-owned causal
store. Causal recording is an additional first-class interpreter signal, not a
replacement for OTEL signals.

## Zig-Specific Decisions

| Effect technique | ZigEffect decision |
| --- | --- |
| TypeScript structural types and class tags | comptime service-tag types with stable string identities |
| Generator syntax for service access | typed effect constructors and `ContextView(Requirements)` |
| Promise/async runtime bridges | synchronous typed runner today; RuntimeHandle is the reusable server/job bridge |
| JavaScript object service implementations | small vtable-shaped driver values below public effects |
| Lazy managed-runtime build | eager build so native service readiness has a definitive startup result |
| Fiber-local maps | inherited `DefaultOverrides` and runtime lineage on each run/fiber context |
| Standard tracing only | tracing plus bounded/redacted causal lineage and an agent-readable application snapshot |

ZigEffect does not copy generator, prototype, symbol, Promise, or JavaScript
module patterns where they add no value in Zig.

## Current Migration State

| Area | State | Evidence |
| --- | --- | --- |
| Canonical service/effect/layer/runtime kernel | landed | `packages/zigeffect/test/kernel_test.zig` |
| Fluent typed effect/layer composition | landed | inferred service/error unions, named causal programs, fluent layer tests |
| Default Clock, Console, Random, Config effects | landed | requirement-free canonical architecture test |
| Semantic RuntimeAspect fanout | landed | custom/built-in aspect tests and causal snapshot |
| FileSystem oracle | landed | stable tag, memory/local layers, typed effects, operation catalog |
| Process oracle | landed | stable tag, fake/local layers, typed effect, operation catalog |
| One-endpoint application map | landed | services, layers, dependencies, operations, recent events, embedded NenDB health, validated manifest intent, exact agent workflow, graph cursor and follow-up queries |
| Canonical local scaffolds | landed | template schema v11 runtime-owned NenDB application/service roots, composable library layers, and graph-durable Testing v2 assertion IDs |
| IDs, Env/Secrets, Workspace | pending canonical migration | legacy APIs remain |
| Queue/PubSub/Sink/Cache/Broker/ObjectStorage | pending canonical migration | legacy APIs remain |
| gRPC facade and native adapter | landed | generated routes/clients, registries, standard services, scoped native channel/server layers, runtime handles, and Cloud Run root are legacy-free |
| HTTP/SQL std facades | pending canonical migration | adapter packages exist; facade wiring remains mixed |
| CLI/Agent/Statechart higher-level programs | pending canonical migration | move after their lower-level services |
| Legacy provider/runtime deletion | pending | tracked by `effect-native-roadmap.md` |

The current legacy scan is intentionally visible in the roadmap. A passing
legacy test proves behavior preservation, not completion of the canonical
migration.

## Standard-Library Admission Checklist

A migrated module is complete only when:

1. application operations are concrete effect descriptions with no environment
   type parameter;
2. explicit requirements contain stable service tags, never implementation
   types;
3. construction dependencies appear on layers;
4. live and deterministic implementations run the same program unchanged;
5. resources belong to application or run scopes with one finalization owner;
6. semantic facts automatically inherit causal runtime lineage and are
   redacted before storage/export;
7. the application snapshot advertises the service and operation catalog; and
8. Testing v2 evidence is complete with zero pending tests, leaks, and logged
   errors.
