# Agent safety plane

The zigeffect safety plane combines Zig compiler output with static source
policy, runtime ownership evidence, deterministic fault/schedule exploration,
and causal source references. It is designed for fast agent-authored Zig while
making the evidence behind a safety claim inspectable.

It does **not** make arbitrary Zig memory-safe or claim Rust-equivalent language
soundness. `agent_safe_v1` is a governed development profile: code under safe
roots cannot use the configured escape-hatch constructs; unavoidable systems
code belongs under audited roots with an exact source fingerprint,
justification, and required check.

## Agent loop

```sh
zigeffect project validate --json
zigeffect project check --agent --json
zigeffect safety explain <finding-id>
zigeffect safety baseline
```

`project check --agent` discovers declared Zig roots, parses them with Zig's AST,
runs only manifest-owned commands, captures bounded/redacted raw compiler
artifacts, parses source spans, and atomically writes:

- `.zigeffect/receipts/latest-static-safety.json`
- `.zigeffect/receipts/latest-safety.json`
- `.zigeffect/receipts/compiler-<command-id>.json`

A `passed` receipt means all required declared gates passed for the recorded
source revision and toolchain. Missing, truncated, stale, or unsupported required
evidence is `incomplete`. Optional unsupported sanitizer/fuzz gates remain
visible and do not become false successes.

## Development kernel

- `ResourceTable(T)` uses generational handles and rejects foreign, stale, or
  double-finalized resources. Borrow callbacks cannot return pointer-bearing
  values.
- `assertAgentSendable(T)` rejects pointer-bearing fiber/message payloads at
  compile time.
- `TrackedAllocator` records source-linked allocation/free/OOM/leak/invalid-free
  facts and supports checked finalization.
- `exploreSchedules` exhaustively explores bounded value-only models,
  deduplicates states, reports deadlock/invariant/step failures, minimizes the
  failing schedule, and supports deterministic replay.
- `SourceMap` correlates stable source ids with causal events while enforcing
  bounds and redaction.

These checks are development evidence. ReleaseFast may omit heavy exploration
and allocation instrumentation according to the project posture; generation
checks and critical invariants can remain enabled.

## Gate matrix

Generated projects declare source policy, Debug, ReleaseSafe,
allocation-failure, leak, causal-invariant, bounded-schedule, and executor
equivalence evidence. ThreadSanitizer, C undefined-behavior sanitizer, stack
protection, and fuzz
are explicit optional capabilities until a platform-specific manifest command
is configured. Changing one to required without a supported command makes the
receipt incomplete.

Generated Debug tests include deterministic all-allocation-failure sweeps and a
bounded safe schedule model. Those sweeps have already exposed partial-result
leaks in CLI parsing, HTTP header cloning, and metrics insertion; each has a
focused regression test.

## Workbench and claims

The read-only workbench Safety view validates receipt schema v1 and shows the
verdict, completeness, gate matrix, compiler source spans, unsafe inventory,
memory facts, and copyable replay commands. Unknown schemas fail closed.

The provider/language benchmark scorer accepts
`zigeffect.agent-benchmark-fixture.v1` and emits
`zigeffect.agent-benchmark-score.v1`. Checked-in fixture values are illustrative
schema data, not a controlled Codex/Claude or Zig/Rust/C study. General safety,
development-speed, or performance claims require frozen tasks, toolchains,
models, prompts, hardware, raw evidence, and repeated measurements.

## Versioned contracts

- project manifest: `zigeffect.project.v1`
- static safety report: `zigeffect.static-safety-report.v1`
- safety receipt: `zigeffect.safety-receipt.v1`
- compiler artifact: `zigeffect.compiler-artifact.v1`
- source map: `zigeffect.source-map.v1`
- schedule exploration: `zigeffect.schedule-exploration.v1`
- benchmark fixture/score: `zigeffect.agent-benchmark-fixture.v1` /
  `zigeffect.agent-benchmark-score.v1`

Unknown versions fail closed. Existing manifests without a safety policy remain
explicitly `unmanaged`; they never receive a passed safety verdict by default.
