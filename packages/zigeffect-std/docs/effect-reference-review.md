# Effect Standard-Library Architecture Review

**Reference tree:** `packages/references/effect`

**Pinned revision:** `80b539f8aba68f478c75c35c2b4140c4ffc4fada`

**Reference release:** Effect `4.0.0-beta.98`

**Examples:** `packages/references/effect-examples` at
`91e24b045af2bcdbeb2e78e075825ed20a0038a7`

**Reviewed:** 2026-07-16

This is a source review, not a name-matching exercise. Effect has 139 stable
top-level source modules because it is also the missing data and concurrency
standard library for JavaScript. Zig already supplies many of those pure data
structures and platform primitives. A module is a useful port only when it
improves typed composition, resource ownership, deterministic concurrency, or
runtime observability in ZigEffect.

## How Effect Builds Its Standard Library

### One stable algebra per module

`packages/effect/src/index.ts` is a generated namespace facade. Modules such as
`Context.ts`, `Layer.ts`, `Resource.ts`, `Pool.ts`, `Request.ts`, `Stream.ts`,
and `Schema.ts` each present one documented algebra. The package export map
explicitly rejects `internal/*`; callers compose public values rather than
constructing interpreter nodes themselves.

The public/internal boundary is not merely file organization. Public modules
retain stable models and laws while `src/internal/core.ts`,
`src/internal/effect.ts`, `src/internal/layer.ts`, and specialized internal
modules own execution details. ZigEffect's equivalent is:

- `zigeffect` for the interpreter and canonical kernel;
- `zigeffect-std` for portable application contracts and constructors;
- adapter packages for native implementations; and
- small application roots that select one root layer and one runtime.

ZigEffect `root.zig` modules should therefore be treated as facades. Private
implementation state is not an accidental public framework contract merely
because Zig can import a source path from the monorepo.

### Stable and evolving surfaces are separated

Effect exports testing separately and exposes AI, CLI, cluster, devtools,
HTTP, persistence, RPC, SQL, workflow, and worker facilities under explicit
`unstable/*` paths. This lets the core algebra mature independently of fast
moving application packages.

ZigEffect should retain package boundaries for platform adapters and clearly
label evolving agent/workflow APIs in their manifests and docs. It should not
copy the word `unstable` mechanically where ZigEffect already owns a stronger
versioned contract, causal schema, and conformance gate.

### Services are effect descriptions, not implementation objects

`Context.Service` defines required capabilities. Portable methods return
`Effect`, `Stream`, or `Sink` descriptions. For example, `FileSystem.ts`
defines the portable contract and derived operations, while
`platform-node/src/NodeFileSystem.ts` supplies the Node layer. Programs never
depend on the Node implementation type.

ZigEffect's canonical mapping is a stable `fx.kernel.Service`, module-level
typed effects, and live/deterministic scoped layers. Construction dependencies
belong to the layer. After construction, consumers require only the service
tag.

`fx.kernel.defineService` is the Zig-native counterpart to Effect's concise
service definition style: the tag, abstract API, acquisition requirements,
typed startup error, default layer, and optional finalizer are declared once.

### Default references are deliberately ambient

Effect uses `Context.Reference` for values with cached defaults. Clock,
Console, Random, ConfigProvider, current metric attributes, and several runtime
controls use this mechanism so ordinary effects do not acquire noisy service
requirements.

ZigEffect has the same useful semantic split but keeps it closed:

- Clock, ConfigProvider, Console, Random, and Tracer are runtime defaults with
  inherited run overrides;
- application capabilities remain explicit tags.

An arbitrary reference registry is not a desirable port. The fixed set is
faster, easier to inspect, and keeps ambient authority bounded for agents.

### Layers preserve output, error, and input

Effect's `Layer<ROut, E, RIn>` exposes output services, construction errors,
and construction inputs. `provide` satisfies inputs, `mergeAll` combines
outputs, scoped layers own resources, and `MemoMap` shares a layer instance
within a build.

The canonical ZigEffect kernel already provides all of these semantics with
comptime service sets, explicit `provide`/`provideMerge`, identity
memoization, reverse finalization, and application-topology evidence. Earlier
reviews that inspected `zigeffect/src/layer` and concluded memoization was
missing were looking at the quarantined legacy layer engine, not
`zigeffect/src/kernel/layer.zig` and its tests.

The Resource/Pool allocation campaign also closed a kernel edge case: when a
scoped layer acquired successfully but registry publication failed, the layer
now releases the unpublished value before returning the startup error. A
dedicated all-allocation-failures kernel test protects that ownership boundary.

### ManagedRuntime is the process bridge

Effect's `ManagedRuntime` lazily builds and caches a layer context, runs many
programs against it, supervises its scope, and disposes resources once.
ZigEffect deliberately builds eagerly: a native server must know whether its
root layer succeeded before reporting readiness. Canonical `zstd.ManagedRuntime`
also owns bounded causal recording, embedded NenDB persistence, application
inspection, and checked shutdown.

The shared invariant is more important than lazy versus eager construction:
one root graph, one application scope, many request/job scopes, and one
disposal edge.

### Observability belongs to interpretation

Effect logging, metrics, tracing, and fiber supervision are runtime facilities
configured through references and layers. Business logic does not request an
observability bundle just to become visible.

ZigEffect uses runtime aspects for logger, metrics, tracer, supervisor, and
causal recording. Structural execution is automatically visible. Portable
standard-library and transport adapters automatically add redacted semantic
facts at their boundaries; business effects do not request an observability
bundle or recorder merely to become visible. Causal facts supplement OTEL
signals; they do not replace them.

### Resource families are scope algebra

Effect's `Resource`, `Pool`, `ScopedRef`, `RcRef`, `RcMap`, and `ScopedCache`
all build on scopes:

- each acquisition has an owner;
- replacement or invalidation closes the replaced scope;
- borrowing registers a finalizer in the borrower's scope; and
- shutdown unwinds partial and complete acquisition consistently.

This is highly portable to Zig. ZigEffect now exposes:

- `zstd.Resource.Service` for refreshable scoped values whose failed refresh
  preserves the last successful acquisition; and
- `zstd.Pool.Service` for bounded scoped pools with preallocation, reuse,
  invalidation, TTL pruning, per-item concurrency, explicit exhaustion, and
  complete partial-startup unwind.

Both use only the canonical kernel. Their service operation catalogs appear in
the application map, semantic facts use stable service keys, and the runtime
records child scopes and finalizers structurally.

## Capability Matrix

| Effect concept | ZigEffect state | Decision |
| --- | --- | --- |
| Context Service | canonical parity | retain stable comptime tags |
| Context Reference | deliberate specialization | retain five bounded runtime defaults |
| Layer inputs/outputs/errors | canonical parity | retain comptime service sets |
| Layer memoization | canonical parity | retain identity memoization and topology evidence |
| ManagedRuntime | extended parity | retain eager startup plus durable causal ownership |
| Cause / Exit / Scope | canonical core | continue typed failure and finalizer hardening |
| Ref / Deferred / Queue / Semaphore / Hub | present in runtime | improve suspension semantics with async backend |
| Resource | ported | `zstd.Resource` |
| Pool | ported | `zstd.Pool` |
| RcRef / RcMap | absent | next resource-lifecycle tranche |
| Lookup Cache / ScopedCache | partial | add after shared in-flight request support |
| Request / RequestResolver | absent | requires a real interpreter request instruction |
| Schedule algebra | partial | union/intersection/sequence exist; typed input/output policies remain |
| Channel / Stream / Sink | partial, legacy ABI quarantined | build a canonical service-set channel executor before expanding operators |
| FiberMap / FiberSet / FiberHandle | partial supervision equivalents | add only with scoped interruption and causal tests |
| Schema refinements/transforms/generation | substantial parity | continue formats, representations, and law testing selectively |
| Property testing / TestClock | implemented and extended | Testing v2 adds causal assertions, virtual worlds, mutation, and proof receipts |
| Metrics | counters, gauges, simple histograms | add tagged buckets/summaries only with OTLP mapping |
| Transactional collections | absent | require canonical STM semantics first |
| Pure JS data modules | Zig std equivalents | do not duplicate without a demonstrated algebraic gap |

## Features That Cannot Be Shallow Ports

### Request and RequestResolver

Effect batches logically independent requests because its interpreter sees
request instructions from multiple fibers, groups them, and invokes a resolver
once. A Zig helper named `requestAll` would not provide this property. The
correct ZigEffect tranche needs:

1. a typed request instruction in the canonical effect algebra;
2. deterministic fiber collection windows;
3. resolver batching and completion tables;
4. shared in-flight cache entries;
5. interruption and resolver failure semantics; and
6. causal parentage from each logical request through the physical batch.

### Channel, Stream, and Sink

Effect streams and sinks are built on an effectful Channel executor with
chunking, suspension, leftovers, scoped finalization, and backpressure. The
existing ZigEffect effectful pull stream is useful engine work, but its legacy
environment parameter is not a canonical application surface. The proper port
must use service-set requirements, the selected async backend, bounded buffers,
and runtime-owned scopes before adding a broad operator catalog.

### Automatic Resource refresh and waiting pools

Background resource refresh and pool waiting require scoped, interruptible
fibers rather than an operating-system sleep or spin. Current `Resource`
refresh is explicit and current `Pool` exhaustion is a typed failure. Those are
honest synchronous semantics. Async variants will use the runtime suspension
backend and preserve the same service contracts.

## Zig-Specific Choices

| Effect technique | ZigEffect choice |
| --- | --- |
| structural TypeScript service shapes | comptime tag plus concrete API value |
| generators for service access | typed effect constructors and `ContextView` |
| `dual` data-first/data-last helpers | normal methods and comptime functions |
| Promise runtime bridges | native runtime handles and selected executors |
| JavaScript object implementations | small values/vtables below public effects |
| lazy runtime startup | eager startup before readiness |
| arbitrary Context references | fixed default-service set |
| standard tracing only | OTEL-compatible signals plus bounded causal lineage |
| implicit garbage-collected ownership | explicit scopes, allocators, and finalizers |

## Admission Checklist

A standard-library module is canonical only when:

1. operations are concrete effect descriptions with stable service tags;
2. requirements contain tags, never implementation types;
3. construction dependencies appear only on layers;
4. live and deterministic layers run the same program unchanged;
5. resources have one application or run-scope owner;
6. failure and partial construction unwind every owned allocation;
7. semantic facts inherit runtime lineage and redact details;
8. the application map advertises service operations and layer dependencies;
9. tests run through the Testing v2 server runner; and
10. suite receipts are complete with zero pending tests, leaks, and logged
    errors.

The implementation design and remaining interpreter tranches are recorded in
`docs/superpowers/specs/2026-07-16-effect-standard-library-foundations.md`.
