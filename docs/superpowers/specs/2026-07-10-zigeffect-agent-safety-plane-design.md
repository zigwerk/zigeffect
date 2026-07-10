# zigeffect Agent Safety Plane Design

Date: 2026-07-10

## Goal

Make zigeffect the safest practical environment for agents to build high-
performance Zig applications without claiming that a runtime library turns
arbitrary Zig into Rust. The delivered system combines a restricted application
profile, audited systems boundaries, compiler evidence, runtime ownership and
concurrency evidence, deterministic fault exploration, and one source-linked
safety receipt that Codex, Claude Code, CI, and humans can query.

The product claim is deliberately scoped:

> A project satisfying `agent_safe_v1` has passed the declared static and
> dynamic safety contract with complete, source-linked evidence for every
> required gate.

This is not a general proof of Zig memory safety. Rust retains stronger
language-level lifetime and data-race prevention. zigeffect aims to provide a
safer agentic application-development process through a smaller application
surface, richer operational invariants, deterministic reproduction, and faster
machine repair.

## Success Criteria

- Every generated application/service/library/package/system declares a safety
  profile and required evidence gates in `zigeffect.project.json`.
- `agent_safe` source cannot introduce raw pointer casts, pointer/integer
  conversion, unmanaged type erasure, disabled runtime safety, inline assembly,
  unmanaged FFI, detached threads, or other governed constructs unless an exact
  audited allowance exists.
- Audited allowances identify the construct, relative path, source fingerprint,
  justification, and verification requirement. Stale allowances fail closed.
- Compiler diagnostics, static findings, runtime events, allocator findings,
  scheduler findings, tests, and sanitizer/fuzz results join through a stable
  source reference and source revision.
- One `zigeffect project check --agent --json` command emits a bounded, redacted,
  versioned `SafetyReceipt` with a truthful pass/fail/incomplete verdict.
- Agents can identify the failing source location, causal chain, unproven area,
  and exact replay command without parsing terminal scrollback.
- Safe application concurrency passes pointer-free, codec-compatible messages;
  arbitrary shared mutable services are rejected at the public boundary.
- Resource handles detect stale use and double close. Scoped borrows cannot
  return pointer-bearing values from safe callbacks.
- Debug allocation tracking, all-allocation-failure tests, ReleaseSafe,
  ThreadSanitizer where supported, C UB sanitization where applicable, fuzzing,
  causal invariants, bounded schedule exploration, and cross-executor structural
  equivalence are represented as explicit gates.
- The workbench renders safety status, unsafe inventory, evidence completeness,
  source-linked findings, gate results, and replay actions.
- Provider-neutral Codex/Claude fixtures and optional real runs can be compared
  with Rust and C baselines without making unsupported claims.

## Safety Zones

### `agent_safe`

Normal application, service, library, and domain code. This zone may use normal
Zig values, tagged unions, error sets, effects, layers, Schema/Codec values,
scoped resources, handles, `Ref`, STM, queues, and zigeffect concurrency APIs.

It must not directly use governed unsafe constructs. Borrowed pointers and
slices may be used locally only when they cannot escape an engine-managed
callback. Values crossing effects, services, fibers, workflows, process
boundaries, or durable storage must be owned values, handles, or codec values.

### `audited_systems`

Runtime, allocator, FFI, executor, storage, transport, and platform adapters.
This zone may use governed constructs only through a machine-readable allowance
and a nearby `// SAFETY:` contract. The allowance is part of the source revision
and becomes stale when its fingerprint no longer matches.

### `unmanaged`

Explicit opt-out. The project can still compile and run, but the safety receipt
must state that no `agent_safe_v1` claim applies.

## Governed Construct Taxonomy

The initial stable taxonomy is:

- `pointer_cast`: `@ptrCast`, `@alignCast`, `@fieldParentPtr`;
- `pointer_integer_conversion`: `@ptrFromInt`, `@intFromPtr`;
- `opaque_pointer`: `*anyopaque`, `?*anyopaque`;
- `many_pointer`: `[*]T` and C pointer forms;
- `runtime_safety_disabled`: `@setRuntimeSafety(false)`;
- `inline_assembly`: `asm`;
- `foreign_interface`: `@cImport`, `extern`, `export`, explicit C callconv;
- `volatile_access`: `volatile`;
- `thread_local_state`: `threadlocal`;
- `unmanaged_thread`: direct `std.Thread.spawn` outside an audited adapter;
- `unchecked_unreachable`: `unreachable` and `catch unreachable` outside a
  proven exhaustive/generated boundary;
- `undefined_escape`: governed uses of `undefined` in public returned/stored
  values; and
- `manual_allocator_escape`: application code persisting raw allocated pointers
  outside an engine-owned resource or handle.

The analyzer tokenizes/parses Zig and never treats comments or string literals
as findings. Some semantic rules require generated API constraints or runtime
evidence because a source-only analyzer is not a borrow checker.

## Project Contract

`zstd.Project.Manifest` gains:

- `safety.profile`: `agent_safe_v1`, `audited_systems`, or `unmanaged`;
- `safety.safe_roots` and `safety.audited_roots`;
- `safety.allowances` with stable ids, paths, constructs, fingerprints,
  justifications, and required check ids;
- `safety.gates` describing required compiler/runtime evidence;
- `safety.limits` for source bytes, diagnostics, findings, schedules, fuzz
  cases, artifacts, and retained runtime events; and
- `safety.production_posture` identifying checks retained in ReleaseFast.

Paths are relative and cannot overlap ambiguously. Duplicate/stale allowances,
unknown gate identifiers, secrets, absolute paths, traversal, and an
`agent_safe_v1` project with no safe root fail validation.

## Source References

`SourceRef` is shared by static and runtime evidence:

- component id;
- project-relative file;
- declaration/function name;
- one-based line and column;
- normalized call-site fingerprint; and
- source digest/revision.

Runtime events store a compact `source_ref_id`; a companion source-map artifact
owns the full fields. This avoids duplicating paths on every event and lets
before/after comparisons retain exact locations while detecting stale evidence.
Compiler diagnostics retain raw bounded output as an artifact and also expose
parsed severity, message, source span, and reference-trace locations.

## Safe Ownership Kernel

### Generational resources

`ResourceTable(T)` owns values and returns `ResourceHandle(T)` containing table
identity, slot index, and generation. Closing increments the generation. Resolve
and close reject stale or foreign handles. The table can attach a causal store
and records acquire/use/finalize/invalid-use facts with `SourceRef`.

### Scoped borrows

`ResourceTable.with(handle, callback)` performs a comptime check on the callback
return type. Pointer-, slice-, allocator-, and handle-to-internal-memory-bearing
returns are rejected for `agent_safe` callbacks. The API does not claim Zig move
semantics; it prevents the common escape route by construction.

### Sendable messages

`assertAgentSendable(T)` recursively permits value-only scalars, enums, tagged
unions, arrays, and structs. Raw pointers, slices, functions, allocators, opaque
values, and unmarked external handles are rejected. OS-thread/fiber public APIs
accept encoded immutable messages or explicitly audited thread-safe services.
An opt-in `Send` declaration alone is not considered proof.

## Allocation Evidence

`TrackedAllocator` wraps a backing allocator for Debug/agent verification. It
records allocation identity, address, size, alignment, return address, lifecycle,
live/peak bytes, invalid frees, and OOM. Typed `allocAt/createAt` helpers also
capture `SourceRef`. The tracker uses the backing allocator for its own metadata
to avoid recursion and is synchronized for executor use.

The runtime exports a bounded `MemorySafetySnapshot` and can record summary and
violation events without allocating from the tracked allocator. DebugAllocator
and `std.testing.checkAllAllocationFailures` remain complementary gates for
poisoning, leak detection, and systematic OOM paths.

## Deterministic Concurrency And Fault Exploration

`ScheduleExplorer(Model)` explores bounded cooperative state-machine schedules.
A model exposes runnable actions, one deterministic step, completion, state
hashing, and invariants. The explorer stores the smallest failing schedule and
reports truncation when state/schedule limits are reached.

Runtime yield/wake/queue/STM/timer/cancellation points gain stable choice ids so
selected effect programs can be adapted to the same explorer. Required gates
also cover spawn failure, interruption, timeout, OOM, dependency failure,
journal crash prefixes, and cross-executor structural equivalence.

The system never reports exhaustive concurrency proof when bounds truncated the
state space.

## Safety Receipt

`zigeffect.safety-receipt.v1` contains:

- project/component/source revision and Zig/toolchain identity;
- profile and governed-construct policy;
- compiler invocation and parsed diagnostics;
- static findings and allowance matches;
- per-gate status: `passed`, `failed`, `unsupported`, `not_run`, `truncated`;
- causal artifact ids and evidence completeness counters;
- memory, resource, concurrency, sanitizer, fuzz, replay, and performance facts;
- introduced/resolved findings relative to an optional baseline;
- redacted replay/query commands selected from manifest command ids; and
- verdict: `passed`, `failed`, `incomplete`, or `unmanaged`.

`passed` requires every required gate to pass and all evidence to match the
current source revision. `unsupported`, `not_run`, or `truncated` on a required
gate produces `incomplete`, never success.

## CLI And Agent Protocol

The safety engine lives under runtime/stdlib `src`; the CLI is one orchestration
surface rather than a new family of `causal_*` tools.

Primary commands:

```text
zigeffect project validate --json
zigeffect project check --agent --json
zigeffect safety explain <finding-id> --json
zigeffect safety replay <receipt> <finding-id>
zigeffect safety baseline <receipt>
zigeffect benchmark score <fixture> --json
```

The check command validates the manifest, discovers only declared component
roots, analyzes source, runs manifest-owned commands/gates, captures bounded
compiler output, imports causal artifacts, and atomically writes a redacted
receipt. Agents receive finding id, source span, causal chain, risk, smallest
recommended repair class, and exact allowed replay command.

## Workbench

The existing workbench adds a Safety view with:

- overall verdict and evidence completeness;
- gate matrix and unsupported/truncated explanations;
- source-linked findings grouped by component and construct;
- unsafe allowance inventory and changes from baseline;
- resource/allocation/fiber ownership chains;
- minimized schedule/fuzz input and replay action;
- before/after introduced/resolved findings; and
- benchmark/provider comparison with explicit non-claims.

The workbench remains read-only. Replays and source changes occur through the
local CLI/agent approval boundary.

## Generated Projects

Scaffolds default to `agent_safe_v1`. Templates:

- keep application code pointer-free at effect/service/fiber boundaries;
- use Schema/Codec-owned values and scoped resources;
- include Debug and ReleaseSafe checks;
- include deterministic allocation-failure and schedule-model examples;
- declare optional platform sanitizer/fuzz gates accurately;
- emit causal acceptance facts; and
- install Codex/Claude skills that require the safety receipt before handoff.

## Benchmarking And Claims

Provider-neutral fixtures score:

- time/tokens to first compile and full acceptance;
- repair iterations and diagnostic-query usage;
- unsafe sites introduced and reviewed;
- escaped seeded memory/concurrency/resource defects;
- injected-failure survival and deterministic reproduction;
- handoff evidence completeness; and
- throughput, latency, memory, and binary size.

The same bounded tasks run against zigeffect/Zig, Rust/Tokio, and C baselines.
Reports distinguish prevention, detection, repair speed, operational robustness,
and performance. Marketing claims require stored benchmark evidence.

## Compatibility And Performance

Static checking, source maps, receipts, schedule exploration, and heavy memory
instrumentation are development-time features. Production ReleaseFast may omit
them according to the manifest, while retaining bounded critical invariants and
causal finding evidence. Comptime validation and value-only messages should
compile away; handles add a small generation check where enabled.

Existing `zigeffect.causal.v1` readers remain compatible. Source correlation is
added through optional ids and companion artifacts. Schema changes are versioned
and unknown versions fail closed.

## Non-Goals

- No claim that arbitrary Zig is memory-safe.
- No source-only pseudo borrow checker presented as sound.
- No compiler fork in the first delivery; use public Zig parsing/comptime/build
  interfaces and retain raw versioned diagnostic evidence.
- No arbitrary command execution from receipts, workbench, or remote input.
- No unreviewed automatic source mutation or deployment.
- No new report-about-report tool family.

## Delivery Order

1. Project safety contract, schemas, and static analyzer.
2. Source references and causal correlation.
3. Ownership/sendable/allocation runtime kernel.
4. Deterministic schedule/fault exploration.
5. CLI compiler/gate orchestration and receipts.
6. Safe scaffold templates and agent protocol.
7. Workbench Safety view.
8. Provider/language benchmark fixtures and release gate.
