# ZigEffect documentation

This directory has one canonical application architecture:
`kernel.Service` + `kernel.Effect` + `kernel.Layer` + one
process-level `zstd.ManagedRuntime`. The application runtime embeds NenDB and
wraps the I/O-free `kernel.ManagedRuntime`; direct kernel runtime construction
is an explicit memory-only framework-test or custom-platform choice. Documents
that mention environment-parameterized effects or `LayerGraph` do so only to
identify migration debt or explain low-level compatibility internals.

## Start here

1. [Usage](usage.md) — authoritative application-facing API guide.
2. [Runtime-owned causal applications](runtime-owned-causal-applications.md) —
   what the runtime, adapters, applications and tests each own.
3. [Compositional applications](compositional-applications.md) — services,
   fluent effects, layers, one runtime, and application inspection.
4. [Module pattern](module-pattern.md) — organizing larger capabilities.
5. [Architecture](architecture.md) — source ownership and import direction.

## Build applications

- [Agent-first application development](agent-first-application-development.md)
- [Proof-carrying development plane](proof-carrying-development-plane.md)
- [Agent guide](agent-guide.md)
- [Agent-first testing](agent-first-testing.md)
- [Errors and diagnostics](errors.md)
- [Resource ownership](resource-ownership.md)
- [gRPC, Connect, and Cloud Run](grpc-cloud-run.md)
- [Statecharts in production](statecharts-production.md)
- [Migration to durable runtime](migration-to-durable-runtime.md)

## Observe and operate

- [Agent-observable runtime](agent-observable-runtime.md)
- [NenDB agent development](nendb-agent-development.md)
- [Causal scenarios](causal-scenarios.md)
- [Causal development harness](causal-dev-harness.md)
- [Local agentic development](local-agentic-development.md)
- [Local agent adapters](local-agent-adapters.md)
- [Agent safety plane](agent-safety-plane.md)
- [Agent workflow studio](agent-workflow-studio.md)
- [Operations](operations.md)
- [Schema governance](schema-governance.md)
- [Performance budget](performance-budget.md)

## Reference

- [Data](data.md)
- [Pattern matching](pattern-matching.md)
- [Effect concepts](effectts-parity.md)
- [Public API review](public-api-review.md)
- [Compatibility](compatibility.md)
- [Roadmap](roadmap.md)
- [Tool roadmap](tool-roadmap.md)

## Status records

These documents record decisions or migration state; they are not tutorials:

- [Developer-experience review](devex-review.md)
- [Standard-library migration](../../zigeffect-std/docs/effect-native-roadmap.md)
- [Native gRPC migration](../../zigeffect-grpc/docs/effect-native-roadmap.md)
- [Ziac composition migration](../../ziac/docs/zigeffect-composition-roadmap.md)

Historical design specifications and implementation plans live under the
repository's `docs/superpowers/` tree. They explain why a change was made but do
not override current package documentation or tested public APIs.
