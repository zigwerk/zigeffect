# zigeffect Causal Production Telemetry Readiness Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a schema-governed, record-only production telemetry readiness review tool that consumes capture fixture JSON and emits ready or blocked review artifacts.

**Architecture:** Create one focused Zig report tool that follows the registry/app readiness pattern: parse options, read a prior artifact, evaluate deterministic checks, write JSON/text outputs, and print the text report. Register the schema and milestone in the existing build, governance, backlog, and docs surfaces.

**Tech Stack:** Zig 0.16 build steps and tests, existing zigeffect causal report conventions, Markdown docs, Bun workspace verification.

---

## Files And Responsibilities

- Create `packages/zigeffect/tools/causal_production_telemetry_readiness_review.zig`
  - Owns schema `zigeffect.causal.production-telemetry-readiness-review.v1`.
  - Parses `--from-fixtures <path> approve|reject --reason <reason>`.
  - Supports `--by`, `--policy`, repeated `--verified-command`, and
    `--out-prefix`.
  - Parses fixture JSON using the delivered fixture schema shape.
  - Evaluates readiness checks for schema, status, authority, source contracts,
    positive fixture coverage, negative fixture coverage, validation checks,
    NenDB direction, SolidJS direction, and verification command evidence.
  - Writes `.json` and `.txt` readiness artifacts and prints the text report.
  - Tests option parsing, path derivation, ready output, blocked output, missing
    verification, unsupported fixture state, and guardrail fields.

- Modify `packages/zigeffect/build.zig`
  - Adds `causal-production-telemetry-readiness-review` executable step.
  - Adds tool tests to `zig build test`.
  - Adds the executable and tests to `zig build examples`.

- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Registers `zigeffect.causal.production-telemetry-readiness-review.v1`.
  - Updates schema count from `52` to `53`.
  - Adds text/JSON test assertions for the new schema.

- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Adds `production-telemetry-readiness-review` as delivered.
  - Updates recommendation to `start-production-telemetry-implementation-proposal`.
  - Updates recommended next branch to
    `codex/zigeffect-causal-production-telemetry-implementation-proposal`.
  - Adds readiness-review commands to verification commands.

- Create `packages/zigeffect/docs/production-telemetry-readiness-review.md`
  - Documents command usage, schema, checks, statuses, guardrails, output paths,
    and verification.

- Modify docs:
  - `packages/zigeffect/README.md`
  - `packages/zigeffect/docs/operations.md`
  - `packages/zigeffect/docs/schema-governance.md`
  - `packages/zigeffect/docs/production-hardening-backlog.md`
  - `packages/zigeffect/docs/production-telemetry-capture-fixtures.md`
  - `packages/zigeffect/docs/roadmap.md`
  - `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Command Contract

```sh
cd packages/zigeffect
zig build causal-production-telemetry-capture-fixtures -- --format json \
  > ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Required verification commands inside the readiness artifact:

```text
zig build causal-production-telemetry-capture-fixtures -- validate --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

## Task 1: Add Failing Tool Tests

**Files:**

- Create: `packages/zigeffect/tools/causal_production_telemetry_readiness_review.zig`

- [ ] **Step 1: Add the initial test-first skeleton**

Create the file with constants, small types, failing implementations, and tests:

```zig
const std = @import("std");

pub const production_telemetry_readiness_review_schema = "zigeffect.causal.production-telemetry-readiness-review.v1";
pub const production_telemetry_readiness_review_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-readiness-review";
pub const recommendation = "start-production-telemetry-implementation-proposal";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-implementation-proposal";

const fixture_schema = "zigeffect.causal.production-telemetry-capture-fixtures.v1";
const generated_by = "causal-production-telemetry-readiness-review";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const durable_write_enabled = false;
const ci_gate_enabled = false;

const Decision = enum { approve, reject };
const ReadinessStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail, skipped };

const Options = struct {
    fixtures_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "local-reviewer",
    policy: []const u8 = "manual-production-telemetry-readiness",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        if (self.verified_commands.len > 0) allocator.free(self.verified_commands);
    }
};

const OutputPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    fn deinit(self: OutputPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    _ = allocator;
    _ = args;
    return error.ExpectedRedFailure;
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    _ = allocator;
    _ = options;
    return error.ExpectedRedFailure;
}

fn formatReports(allocator: std.mem.Allocator, input: ReadinessInput) !ReadinessReports {
    _ = allocator;
    _ = input;
    return error.ExpectedRedFailure;
}
```

Add tests in the same file:

```zig
test "production telemetry readiness exposes schema and blocked authority constants" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-readiness-review.v1", production_telemetry_readiness_review_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_readiness_review_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-readiness-review", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-implementation-proposal", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-implementation-proposal", next_branch_if_ready);
    try std.testing.expect(!applied);
    try std.testing.expectEqualStrings("none", mutation_authority);
    try std.testing.expect(!production_telemetry_ingestion);
    try std.testing.expect(!live_exporter_enabled);
    try std.testing.expect(!durable_write_enabled);
    try std.testing.expect(!ci_gate_enabled);
}

test "production telemetry readiness parses approve decision verified commands and output prefix" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-readiness-review",
        "--from-fixtures",
        ".zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json",
        "approve",
        "--reason",
        "fixtures reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-readiness",
        "--verified-command",
        "zig build test",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-telemetry",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json", options.fixtures_path);
    try std.testing.expectEqualStrings("fixtures reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-readiness", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build test", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-telemetry", options.out_prefix.?);
}

test "production telemetry readiness rejects missing required arguments" {
    try std.testing.expectError(error.MissingFixturesPath, parseOptions(std.testing.allocator, &.{"zigeffect-causal-production-telemetry-readiness-review"}));
    try std.testing.expectError(error.InvalidFixturesPath, parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-readiness-review", "--from-fixtures", "fixtures.txt", "approve", "--reason", "reviewed" }));
    try std.testing.expectError(error.MissingDecision, parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-readiness-review", "--from-fixtures", "fixtures.json" }));
    try std.testing.expectError(error.UnknownDecision, parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-readiness-review", "--from-fixtures", "fixtures.json", "maybe", "--reason", "reviewed" }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-readiness-review", "--from-fixtures", "fixtures.json", "approve" }));
}
```

- [ ] **Step 2: Run the focused test and verify red**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_readiness_review.zig
```

Expected: fails with `ExpectedRedFailure` from option/path/report functions.

## Task 2: Implement Readiness Evaluation And Output

**Files:**

- Modify: `packages/zigeffect/tools/causal_production_telemetry_readiness_review.zig`

- [ ] **Step 1: Implement option parsing**

Add `parseDecision`, `parseOptions`, and argument validation matching the spec.
Use repeated `--verified-command` values in an owned slice and free them in
`Options.deinit`.

- [ ] **Step 2: Implement path derivation**

`outputPathsForOptions` should:

- use `--out-prefix` directly when present;
- otherwise strip `.json` from `fixtures_path`;
- append `-readiness-review.json` and `-readiness-review.txt` when no prefix is
  provided;
- append `.json` and `.txt` directly when a custom prefix is provided.

Add or keep tests asserting:

```zig
test "production telemetry readiness output paths derive from fixtures path and out prefix" {
    const derived = try outputPathsForOptions(std.testing.allocator, .{
        .fixtures_path = ".zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json",
        .decision = .approve,
        .reason = "reviewed",
    });
    defer derived.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json", derived.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.txt", derived.text_path);

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .fixtures_path = ".zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json",
        .decision = .approve,
        .reason = "reviewed",
        .out_prefix = ".zig-cache/causal-artifacts/custom-telemetry",
    });
    defer custom.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-telemetry.json", custom.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-telemetry.txt", custom.text_path);
}
```

- [ ] **Step 3: Define fixture JSON structs**

Define structs for the fixture JSON shape with `.ignore_unknown_fields = true`:

- `FixtureCatalog`
- `SourceContract`
- `PositiveFixture`
- `NegativeFixture`
- `ValidationCheck`

Include only fields needed by readiness checks:

```zig
const FixtureCatalog = struct {
    schema: []const u8,
    schema_version: u32,
    status: []const u8,
    source_branch: []const u8 = "",
    recommendation: []const u8 = "",
    next_branch: []const u8 = "",
    applied: bool,
    mutation_authority: []const u8,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    durable_write_enabled: bool,
    ci_gate_enabled: bool,
    source_contracts: []const SourceContract = &.{},
    positive_fixtures: []const PositiveFixture = &.{},
    negative_fixtures: []const NegativeFixture = &.{},
    validation_checks: []const ValidationCheck = &.{},
    non_goals: []const []const u8 = &.{},
};
```

- [ ] **Step 4: Implement checks**

Implement `evaluateReadiness` so it appends checks in this order:

1. `fixture-schema`
2. `fixture-status`
3. `reviewer-decision`
4. `decision-approved`
5. `authority-boundary`
6. `source-contracts-present`
7. `positive-fixture-coverage`
8. `negative-fixture-coverage`
9. `validation-checks-passed`
10. `nendb-only-retention`
11. `solid-webui-direction`
12. `required-verification-recorded`

Readiness is `ready` only when every check passes.

- [ ] **Step 5: Implement text and JSON formatting**

The JSON report must include:

- top-level schema fields from the design;
- `fixture_summary` with counts of source contracts, positive fixtures,
  negative fixtures, and validation checks;
- `checks`;
- `required_verification_commands`;
- `verified_commands`;
- `implementation_proposal_steps`;
- `readiness_guardrails`.

The text report must include the schema, source fixture path, decision,
readiness status, authority fields, checks, commands, next steps, and guardrails.

- [ ] **Step 6: Implement file IO and `main`**

`main` should read the fixture JSON, format reports, write both artifacts, and
print text. Missing fixture input maps to `MissingFixturesInput`.

- [ ] **Step 7: Run focused tests and verify green**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_readiness_review.zig
```

Expected: all readiness-review tests pass.

## Task 3: Wire The Build

**Files:**

- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add build step and tests**

Add a module/executable/test block adjacent to
`causal-production-telemetry-capture-fixtures`:

```zig
const causal_production_telemetry_readiness_review_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_readiness_review.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_production_telemetry_readiness_review_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-telemetry-readiness-review",
    .root_module = causal_production_telemetry_readiness_review_tool_module,
});
const run_causal_production_telemetry_readiness_review_tool = b.addRunArtifact(causal_production_telemetry_readiness_review_tool);
if (b.args) |args| run_causal_production_telemetry_readiness_review_tool.addArgs(args);
const causal_production_telemetry_readiness_review_step = b.step("causal-production-telemetry-readiness-review", "Review production telemetry fixture readiness");
causal_production_telemetry_readiness_review_step.dependOn(&run_causal_production_telemetry_readiness_review_tool.step);

const causal_production_telemetry_readiness_review_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-telemetry-readiness-review-tests",
    .root_module = causal_production_telemetry_readiness_review_tool_module,
});
const run_causal_production_telemetry_readiness_review_tool_tests = b.addRunArtifact(causal_production_telemetry_readiness_review_tool_tests);
test_step.dependOn(&run_causal_production_telemetry_readiness_review_tool_tests.step);
```

Add the tool and tests to `examples_step` dependencies.

- [ ] **Step 2: Run build test for the new step**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-readiness-review -- --from-fixtures missing.json approve --reason reviewed
```

Expected: fails with a missing input error, proving the step is callable.

## Task 4: Register Governance And Backlog

**Files:**

- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Register schema governance**

Add schema entry:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-readiness-review.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-readiness-review"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry implementation proposal" },
    .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "readiness-review", "no-live-ingestion" },
    .governance_requirements = &.{ "readiness review tests", "fixture evidence checks", "verification command evidence", "next-branch handoff" },
},
```

Update schema count and test assertions to `53`.

- [ ] **Step 2: Update hardening backlog**

Add delivered backlog item:

```zig
.{
    .id = "production-telemetry-readiness-review",
    .title = "Production Telemetry Readiness Review",
    .gap_id = "production-telemetry-readiness-review",
    .priority = "P5",
    .status = "delivered",
    .summary = "Consumes production telemetry capture fixture JSON and emits ready or blocked review artifacts before any implementation proposal work.",
    .depends_on = &.{ "production-telemetry-capture-fixtures", "production-telemetry-capture-design" },
    .deliverables = &.{
        "fixture JSON readiness review",
        "reviewer decision and reason recording",
        "required verification command evidence",
        "ready and blocked readiness artifacts",
        "implementation proposal handoff",
    },
    .evidence_sources = &.{
        "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-readiness-review-design.md",
        "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-readiness-review-implementation.md",
        "packages/zigeffect/tools/causal_production_telemetry_readiness_review.zig",
        "packages/zigeffect/docs/production-telemetry-readiness-review.md",
    },
    .branch = "codex/zigeffect-causal-production-telemetry-readiness-review",
    .agent_guidance = "Use readiness review artifacts to decide whether a future implementation-proposal branch may start; do not infer live telemetry or mutation authority.",
},
```

Update:

```zig
pub const recommendation = "start-production-telemetry-implementation-proposal";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-implementation-proposal";
```

Add readiness commands to `verification_commands`.

- [ ] **Step 3: Run report tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: both pass.

## Task 5: Update Documentation

**Files:**

- Create: `packages/zigeffect/docs/production-telemetry-readiness-review.md`
- Modify docs listed in the file responsibilities section.

- [ ] **Step 1: Create readiness review doc**

Include sections:

- command;
- schema;
- boundary fields;
- statuses;
- checks;
- required verification commands;
- output paths;
- agent guidance;
- verification.

- [ ] **Step 2: Update existing docs**

Update current-next references from readiness review to implementation proposal
only after documenting that readiness review is delivered. Preserve explicit
no-live-ingestion, no non-NenDB adapter, no alternate renderer, and
mutation-authority-none boundaries.

- [ ] **Step 3: Run docs search**

Run:

```sh
rg -n "production-telemetry-readiness-review|start-production-telemetry-implementation-proposal|production telemetry implementation proposal" packages/zigeffect docs/superpowers
```

Expected: docs and tool references are present in the intended files.

## Task 6: Final Verification And Commit

**Files:**

- All created and modified files from prior tasks.

- [ ] **Step 1: Generate fixture artifact and run ready path**

Run:

```sh
cd packages/zigeffect
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-production-telemetry-capture-fixtures -- --format json \
  > ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Expected: text output contains `readiness_status: ready`, `applied: false`,
and `mutation_authority: none`.

- [ ] **Step 2: Run blocked path**

Run:

```sh
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  reject \
  --reason "negative readiness path"
```

Expected: text output contains `readiness_status: blocked`.

- [ ] **Step 3: Run package verification**

Run:

```sh
zig test tools/causal_production_telemetry_readiness_review.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

Expected: all commands exit 0.

- [ ] **Step 4: Run repo verification**

Run:

```sh
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit implementation**

Run:

```sh
git status --short --branch
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-readiness-review-implementation.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/production-telemetry-capture-fixtures.md \
  packages/zigeffect/docs/production-telemetry-readiness-review.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_production_telemetry_readiness_review.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add production telemetry readiness review"
```

Expected: commit succeeds with only intended files staged.

## Self-Review

- Spec coverage: every design goal maps to a task above.
- Incomplete marker scan: no incomplete markers are present.
- Type consistency: command names, schema names, branch names, and status names
  are consistent across tasks.
