# zigeffect Causal Production Hardening Backlog Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic backlog-refresh artifact that closes the delivered production-hardening queue and selects `codex/zigeffect-causal-nendb-durable-history-hardening` as the next branch.

**Architecture:** Add one read-only Zig tool that consumes the production-hardening backlog JSON, validates the terminal delivered report-policy item, records unresolved candidates, and emits JSON/text refresh artifacts. Register the new schema, build step, docs, backlog item, and roadmap handoff while keeping all mutation, live telemetry, durable write, GitHub, Cockroach, and alternate-renderer authority disabled.

**Tech Stack:** Zig build tooling, `std.json`, local `.zig-cache/causal-artifacts` outputs, existing zigeffect docs, Bun only for repo-level verification.

---

## File Map

- Create: `packages/zigeffect/tools/causal_production_hardening_backlog_refresh.zig`
  - CLI parser, source backlog JSON parser, candidate model, checks, JSON/text rendering, tests.
- Create: `packages/zigeffect/docs/production-hardening-backlog-refresh.md`
  - Operator and agent documentation for the refresh artifact.
- Modify: `packages/zigeffect/build.zig`
  - Register executable, build step, and test dependency.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Add schema entry and bump schema count from 79 to 80.
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Add delivered backlog-refresh item, append dependency order, add verification commands, and advance recommendation to NenDB durable-history hardening.
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
  - Document refresh delivery and next branch.
- Modify: `packages/zigeffect/docs/operations.md`
  - Add run instructions and interpretation boundary.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Record the handoff to NenDB durable-history hardening.
- Modify: `packages/zigeffect/README.md`
  - Add command mention.
- Modify: `packages/zigeffect/docs/schema-governance.md`
  - Add schema line and schema count.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark backlog refresh delivered and add the next branch.

## Task 1: Write The Failing Refresh Tool Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_production_hardening_backlog_refresh.zig`

- [x] **Step 1: Add constants, fixtures, and tests first**

Create the file with enough code to compile tests but intentionally fail the selected next-branch assertion:

```zig
const std = @import("std");

pub const production_hardening_backlog_refresh_schema = "zigeffect.causal.production-hardening-backlog-refresh.v1";
pub const production_hardening_backlog_refresh_schema_version: u32 = 1;
pub const source_backlog_schema = "zigeffect.causal.production-hardening-backlog.v1";
pub const source_branch = "codex/zigeffect-causal-production-hardening-backlog-refresh";
pub const recommendation = "start-nendb-durable-history-hardening";
pub const next_branch_if_ready = "codex/zigeffect-causal-nendb-durable-history-hardening";

test "refresh constants preserve the NenDB-only handoff" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.production-hardening-backlog-refresh.v1",
        production_hardening_backlog_refresh_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), production_hardening_backlog_refresh_schema_version);
    try std.testing.expectEqualStrings("start-nendb-durable-history-hardening", recommendation);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-nendb-durable-history-hardening",
        next_branch_if_ready,
    );
}

test "refresh report selects durable history and not Cockroach" {
    const allocator = std.testing.allocator;
    const report = try formatTextReport(allocator, readySourceBacklogJson(), "refresh reviewed", &.{
        "zig build causal-production-hardening-backlog -- --format json",
        "zig build causal-schema-governance -- --format json",
    });
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "backlog refresh status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "selected next branch: codex/zigeffect-causal-nendb-durable-history-hardening") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "Cockroach") == null);
}

fn formatTextReport(_: std.mem.Allocator, _: []const u8, _: []const u8, _: []const []const u8) ![]const u8 {
    return error.NotImplemented;
}

fn readySourceBacklogJson() []const u8 {
    return
        \\{
        \\  "schema": "zigeffect.causal.production-hardening-backlog.v1",
        \\  "schema_version": 1,
        \\  "recommendation": "refresh-production-hardening-backlog",
        \\  "recommended_next_branch": "codex/zigeffect-causal-production-hardening-backlog-refresh",
        \\  "backlog_items": [
        \\    {
        \\      "id": "production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
        \\      "status": "delivered",
        \\      "branch": "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy"
        \\    }
        \\  ],
        \\  "verification_commands": [
        \\    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy"
        \\  ]
        \\}
    ;
}
```

- [x] **Step 2: Run the red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog_refresh.zig
```

Expected: fails with `error.NotImplemented`.

## Task 2: Implement The Refresh Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog_refresh.zig`

- [x] **Step 1: Add CLI option parsing**

Implement:

```text
zig build causal-production-hardening-backlog-refresh -- --from-backlog <path> refresh --reason <reason> [--verified-command <command>]... [--out-prefix <prefix>]
```

Required parser behavior:

- `--help` prints usage and exits 0.
- Missing `--from-backlog`, missing path, missing `refresh`, missing reason, unknown flags, and non-JSON backlog path fail closed.
- `--verified-command` may be repeated.
- `--out-prefix` controls both `.json` and `.txt` outputs.

- [x] **Step 2: Add source backlog structs**

Use `std.json.parseFromSlice` with `ignore_unknown_fields=true` and these fields:

```zig
const BacklogArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    recommendation: []const u8 = "",
    recommended_next_branch: []const u8 = "",
    backlog_items: []const BacklogItem = &.{},
    verification_commands: []const []const u8 = &.{},
};

const BacklogItem = struct {
    id: []const u8 = "",
    status: []const u8 = "",
    branch: []const u8 = "",
};
```

- [x] **Step 3: Add candidate and check models**

Define stable candidates:

```zig
const unresolved_candidates = &.{
    Candidate{
        .id = "nendb-durable-history-hardening",
        .title = "NenDB Durable History Hardening",
        .recommended_branch = "codex/zigeffect-causal-nendb-durable-history-hardening",
        .priority = "P0",
        .why_now = "Durable causal history is the next foundation for self-improving agents, cross-run comparison, replay evidence, and app-facing reuse.",
        .depends_on = &.{ "production-hardening-backlog-refresh", "causal-nendb-storage-backend", "production-telemetry-nendb-retention-fixtures" },
        .blocked_claims = &.{ "Cockroach adapter scope", "live production write", "production health proof", "mutation authority" },
    },
    Candidate{
        .id = "agent-query-cross-run-comparison",
        .title = "Agent Query Cross-Run Comparison",
        .recommended_branch = "codex/zigeffect-causal-agent-query-compare-runs",
        .priority = "P1",
        .why_now = "The existing agent query interface is partial because compare_runs remains future work.",
        .depends_on = &.{ "nendb-durable-history-hardening" },
        .blocked_claims = &.{ "unbounded query response", "unredacted trace payload" },
    },
};
```

Checks required for ready status:

- source schema matches `source_backlog_schema`;
- source recommendation is `refresh-production-hardening-backlog` or `start-nendb-durable-history-hardening`;
- source branch is the refresh branch or the selected NenDB branch;
- terminal item exists with `status=delivered`;
- terminal build command exists in `verification_commands`;
- selected branch contains `nendb` and does not contain `cockroach`;
- mutation authority remains `none`;
- no live telemetry or durable write flag is enabled.

- [x] **Step 4: Render text and JSON reports**

Text report must include:

```text
zigeffect causal production hardening backlog refresh
schema: zigeffect.causal.production-hardening-backlog-refresh.v1
backlog refresh status: ready
ready for next branch: true
selected next work: nendb-durable-history-hardening
selected next branch: codex/zigeffect-causal-nendb-durable-history-hardening
mutation authority: none
denied claims:
```

JSON report must include:

```json
{
  "schema": "zigeffect.causal.production-hardening-backlog-refresh.v1",
  "schema_version": 1,
  "generated_by": "causal-production-hardening-backlog-refresh",
  "backlog_refresh_status": "ready",
  "ready_for_next_branch": true,
  "selected_next_work": "nendb-durable-history-hardening",
  "selected_next_branch": "codex/zigeffect-causal-nendb-durable-history-hardening",
  "mutation_authority": "none"
}
```

- [x] **Step 5: Add negative tests**

Tests must cover:

- wrong source schema blocks;
- unsupported source recommendation blocks;
- missing terminal delivered item blocks;
- missing terminal verification command blocks;
- selected candidate denies Cockroach and non-NenDB durable adapter claims;
- JSON report includes `ready_for_next_branch`.

- [x] **Step 6: Run green focused tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog_refresh.zig
```

Expected: all tests pass.

## Task 3: Register Build Step And Schema

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`

- [x] **Step 1: Register build step and test dependency**

In `build.zig`, add a module/executable/run step/test block near the other production hardening tools:

```zig
const causal_production_hardening_backlog_refresh_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_hardening_backlog_refresh.zig"),
    .target = target,
    .optimize = optimize,
});
const causal_production_hardening_backlog_refresh_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-hardening-backlog-refresh",
    .root_module = causal_production_hardening_backlog_refresh_tool_module,
});
const run_causal_production_hardening_backlog_refresh_tool = b.addRunArtifact(causal_production_hardening_backlog_refresh_tool);
if (b.args) |args| run_causal_production_hardening_backlog_refresh_tool.addArgs(args);
const causal_production_hardening_backlog_refresh_step = b.step("causal-production-hardening-backlog-refresh", "Refresh production hardening backlog and select next unresolved branch");
causal_production_hardening_backlog_refresh_step.dependOn(&run_causal_production_hardening_backlog_refresh_tool.step);
const causal_production_hardening_backlog_refresh_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-hardening-backlog-refresh-tests",
    .root_module = causal_production_hardening_backlog_refresh_tool_module,
});
const run_causal_production_hardening_backlog_refresh_tool_tests = b.addRunArtifact(causal_production_hardening_backlog_refresh_tool_tests);
test_step.dependOn(&run_causal_production_hardening_backlog_refresh_tool_tests.step);
```

- [x] **Step 2: Add schema governance entry**

Add:

```zig
.{
    .schema = "zigeffect.causal.production-hardening-backlog-refresh.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-hardening-backlog-refresh"},
    .consumed_by = &.{ "agents", "reviewers", "future NenDB durable history hardening" },
    .compatibility = &.{ "strict-v1", "read-only", "nendb-only", "local-artifact-only", "no-cockroach", "no-live-telemetry", "no-durable-write", "no-nendb-write", "no-mutation-authority" },
    .governance_requirements = &.{ "source backlog checks", "terminal delivered item check", "candidate selection checks", "denied inference checks", "next branch handoff" },
},
```

Update schema-count tests from `79` to `80` and add assertions for the new schema.

- [x] **Step 3: Verify build help and schema governance**

Run:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog-refresh -- --help
zig build causal-schema-governance -- --format json
```

Expected:

- help prints usage;
- schema governance exits 0 and reports `schema_count: 80`.

## Task 4: Refresh The Backlog And Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/production-hardening-backlog-refresh.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [x] **Step 1: Advance backlog recommendation**

Change constants:

```zig
pub const recommendation = "start-nendb-durable-history-hardening";
pub const recommended_next_branch = "codex/zigeffect-causal-nendb-durable-history-hardening";
```

Add delivered item:

```zig
.{
    .id = "production-hardening-backlog-refresh",
    .title = "Production Hardening Backlog Refresh",
    .gap_id = "production-hardening-backlog-refresh",
    .priority = "P5",
    .status = "delivered",
    .summary = "Closes the delivered production-hardening queue, records unresolved candidates, and selects NenDB durable-history hardening as the next branch.",
    .depends_on = &.{ "production-telemetry-ci-gate-required-status-check-enforcement-report-policy" },
    .deliverables = &.{ "refresh artifact schema", "unresolved candidate catalog", "NenDB durable-history handoff", "denied production and mutation claims" },
    .evidence_sources = &.{ "packages/zigeffect/tools/causal_production_hardening_backlog_refresh.zig", "packages/zigeffect/docs/production-hardening-backlog-refresh.md" },
    .branch = "codex/zigeffect-causal-production-hardening-backlog-refresh",
    .agent_guidance = "Use this refresh as a handoff artifact only. The selected next branch is NenDB durable-history hardening; do not infer production health, production cluster readiness, live telemetry, durable writes, NenDB writes, Cockroach scope, or mutation authority.",
},
```

Append `production-hardening-backlog-refresh` to `dependency_order` and add refresh build commands to `verification_commands`.

- [x] **Step 2: Update backlog tests**

Update tests to expect:

- recommendation `start-nendb-durable-history-hardening`;
- recommended branch `codex/zigeffect-causal-nendb-durable-history-hardening`;
- delivered item `production-hardening-backlog-refresh`;
- JSON/text reports mention `causal-production-hardening-backlog-refresh`.

- [x] **Step 3: Write refresh docs**

Create `packages/zigeffect/docs/production-hardening-backlog-refresh.md` with:

- schema and build step;
- CLI example;
- selected next branch;
- candidate list;
- authority boundary;
- verification commands.

- [x] **Step 4: Update roadmap and README docs**

Update docs so agents see:

- production hardening backlog refresh delivered;
- selected next branch is `codex/zigeffect-causal-nendb-durable-history-hardening`;
- no Cockroach or non-NenDB durable adapter work;
- no live telemetry, durable write, production health, or mutation authority.

- [x] **Step 5: Run backlog tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-hardening-backlog -- --format json
```

Expected:

- tests pass;
- JSON report contains `recommended_next_branch: codex/zigeffect-causal-nendb-durable-history-hardening`.

## Task 5: Verify CLI Artifacts And Full Build

**Files:**
- All modified files from Tasks 1 through 4.

- [x] **Step 1: Generate current backlog source artifact**

Run:

```sh
cd packages/zigeffect
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-production-hardening-backlog -- --format json 2> ../../.zig-cache/causal-artifacts/production-hardening-backlog.json
```

Expected: JSON artifact exists and uses `zigeffect.causal.production-hardening-backlog.v1`.

- [x] **Step 2: Run refresh positive path**

Run:

```sh
zig build causal-production-hardening-backlog-refresh -- \
  --from-backlog ../../.zig-cache/causal-artifacts/production-hardening-backlog.json \
  refresh \
  --reason "production hardening backlog refreshed after report policy" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Expected:

- command exits 0;
- JSON/text artifacts are written;
- status is ready;
- selected branch is `codex/zigeffect-causal-nendb-durable-history-hardening`.

- [x] **Step 3: Run refresh negative path**

Create a temporary unsupported-recommendation fixture and run it through the
CLI:

```sh
cat > /tmp/production-hardening-backlog-refresh-negative.json <<'JSON'
{
  "schema": "zigeffect.causal.production-hardening-backlog.v1",
  "schema_version": 1,
  "recommendation": "start-cockroach-durable-history",
  "recommended_next_branch": "codex/zigeffect-causal-cockroach-durable-history",
  "backlog_items": [
    {
      "id": "production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
      "status": "delivered",
      "branch": "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy"
    }
  ],
  "verification_commands": [
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy"
  ]
}
JSON

zig build causal-production-hardening-backlog-refresh -- \
  --from-backlog /tmp/production-hardening-backlog-refresh-negative.json \
  refresh \
  --reason "negative production hardening backlog refresh path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-hardening-backlog-refresh-negative
```

Expected: blocked status, `ready_for_next_branch=false`, and no mutation authority.

- [x] **Step 4: Run focused and integration verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog_refresh.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-hardening-backlog-refresh -- --help
zig build causal-schema-governance -- --format json
zig build examples
zig build test
zig fmt --check build.zig \
  tools/causal_production_hardening_backlog_refresh.zig \
  tools/causal_production_hardening_backlog.zig \
  tools/causal_schema_governance.zig
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

- [x] **Step 5: Commit implementation**

Run:

```sh
git add docs/superpowers/plans/2026-06-10-zigeffect-causal-production-hardening-backlog-refresh-implementation.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/production-hardening-backlog-refresh.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog_refresh.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git diff --cached --check
git commit -m "feat(zigeffect): add production hardening backlog refresh"
```

Expected: commit succeeds on branch `codex/zigeffect-causal-production-hardening-backlog-refresh`.
