# ZigEffect Repository Guidance

This repository develops ZigEffect itself. Work in framework mode unless an
example or reference application has its own `zigeffect.project.json`.

## Engineering Loop

1. Read the affected package's public exports, `build.zig`, manifest and tests.
2. Write or update the design under `docs/superpowers/specs/` and the execution
   plan under `docs/superpowers/plans/` for multi-step work.
3. Add a failing deterministic test before changing behaviour.
4. Use typed effects, layers, scoped resources and one managed runtime. Runtime
   and owning adapters record structural causal evidence; applications must not
   construct causal stores or duplicate lifecycle facts.
5. Run the smallest package-native test first, then the affected compatibility
   and repository gates.
6. Inspect `.zigeffect/tests/suites/<artifact>.json`. Require a complete pass,
   equal discovered/executed counts, zero pending tests, leaks and logged errors.

Use the repository-owned `.agents/skills/zigeffect-development/SKILL.md` for the
full proof-carrying development workflow.

## Commands

- Core: `cd packages/zigeffect && zig build test`
- Standard library: `cd packages/zigeffect-std && zig build test && zig build examples`
- CLI: `cd packages/zigeffect-cli && zig build test && zig build integration-test`
- Frontends: `bun run check:frontend`
- Architecture: `bun run zigeffect:architecture:test`
- Release: `cd packages/zigeffect && zig build release-gate`

Do not add report-about-report tools. New tools must exercise runtime code and
must satisfy `packages/zigeffect/tools/check_tool_hygiene.sh`.

## Performance Evidence

The current working baseline is the schema-v2 ARM64 Docker optimization
diagnostic: 11,792 RPC/s for 1 KiB unary, 96.6% of grpc-go in the same receipt,
and 13.4% higher throughput than Tonic. It is candidate engineering evidence,
not a release or Cloud Run performance promise. Read
`packages/zigeffect-grpc/benchmarks/PERFORMANCE.md` before repeating or changing
the claim.

`zigeffect-grpc` remains `production_candidate` until a schema-v2 receipt from
committed source includes native Linux amd64 evidence, the complete 24-hour
mixed-shape bounded-memory campaign, and deployed GCP service-to-service
qualification.
