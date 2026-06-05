# zigeffect Devex Review

Date: 2026-06-04

## Current Direction

`zigeffect` should feel like sturdy Zig with Effect-style structure around it.
The library should make large Zig tools easier to compose, test, observe, and
release without hiding allocators, error sets, or resource lifetimes.

## What Is Working

- Direct-style functions keep implementation code readable.
- Constructors and recovery helpers reduce tiny wrapper boilerplate without
  hiding Zig errors.
- `onExit` and `ensuring` give lifecycle observation and effect-local cleanup
  without forcing app code into callback-heavy style.
- `Context` gives typed service access without global state.
- `Runtime`, `Scope`, and `acquireRelease` make cleanup explicit and automatic.
- `Layer.fromBuilder` gives dependency construction a scoped teardown path.
- `Layer.merge` and `Layer.provide` make dependency composition possible without
  manual context setup in every test or tool.
- `Effect.requires`, `Layer.provides`, `Runtime.provides`, `LayerGraph`, and
  `layerGraph` give production code a preflight dependency gate before startup.
- `LayerWithError` preserves typed startup failures from dependency builders.
- `layerGraph` builds heterogeneous declared layers in dependency order and
  memoizes the started environments until graph deinit.
- `DependencyReport` gives missing and duplicate service diagnostics that CLIs,
  tests, and agents can print.
- Fallible finalizers are recorded and surfaced through `Runtime.exit`.
- Exit-aware finalizers let cleanup react to success, typed failure, defect,
  interruption, or cause summaries.
- `Clock` is now a service abstraction with fake and system modes.
- Zig error sets provide typed errors without a custom error hierarchy.
- `serviceNotFound` gives missing services a package-owned compile-time
  diagnostic instead of vague one-off environment messages.
- `formatExit` and `formatCause` turn structured runtime results into readable
  reports for tests, CLIs, and agents.
- Missing finalizer scopes now return `error.MissingScope`, and
  `acquireRelease` releases immediately if registration fails.
- `TestEnv` gives agents deterministic logs, files, metrics, traces, config, and
  time.
- Composition helpers and `Schedule` retry/repeat policies are available but do
  not dominate the API.
- Effect-style schedule names (`once`, `recurs`, `spaced`, `duration`, and
  `fibonacci`) make common retry/repeat policy intent easier to scan.

## Ergonomic Risks

- `Effect` composition wrappers are repetitive internally. Future work should
  consider reducing duplication without making the public API harder to read.
- `acquireRelease` currently requires pointer resources with stable lifetimes.
  That is clear, but value resources may need a separate helper later.
- Composition errors are still mostly Zig's native function-pointer and error-set
  messages. Future work should add small compile-time assertions where the
  package can name the likely fix.
- `Runtime.run` creates a fresh scope per run. Shared long-lived scopes may need
  an explicit API once real app runtimes need them.
- Dependency-injected layer builders are still deferred. Layer builders receive
  `(Allocator, *Scope)`, while declared requirements drive validation and build
  order.
- Recursive causes use pointer links for nested formatting. Runtime-generated
  causes currently surface finalizer failures directly rather than returning
  pointer-backed sequential trees.
- Logger levels are currently collapsed into plain messages. A real app logger
  should preserve level metadata.
- Test services are useful but still bundled. Larger apps may need custom
  environments with only the services they use.
- Runtime-generated nested causes are still deliberately conservative. Cleanup
  failures from `Runtime.exit` surface as direct finalizer-failure causes rather
  than stack-unsafe sequential cause trees.

## EffectTS Maturity Notes

EffectTS is much broader than this package: it has mature service tags, layers,
structured causes, schedules, test clocks, logging, tracing, metrics, config,
and a large stdlib surface. The current `zigeffect` target is core style parity:
the same predictable architecture shape, implemented in Zig with explicit
allocators, native error sets, direct-style `try`, and scoped cleanup.

See `effectts-parity.md` for the researched comparison and the next parity
priorities.

## Next Priority

1. Add typed config descriptors and env/file providers.
2. Add level-aware structured logger entries.
3. Add metrics snapshots with counters, gauges, and histograms.
4. Add tracing span ids and nested span trees.
5. Add compile-time assertions for common composition mistakes, especially
   mismatched environments and resource error sets.
6. Add dependency-injected layer builders that can consume previously-started
   graph services.
7. Add a small module/app pattern that bundles layer, effects, tests, and docs
   for large predictable software.
8. Add richer `Exit`/`Cause` assertions and defect helpers.

## Standard For Future Work

Every public API addition should include:

- failing test first
- usage docs
- agent guidance if the API can be misused
- focused `bun run zigeffect:test`
- combined `bun run zig:test`
