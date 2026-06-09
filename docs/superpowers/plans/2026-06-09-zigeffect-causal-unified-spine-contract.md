# zigeffect Causal Unified Spine Contract Implementation Plan

Date: 2026-06-09
Branch: `codex/zigeffect-causal-unified-spine-contract`
Design: `docs/superpowers/specs/2026-06-09-zigeffect-causal-unified-spine-contract-design.md`

## Scope

Implement the unified causal spine contract as a deterministic Zig report tool,
wire it into schema governance, and update documentation/backlog pointers so the
next branch can safely add deep runtime internals.

## Files

- Add `packages/zigeffect/tools/causal_unified_spine_contract.zig`
- Add `packages/zigeffect/docs/unified-spine-contract.md`
- Update `packages/zigeffect/build.zig`
- Update `packages/zigeffect/tools/causal_schema_governance.zig`
- Update `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Update `packages/zigeffect/docs/schema-governance.md`
- Update `packages/zigeffect/docs/production-hardening-backlog.md`
- Update `packages/zigeffect/docs/agent-observable-runtime.md`
- Update `packages/zigeffect/docs/roadmap.md`
- Update `packages/zigeffect/README.md`
- Update `packages/zigeffect/docs/operations.md`
- Update `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## TDD Plan

1. Add the new Zig tool with tests before wiring the build step.
2. Tests must prove:
   - schema metadata is `zigeffect.causal.unified-spine-contract.v1`
   - recommendation is `start-deep-runtime-internals`
   - next branch is `codex/zigeffect-causal-deep-runtime-internals`
   - all canonical runtime ids are present
   - all app semantic ids are present
   - all relationship types are present
   - policy stages preserve append-only source event semantics
   - derived index families cover cause, parent, fiber, scope, layer/service,
     data lineage, artifact, and findings
   - non-goals include Cockroach, React, live mutation, and direct NenDB
     dependency changes
   - text and JSON reports contain the important fields
   - option parsing handles text, JSON, missing format, and unknown format
3. Wire `zig build causal-unified-spine-contract` only after the tests exist.
4. Run the new step and JSON mode, then update schema governance/backlog/docs.

## Implementation Steps

1. Create the report tool.
   - Define static slices for ids, relationships, policy stages, derived
     indexes, consumers, fixture mappings, authority boundaries, non-goals, and
     verification commands.
   - Emit deterministic text and JSON formats using local JSON helpers.
   - Keep the tool self-contained and side-effect free.

2. Wire the build.
   - Add executable and test artifact in `packages/zigeffect/build.zig`.
   - Add `causal-unified-spine-contract` build step.

3. Register schema governance.
   - Add a production-hardening schema entry.
   - Update governance docs and expected schema count naturally through
     `schema_entries.len`.

4. Update the production hardening backlog.
   - Mark `unified-causal-spine-contract` as delivered.
   - Set recommendation to `start-deep-runtime-internals`.
   - Set recommended branch to `codex/zigeffect-causal-deep-runtime-internals`.
   - Add the new tool to verification commands.

5. Update documentation.
   - Add a dedicated unified spine contract document.
   - Cross-link from agent-observable runtime, operations, roadmap, README, and
     master roadmap.
   - Preserve constraints: NenDB adapter only, SolidJS in `zig-webui`, no
     Cockroach, no React, no mutation authority.

6. Verify.
   - `cd packages/zigeffect`
   - `zig build causal-unified-spine-contract`
   - `zig build causal-unified-spine-contract -- --format json`
   - `zig build causal-artifact-access-control`
   - `zig build causal-production-hardening-backlog`
   - `zig build causal-production-hardening-backlog -- --format json`
   - `zig build causal-schema-governance`
   - `zig build examples`
   - `zig build test`
   - `cd ../..`
   - `bun run check`
   - `bun run zig:test`
   - `git diff --check`
   - `git diff --cached --check`

## Commit Plan

1. Commit design and implementation plan.
2. Commit implementation and documentation updates.

## Follow-On Branch

`codex/zigeffect-causal-deep-runtime-internals`

That branch should begin emitting the deeper runtime facts named by this
contract: layer ids, service keys, resource ids, richer scope/fiber ownership,
retry/cause details, and interruption/finalizer evidence.
