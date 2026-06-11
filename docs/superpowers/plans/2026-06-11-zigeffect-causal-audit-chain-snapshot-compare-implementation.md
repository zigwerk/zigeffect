# zigeffect Causal Audit-Chain Snapshot Compare Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only `causal-snapshot -- audit-chain-compare` command that
compares two named audit-chain snapshots with schema-governed text and JSON
evidence.

**Architecture:** Extend `packages/zigeffect/tools/causal_snapshot.zig` with a
new audit-chain snapshot compare schema, small audit-chain parser structs,
summary/delta helpers, deterministic text and JSON formatters, and a CLI
subcommand that reuses existing snapshot reference resolution. Register the new
schema in governance, update docs/backlog/roadmap, and keep all behavior
local-artifact, read-only, and mutation-authority-free.

**Tech Stack:** Zig 0.16, `std.json.parseFromSlice`, existing
`causal_snapshot` manifest helpers, existing `causal_run` artifact paths,
existing schema governance/backlog tooling, Bun root verification.

---

## File Map

- Modify: `packages/zigeffect/tools/causal_snapshot.zig`
  - Add schema constants, audit-chain structs, comparison helpers, text/JSON
    formatters, CLI subcommand, fixtures, and tests.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Register `zigeffect.causal.audit-chain-snapshot-compare.v1` and bump schema
    count.
- Modify: `packages/zigeffect/docs/schema-governance.md`
  - Document the new schema.
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark this branch delivered and advance the recommended next branch.
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
  - Reflect delivered audit-chain snapshot comparison and next handoff.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Add the audit-chain snapshot comparison command and boundary.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Add agent guidance for naming and comparing audit-chain snapshots.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Mark the milestone delivered and name the next milestone.
- Modify: `packages/zigeffect/README.md`
  - Add a short command example.
- Modify:
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark branch 46 delivered and set branch 47.
- Add this plan under `docs/superpowers/plans/`.

## Task 1: Add Red Tests And Fixtures

**Files:**
- Modify: `packages/zigeffect/tools/causal_snapshot.zig`

- [ ] **Step 1: Add audit-chain fixture JSON**

Add two audit-chain fixtures near existing snapshot fixtures:

```zig
const audit_chain_left_json =
    \\{
    \\  "schema": "zigeffect.causal.audit-chain.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "dogfood",
    \\  "assessment": "unchanged",
    \\  "proposal_status": "approved",
    \\  "approval_status": "approved",
    \\  "approved": true,
    \\  "applied": false,
    \\  "finding_delta": 0,
    \\  "event_ids": [1, 2, 3, 5],
    \\  "disappeared_event_ids": [1],
    \\  "persisting_event_ids": [2],
    \\  "appeared_event_ids": [3],
    \\  "missing_event_ids": [5],
    \\  "verification_commands": ["zig build examples"],
    \\  "claim_guardrails": ["Do not claim a fix while evidence persists."],
    \\  "proposal_guardrails": ["This proposal does not apply source changes."],
    \\  "chain_guardrails": ["Chain comparison is evidence, not authorization to edit source."]
    \\}
;

const audit_chain_right_json =
    \\{
    \\  "schema": "zigeffect.causal.audit-chain.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "dogfood",
    \\  "assessment": "improved",
    \\  "proposal_status": "approved",
    \\  "approval_status": "approved",
    \\  "approved": true,
    \\  "applied": false,
    \\  "finding_delta": -1,
    \\  "event_ids": [1, 2, 3],
    \\  "disappeared_event_ids": [1, 2],
    \\  "persisting_event_ids": [],
    \\  "appeared_event_ids": [3],
    \\  "missing_event_ids": [],
    \\  "verification_commands": ["zig build examples", "zig build test"],
    \\  "claim_guardrails": ["Do not claim a fix while evidence persists."],
    \\  "proposal_guardrails": ["This proposal does not apply source changes."],
    \\  "chain_guardrails": ["Chain comparison is evidence, not authorization to edit source."]
    \\}
;
```

Add a third fixture by replacing `"applied": false` with `"applied": true` in
the right fixture inside the applied-boundary test.

- [ ] **Step 2: Add manifest fixtures for audit-chain artifacts**

Add:

```zig
const audit_chain_left_manifest_json =
    \\{
    \\  "schema": "zigeffect.causal.snapshot-manifest.v1",
    \\  "schema_version": 1,
    \\  "name": "left-chain",
    \\  "target": "dogfood",
    \\  "phase": "audit-chain-baseline",
    \\  "artifact": {
    \\    "path": ".zig-cache/causal-artifacts/left-audit-chain.json",
    \\    "schema": "zigeffect.causal.audit-chain.v1",
    \\    "schema_version": 1,
    \\    "events": 0,
    \\    "first_event_id": null,
    \\    "last_event_id": null,
    \\    "findings": 1
    \\  },
    \\  "warnings": []
    \\}
;

const audit_chain_right_manifest_json =
    \\{
    \\  "schema": "zigeffect.causal.snapshot-manifest.v1",
    \\  "schema_version": 1,
    \\  "name": "right-chain",
    \\  "target": "dogfood",
    \\  "phase": "audit-chain-after",
    \\  "artifact": {
    \\    "path": ".zig-cache/causal-artifacts/right-audit-chain.json",
    \\    "schema": "zigeffect.causal.audit-chain.v1",
    \\    "schema_version": 1,
    \\    "events": 0,
    \\    "first_event_id": null,
    \\    "last_event_id": null,
    \\    "findings": 0
    \\  },
    \\  "warnings": []
    \\}
;
```

- [ ] **Step 3: Add failing formatter tests**

Add tests:

```zig
test "audit-chain snapshot compare json summarizes two retained chain states" {
    const json = try formatAuditChainSnapshotCompareJson(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-left-chain.json",
        audit_chain_left_manifest_json,
        audit_chain_left_json,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-right-chain.json",
        audit_chain_right_manifest_json,
        audit_chain_right_json,
    );
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.audit-chain-snapshot-compare.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"comparison\":\"improved\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"finding_delta_delta\":-1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"persisting_delta\":-1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"missing_delta\":-1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"left-chain\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"right-chain\"") != null);
}
```

Add a text report test that expects:

- `zigeffect causal audit-chain snapshot compare report`;
- `schema: zigeffect.causal.audit-chain-snapshot-compare.v1`;
- `status: ready`;
- `comparison: improved`;
- `left snapshot: left-chain`;
- `right snapshot: right-chain`;
- `deltas:`;
- `next queries:`.

- [ ] **Step 4: Add failing blocked/applied test**

Use `std.mem.replaceOwned` to set `"applied": true` in the right audit-chain
fixture. Assert the JSON report contains:

- `"status":"blocked"`;
- `"comparison":"inconclusive"`;
- `right audit-chain applied=true requires reviewed application evidence`.

- [ ] **Step 5: Add failing usage test**

Extend the usage test to expect:

```zig
"audit-chain-compare <left> <right>"
```

- [ ] **Step 6: Verify RED**

Run:

```sh
cd packages/zigeffect && zig test --dep causal_artifact --dep causal_compare --dep causal_run -Mroot=tools/causal_snapshot.zig -Mcausal_artifact=tools/causal_artifact.zig -Mcausal_compare=tools/causal_compare.zig -Mcausal_run=tools/causal_run.zig
```

Expected: compile failures for missing formatter functions/constants.

## Task 2: Implement Formatters And Helpers

**Files:**
- Modify: `packages/zigeffect/tools/causal_snapshot.zig`

- [ ] **Step 1: Add schema constants and structs**

Add constants:

```zig
pub const audit_chain_snapshot_compare_schema = "zigeffect.causal.audit-chain-snapshot-compare.v1";
pub const audit_chain_snapshot_compare_schema_version: u32 = 1;
```

Add `AuditChainArtifactForCompare`, `AuditChainSnapshotSide`,
`AuditChainSnapshotDeltas`, and enum/string helpers for status/comparison.

- [ ] **Step 2: Add parser and warning helpers**

Parse audit-chain artifacts with `ignore_unknown_fields=true`.

Warnings should include:

- unsupported or missing audit-chain schema;
- audit-chain `schema_version` newer than `1`;
- target mismatch between manifest and audit-chain artifact;
- manifest warnings already carried by each snapshot manifest.

- [ ] **Step 3: Add summary and delta helpers**

Compute counts from array lengths and signed deltas with:

```zig
fn countDelta(after: usize, before: usize) isize
```

Reuse the existing helper name if compatible; otherwise add a private helper
near snapshot compare code.

- [ ] **Step 4: Add comparison rules**

Implement deterministic comparison:

- blocked side -> `inconclusive`;
- right assessment improved over left -> `improved`;
- lower right finding delta -> `improved`;
- lower persisting and missing counts without higher appeared count ->
  `improved`;
- worse assessment or higher right finding/missing/appeared evidence ->
  `regressed`;
- equal counts and assessments -> `unchanged`;
- fallback -> `inconclusive`.

- [ ] **Step 5: Add JSON formatter**

Emit compact deterministic JSON. Do not pretty-print in this branch; existing
snapshot manifest JSON is compact.

- [ ] **Step 6: Add text formatter**

Emit the report shape from the design doc with signed deltas and next queries.

- [ ] **Step 7: Verify GREEN**

Run the focused Zig test command from Task 1.

Expected: all snapshot tests pass.

## Task 3: Add CLI Subcommand

**Files:**
- Modify: `packages/zigeffect/tools/causal_snapshot.zig`

- [ ] **Step 1: Update usage**

Add:

```text
zig build causal-snapshot -- audit-chain-compare <left> <right>
```

- [ ] **Step 2: Implement CLI branch**

In `main`, add a branch before replay/fork commands:

```zig
if (std.mem.eql(u8, args[1], "audit-chain-compare")) {
    if (args.len != 4) failUsage(error.InvalidAuditChainSnapshotCompareArguments);
    ...
}
```

Use `resolveSnapshotManifestReference`, read both manifests, read both
`artifact.path` values, call `formatAuditChainSnapshotCompareText`, and print
the report.

- [ ] **Step 3: Smoke CLI with temporary files**

Create temporary manifest and audit-chain files outside source control, then run:

```sh
cd packages/zigeffect
zig build causal-snapshot -- audit-chain-compare /tmp/left-manifest.json /tmp/right-manifest.json
```

Expected output includes `comparison: improved`.

## Task 4: Update Governance And Backlog

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Register schema governance entry**

Add `zigeffect.causal.audit-chain-snapshot-compare.v1` with:

- category `snapshot-replay`;
- emitted by `causal-snapshot audit-chain-compare`;
- consumed by agents, reviewers, future workbench, and app-facing production
  integration fixtures;
- compatibility `strict-v1`, `record-only`, `read-only`, `mutation-authority-none`.

Bump schema count from `81` to `82` in tests.

- [ ] **Step 2: Update production hardening backlog**

Add delivered item `audit-chain-snapshot-compare`.

Advance:

```zig
pub const recommendation = "start-app-facing-production-integration-fixtures";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-production-integration-fixtures";
```

Add tests for the new delivered item and next branch.

- [ ] **Step 3: Verify governance tools**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: schema count `82`, backlog next branch is app-facing production
integration fixtures.

## Task 5: Update Docs And Roadmap

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify:
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Modify this implementation plan checklist.

- [ ] **Step 1: Add command examples**

Document:

```sh
zig build causal-snapshot -- manifest left-chain .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.json --target dogfood --phase audit-chain-baseline
zig build causal-snapshot -- audit-chain-compare left-chain right-chain
```

- [ ] **Step 2: Update roadmap handoff**

Mark `codex/zigeffect-causal-audit-chain-snapshot-compare` delivered and add
the next branch:

```text
codex/zigeffect-causal-app-facing-production-integration-fixtures
```

- [ ] **Step 3: Complete checklist**

Flip this plan's completed implementation checkboxes to `[x]`.

## Task 6: Full Verification And Commit

Run:

```sh
cd packages/zigeffect && zig test --dep causal_artifact --dep causal_compare --dep causal_run -Mroot=tools/causal_snapshot.zig -Mcausal_artifact=tools/causal_artifact.zig -Mcausal_compare=tools/causal_compare.zig -Mcausal_run=tools/causal_run.zig
cd packages/zigeffect && zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
cd packages/zigeffect && zig test tools/causal_production_hardening_backlog.zig
cd packages/zigeffect && zig build causal-schema-governance -- --format json
cd packages/zigeffect && zig build causal-production-hardening-backlog -- --format json
cd packages/zigeffect && zig fmt --check tools/causal_snapshot.zig tools/causal_schema_governance.zig tools/causal_production_hardening_backlog.zig
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
bun run check
bun run zig:test
git diff --check
```

Commit implementation:

```sh
git add docs/superpowers/plans/2026-06-11-zigeffect-causal-audit-chain-snapshot-compare-implementation.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md packages/zigeffect
git commit -m "feat(zigeffect): add audit-chain snapshot comparison"
```

## Success Criteria

- `causal-snapshot -- audit-chain-compare` exists.
- Text and JSON formatters produce
  `zigeffect.causal.audit-chain-snapshot-compare.v1` evidence.
- Unsupported or applied audit-chain artifacts produce blocked evidence, not
  false readiness.
- Schema governance count is `82`.
- Production hardening backlog points to app-facing production integration
  fixtures.
- Full verification passes and the working tree is clean after commit.
