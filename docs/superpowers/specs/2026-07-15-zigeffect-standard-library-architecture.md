# ZigEffect Standard Library Architecture

**Date:** 2026-07-15
**Scope:** `zigeffect` canonical kernel and `zigeffect-std`
**Reference:** Effect 4.0.0-beta.98 at pinned submodule revision
`80b539f8aba68f478c75c35c2b4140c4ffc4fada`

## Problem

`zigeffect-std` currently contains useful implementations, but many public
operations are imperative values wrapped after the fact by an
`Effect(EffectEnv)` type. The provider, effect, layer, and runtime all retain a
single concrete environment type. This makes the dependency graph describe an
adapter around the program instead of making the program itself a typed,
composable description.

The canonical kernel now has requirement-typed effects, stable service tags,
typed layers, layer memoization, managed runtime ownership, runtime defaults,
runtime aspects, and application snapshots. The standard library must use that
kernel directly and must not remain a second dependency/runtime system.

## Reference Findings

The pinned Effect implementation uses four distinct categories.

1. `Context.Reference` values such as Clock, Console, Random, configuration,
   and tracer settings have defaults and therefore do not add an ordinary
   service requirement to every program that uses them. They can be overridden
   lexically for a run or scope.
2. Portable capabilities such as `FileSystem` are stable context service keys.
   Their public methods return effects; a program never receives a raw host
   filesystem and then wraps calls later.
3. Host packages provide implementations as layers. For example the Node
   package exports a FileSystem layer while the portable interface remains in
   the Effect package.
4. `ManagedRuntime` builds a root layer once, memoizes it, owns its resource
   scope, runs many programs against the resulting services, and disposes the
   graph once.

The architecture, rather than TypeScript's class/generator syntax, is the part
to copy. Zig should use comptime requirement sets, concrete effect values,
vtable-shaped driver APIs only below the service boundary, and direct values
where pure Zig is more efficient.

## Target Model

### Pure APIs

Schema, Path, codecs, redaction, capability descriptions, schedules, and other
pure data transformations remain ordinary Zig APIs. Wrapping pure functions in
services would add indirection without improving substitution or lifetime
management.

### Runtime defaults

Clock, ConfigProvider, Console, Random, and Tracer are kernel defaults.
`zigeffect-std` exports effect constructors over the active default reference.
Those effects have an empty explicit requirement set and support inherited
`DefaultOverrides`.

Default operations still emit semantic causal events. Being ambient must not
make them invisible.

### Explicit portable services

FileSystem, Process, HTTP, SQL, Queue, ObjectStorage, and similar external
capabilities use one stable service tag each. The module exports:

- an abstract driver API;
- effect constructors whose requirement set contains only the stable tag;
- live and deterministic layer constructors;
- stable typed failures; and
- operation-level causal events emitted automatically by the effect wrapper.

Construction dependencies appear on layers, not on each operation after the
service has been built.

### Runtime aspects and semantic events

Structural events already flow through RuntimeAspect to causal storage,
logging, metrics, tracing, and supervision. Semantic standard-library events
must use the same fanout path. A semantic event therefore:

- inherits run, parent, fiber, and scope identity from the current context;
- reaches custom aspects, logger, metrics, tracer, and the causal store;
- preserves the full causal taxonomy and redacted domain references; and
- returns its recorded identity so completion/failure events can point to the
  exact operation start.

Standard-library services never take a `CausalStore`, logger, metrics registry,
or tracer as an ordinary application dependency merely to be observable.

## First Migration Slice

This change establishes the reusable pattern with:

1. a canonical semantic RuntimeAspect channel;
2. Clock, Console, Randomness, and Config facades over kernel defaults;
3. FileSystem as a stable explicit service with memory/local layers;
4. Process as a stable explicit service with fake/local layers; and
5. Testing v2 evidence proving topology, substitution, redaction, and semantic
   lineage through one ManagedRuntime.

Existing imperative implementations may remain temporarily as driver-level
building blocks for unmigrated modules. Their environment-parameterized effect
constructors are not the target API and do not count as migration completion.

## Developer Experience

```zig
var files = zstd.FileSystem.Memory.init(allocator);
defer files.deinit();
var process = zstd.Process.Fake.init(.{ .exit_code = 0, .stdout = "ok" });

const MainLayer = zstd.fx.kernel.Layer.mergeAll(.{
    zstd.FileSystem.memory(&files),
    zstd.Process.fake(&process),
    App.Default(),
});

var runtime = try zstd.fx.kernel.ManagedRuntime(@TypeOf(MainLayer)).make(
    allocator,
    MainLayer,
    .{},
);
defer runtime.deinit();

try runtime.run(App.main());
```

Application code calls `zstd.FileSystem.readFile(path)` and
`zstd.Process.run(command)`. It does not name an environment type, fetch a raw
implementation, provide the same layer per endpoint, or manually record
observability.

## Safety and Performance

- The causal store continues to own and redact event strings.
- File contents, process stdout/stderr, credentials, and configuration values
  are not copied into causal details.
- Driver vtables remain one indirect call per external operation; effect and
  layer types are otherwise comptime-specialized.
- ManagedRuntime owns service values and scoped resources once.
- Test layers can borrow deterministic driver state whose lifetime encloses the
  runtime; production scoped layers own resources and finalizers.

## Acceptance

- default-service effects declare no explicit service requirements;
- explicit operations require stable tags rather than implementation types;
- the same FileSystem and Process programs run against live/fake layers without
  changing their effect type;
- the application snapshot exposes the stable services and root layer;
- the application snapshot exposes each stable service's canonical operation
  catalog even before every operation has executed;
- every external operation has a causally linked start/completion pair;
- semantic events fan out to causal, logger, metrics, and tracer aspects;
- secret-shaped operation details are redacted; and
- Testing v2 receipts are complete with no pending tests, leaks, or logged
  errors.
