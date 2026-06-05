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
- `acquireRelease` covers pointer resources and `acquireReleaseValue` covers
  copy-safe value resources. The remaining risk is teaching callers when a
  value's copy-based cleanup model is appropriate.
- Common composition errors now have package-owned diagnostics for effect
  functions, layer merges, resource error sets, service tuples, static
  requirements, and environment mismatches. Future work should keep adding
  focused assertions only where the package can name the likely fix.
- `Runtime.run` creates a fresh scope per run by default. Use
  `Runtime.withScope` when an app lifecycle should own resources across runs.
- Dependency-injected layer builders now receive graph startup contexts through
  `fromContextBuilder`; `fromEffect` and richer layer algebra remain future
  work.
- Recursive causes use pointer links for nested formatting. Runtime-generated
  causes avoid pointer-backed sequential trees and use direct cleanup variants
  for finalizer-only and failure-then-finalizer failures.
- Logger levels are currently collapsed into plain messages. A real app logger
  should preserve level metadata.
- `ServiceEnv(.{ ... })` lets graph-run app effects depend on only the service
  slice they use. Larger apps should still define custom module environments
  when those environments own state or behavior beyond service projection.
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
5. Add a common internal runner path where Zig's types allow it.
6. Add cross-runtime trace propagation across effects, layers, fibers, and
   schedules.
7. Add richer fake-service layer builders for custom module tests.
   for large predictable software.
8. Add richer `Exit`/`Cause` assertions and defect helpers.

## Standard For Future Work

Every public API addition should include:

- failing test first
- usage docs
- agent guidance if the API can be misused
- focused `bun run zigeffect:test`
- combined `bun run zig:test`
