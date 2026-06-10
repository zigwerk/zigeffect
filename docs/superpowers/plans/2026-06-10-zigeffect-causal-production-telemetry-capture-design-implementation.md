# zigeffect Causal Production Telemetry Capture Design Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a schema-governed, deterministic production telemetry capture design report that tells agents and reviewers how future telemetry may be captured without enabling live ingestion, exporters, durable writes, CI gates, capacity claims, or mutation authority.

**Architecture:** Create one record-only Zig report tool that emits text and JSON from static, reviewed tables. Wire it into `build.zig`, schema governance, the production-hardening backlog, and docs so the branch becomes a cited handoff to safe fixture work.

**Tech Stack:** Zig 0.16 build steps and tests, existing zigeffect causal report patterns, Markdown docs, Bun verification commands.

---

## Files And Responsibilities

- Create `packages/zigeffect/tools/causal_production_telemetry_capture_design.zig`
  - Owns schema `zigeffect.causal.production-telemetry-capture-design.v1`.
  - Emits text and JSON reports for capture surfaces, telemetry fields, gates, negative fixtures, non-goals, agent guidance, and verification commands.
  - Hard-codes `applied=false`, `mutation_authority="none"`, `production_telemetry_ingestion=false`, and `live_exporter_enabled=false`.
  - Tests parser behavior, report contents, JSON contents, negative fixture coverage, and forbidden-authority boundaries.

- Modify `packages/zigeffect/build.zig`
  - Adds `causal-production-telemetry-capture-design` executable step.
  - Adds the tool tests to `zig build test`.
  - Adds the tool and tests to `zig build examples`.

- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Registers `zigeffect.causal.production-telemetry-capture-design.v1`.
  - Updates tests to expect the new schema in text and JSON reports.

- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Adds `production-telemetry-capture-design` as delivered.
  - Updates recommendation to `start-production-telemetry-capture-fixtures`.
  - Updates recommended next branch to `codex/zigeffect-causal-production-telemetry-capture-fixtures`.
  - Adds the new command to verification commands.

- Create `packages/zigeffect/docs/production-telemetry-capture-design.md`
  - Documents command usage, schema, capture surfaces, field contract, readiness gates, negative fixtures, and non-goals.

- Modify docs:
  - `packages/zigeffect/README.md`
  - `packages/zigeffect/docs/operations.md`
  - `packages/zigeffect/docs/schema-governance.md`
  - `packages/zigeffect/docs/load-test-observation-harness.md`
  - `packages/zigeffect/docs/production-hardening-backlog.md`
  - `packages/zigeffect/docs/roadmap.md`
  - `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Command Contract

Supported invocations:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-capture-design
zig build causal-production-telemetry-capture-design -- --format json
```

Parser rules:

- No args after the executable means text.
- `--format text` means text.
- `--format json` means JSON.
- `--format` without a value returns `error.MissingFormat`.
- Unknown formats return `error.UnknownFormat`.
- Any other flag returns `error.UnknownFlag`.

## Task 1: Add Failing Tool Tests

**Files:**

- Create `packages/zigeffect/tools/causal_production_telemetry_capture_design.zig`

- [ ] **Step 1: Create the initial tool skeleton and failing tests**

Use this initial skeleton:

```zig
const std = @import("std");

pub const production_telemetry_capture_design_schema = "zigeffect.causal.production-telemetry-capture-design.v1";
pub const production_telemetry_capture_design_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-capture-design";
pub const recommendation = "start-production-telemetry-capture-fixtures";
pub const next_branch = "codex/zigeffect-causal-production-telemetry-capture-fixtures";

const OutputFormat = enum { text, json };

const generated_by = "causal-production-telemetry-capture-design";
const status = "design-only";
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const applied = false;

const SourceContract = struct {
    id: []const u8,
    schema: []const u8,
    producer: []const u8,
    evidence_role: []const u8,
    authority_boundary: []const u8,
};

const CaptureSurface = struct {
    id: []const u8,
    source: []const u8,
    signal: []const u8,
    boundary: []const u8,
    agent_guidance: []const u8,
};

const TelemetryField = struct {
    name: []const u8,
    required: bool,
    purpose: []const u8,
    forbidden_values: []const []const u8,
};

const ReadinessGate = struct {
    id: []const u8,
    decision: []const u8,
    required_evidence: []const []const u8,
    blocks_until: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    attempted_claim: []const u8,
    decision: []const u8,
    reason: []const u8,
};

const AgentRule = struct {
    id: []const u8,
    guidance: []const u8,
};

fn parseOptions(args: []const []const u8) !OutputFormat {
    _ = args;
    return error.ExpectedRedFailure;
}

fn formatText(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return error.ExpectedRedFailure;
}

fn formatJson(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return error.ExpectedRedFailure;
}

test "production telemetry capture design exposes schema and blocked authority constants" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-capture-design.v1", production_telemetry_capture_design_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_capture_design_schema_version);
    try std.testing.expectEqualStrings("start-production-telemetry-capture-fixtures", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-capture-fixtures", next_branch);
    try std.testing.expectEqualStrings("none", mutation_authority);
    try std.testing.expect(!production_telemetry_ingestion);
    try std.testing.expect(!live_exporter_enabled);
    try std.testing.expect(!applied);
}

test "production telemetry capture design parses output format options" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-production-telemetry-capture-design"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-production-telemetry-capture-design", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-production-telemetry-capture-design", "--format", "json" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-production-telemetry-capture-design", "--format" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-production-telemetry-capture-design", "--format", "yaml" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-production-telemetry-capture-design", "--json" }));
}

test "production telemetry capture design text report states non-live boundary" {
    const report = try formatText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.production-telemetry-capture-design.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production telemetry ingestion: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "live exporter enabled: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation authority: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "capture surface: runtime-trace") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "readiness gate: retention-nendb-compatible") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "negative fixture: raw-request-body-capture") != null);
}

test "production telemetry capture design json report is machine readable and bounded" {
    const report = try formatJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-capture-design.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"production_telemetry_ingestion\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"live_exporter_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"capture_surface_id\": \"runtime-trace\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"otel-bridge-reviewed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"cockroach-adapter-work\"") != null);
}
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_capture_design.zig
```

Expected: FAIL with `ExpectedRedFailure` from `parseOptions`, `formatText`, or `formatJson`.

## Task 2: Implement Report Model And Renderers

**Files:**

- Modify `packages/zigeffect/tools/causal_production_telemetry_capture_design.zig`

- [ ] **Step 1: Add static report tables**

Add arrays named exactly:

```zig
const source_contracts: []const SourceContract = &.{ ... };
const capture_surfaces: []const CaptureSurface = &.{ ... };
const telemetry_fields: []const TelemetryField = &.{ ... };
const readiness_gates: []const ReadinessGate = &.{ ... };
const negative_fixtures: []const NegativeFixture = &.{ ... };
const agent_rules: []const AgentRule = &.{ ... };
const non_goals: []const []const u8 = &.{ ... };
const verification_commands: []const []const u8 = &.{ ... };
```

Minimum required table entries:

- Source contracts:
  - `load-test-observation-harness`
  - `causal-otel-record`
  - `backend-conformance`
  - `production-artifact-aggregation`
  - `artifact-access-control`
  - `encryption-at-rest-policy`
  - `production-capacity-planning`
- Capture surfaces:
  - `runtime-trace`
  - `app-semantic`
  - `backend-export-otel`
  - `redaction-access`
  - `local-observation-correlation`
- Telemetry fields:
  - `capture_surface_id`
  - `source_schema`
  - `signal_kind`
  - `event_kind_policy`
  - `redaction_state`
  - `sampling_policy`
  - `retention_policy`
  - `access_policy_ref`
  - `encryption_policy_ref`
  - `telemetry_transport_state`
  - `durable_write_state`
  - `local_observation_refs`
  - `review_gate`
  - `blocked_claims`
- Readiness gates:
  - `schema-registered`
  - `redaction-reviewed`
  - `sampling-bounded`
  - `retention-nendb-compatible`
  - `access-policy-reviewed`
  - `encryption-policy-reviewed`
  - `otel-bridge-reviewed`
  - `local-observation-separated`
  - `capacity-claim-blocked`
  - `fixture-handoff-ready`
- Negative fixtures:
  - `live-exporter-enabled`
  - `otlp-collector-endpoint-configured`
  - `raw-request-body-capture`
  - `raw-header-capture`
  - `raw-prompt-capture`
  - `credential-token-capture`
  - `unbounded-attribute-cardinality`
  - `sampled-out-event-forwarded`
  - `local-observation-as-production-capacity`
  - `non-nendb-durable-storage`
  - `cockroach-adapter-work`
  - `react-or-alternate-renderer`
  - `ci-telemetry-gate`
  - `mutation-authority-granted`

- [ ] **Step 2: Implement option parsing**

Replace the stub with:

```zig
fn parseOptions(args: []const []const u8) !OutputFormat {
    if (args.len == 1) return .text;
    if (args.len == 3 and std.mem.eql(u8, args[1], "--format")) {
        if (std.mem.eql(u8, args[2], "text")) return .text;
        if (std.mem.eql(u8, args[2], "json")) return .json;
        return error.UnknownFormat;
    }
    if (args.len == 2 and std.mem.eql(u8, args[1], "--format")) return error.MissingFormat;
    return error.UnknownFlag;
}
```

- [ ] **Step 3: Implement text and JSON renderers**

Implement helpers in the same style as `causal_production_capacity_planning.zig`:

```zig
fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void { ... }
fn appendJsonStringArray(output: *std.ArrayList(u8), allocator: std.mem.Allocator, values: []const []const u8) !void { ... }
fn boolText(value: bool) []const u8 { return if (value) "true" else "false"; }
```

`formatText` must print:

```text
schema: zigeffect.causal.production-telemetry-capture-design.v1
schema version: 1
status: design-only
generated by: causal-production-telemetry-capture-design
source branch: codex/zigeffect-causal-production-telemetry-capture-design
recommendation: start-production-telemetry-capture-fixtures
next branch: codex/zigeffect-causal-production-telemetry-capture-fixtures
applied: false
mutation authority: none
production telemetry ingestion: false
live exporter enabled: false
```

`formatJson` must include top-level keys:

```json
{
  "schema": "...",
  "schema_version": 1,
  "status": "design-only",
  "generated_by": "...",
  "source_branch": "...",
  "recommendation": "...",
  "next_branch": "...",
  "applied": false,
  "mutation_authority": "none",
  "production_telemetry_ingestion": false,
  "live_exporter_enabled": false,
  "source_contracts": [],
  "capture_surfaces": [],
  "telemetry_fields": [],
  "readiness_gates": [],
  "negative_fixtures": [],
  "agent_rules": [],
  "non_goals": [],
  "verification_commands": []
}
```

- [ ] **Step 4: Add `main`**

Add:

```zig
pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| {
        std.debug.print("causal-production-telemetry-capture-design error: {s}\n{s}", .{ @errorName(err), usage() });
        std.process.exit(1);
    };

    const output = switch (format) {
        .text => try formatText(allocator),
        .json => try formatJson(allocator),
    };
    defer allocator.free(output);
    std.debug.print("{s}", .{output});
}
```

- [ ] **Step 5: Run focused test and confirm GREEN**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_capture_design.zig
```

Expected: PASS.

## Task 3: Wire Build Step And Governance

**Files:**

- Modify `packages/zigeffect/build.zig`
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] **Step 1: Add build module and test wiring**

Insert after the load-test observation harness block in `build.zig`:

```zig
const causal_production_telemetry_capture_design_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_capture_design.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_production_telemetry_capture_design_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-telemetry-capture-design",
    .root_module = causal_production_telemetry_capture_design_tool_module,
});
const run_causal_production_telemetry_capture_design_tool = b.addRunArtifact(causal_production_telemetry_capture_design_tool);
if (b.args) |args| run_causal_production_telemetry_capture_design_tool.addArgs(args);
const causal_production_telemetry_capture_design_step = b.step("causal-production-telemetry-capture-design", "Print causal production telemetry capture design report");
causal_production_telemetry_capture_design_step.dependOn(&run_causal_production_telemetry_capture_design_tool.step);

const causal_production_telemetry_capture_design_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-telemetry-capture-design-tests",
    .root_module = causal_production_telemetry_capture_design_tool_module,
});
const run_causal_production_telemetry_capture_design_tool_tests = b.addRunArtifact(causal_production_telemetry_capture_design_tool_tests);
test_step.dependOn(&run_causal_production_telemetry_capture_design_tool_tests.step);
```

Also add near the existing causal examples wiring:

```zig
examples_step.dependOn(&causal_production_telemetry_capture_design_tool.step);
examples_step.dependOn(&run_causal_production_telemetry_capture_design_tool_tests.step);
```

- [ ] **Step 2: Register schema governance**

Insert after the load-test observation harness entry:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-capture-design.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-capture-design"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry capture fixtures" },
    .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "design-only", "no-live-ingestion" },
    .governance_requirements = &.{ "telemetry capture design tests", "redaction gate docs", "negative telemetry fixtures", "next-branch handoff" },
},
```

Update schema governance tests so they call:

```zig
try expectSchema(entries, "zigeffect.causal.production-telemetry-capture-design.v1");
```

and assert both text and JSON reports contain the new schema.

- [ ] **Step 3: Run governance checks**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-capture-design
zig build causal-production-telemetry-capture-design -- --format json
zig build causal-schema-governance -- --format json
zig build test
```

Expected: PASS.

## Task 4: Update Hardening Backlog Handoff

**Files:**

- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Add backlog item**

Add a delivered item:

```zig
.{
    .id = "production-telemetry-capture-design",
    .branch = "codex/zigeffect-causal-production-telemetry-capture-design",
    .status = "delivered",
    .command = "zig build causal-production-telemetry-capture-design",
    .schema = "zigeffect.causal.production-telemetry-capture-design.v1",
    .scope = "Design-only production telemetry capture contract with capture surfaces, field contract, redaction sampling retention access encryption gates, negative fixtures, and fixture handoff.",
    .authority_boundary = "No live ingestion, no exporter, no OTLP endpoint, no production durable writes, no capacity sizing, no CI gate, no non-NenDB adapter, no alternate renderer, and no mutation authority.",
    .agent_guidance = "Use causal-production-telemetry-capture-design to classify future telemetry fixture work; do not infer live production telemetry or capacity evidence.",
},
```

If the local `BacklogItem` shape differs, use the existing field names exactly and preserve the same content.

- [ ] **Step 2: Update recommendation and dependency order**

Change:

```zig
const recommendation = "start-production-telemetry-capture-design";
const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-capture-design";
```

to:

```zig
const recommendation = "start-production-telemetry-capture-fixtures";
const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-capture-fixtures";
```

Add `"production-telemetry-capture-design"` after `"load-test-observation-harness"` in `dependency_order`.

Add verification commands:

```zig
"zig build causal-production-telemetry-capture-design",
"zig build causal-production-telemetry-capture-design -- --format json",
```

- [ ] **Step 3: Update backlog tests**

Add assertions:

```zig
try expectBacklogItem("production-telemetry-capture-design");
try expectBacklogItemStatus("production-telemetry-capture-design", "delivered");
```

Change recommendation assertions to:

```zig
"codex/zigeffect-causal-production-telemetry-capture-fixtures"
"start-production-telemetry-capture-fixtures"
```

- [ ] **Step 4: Run backlog checks**

Run:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
zig build test
```

Expected: PASS.

## Task 5: Add Documentation

**Files:**

- Create `packages/zigeffect/docs/production-telemetry-capture-design.md`
- Modify `packages/zigeffect/README.md`
- Modify `packages/zigeffect/docs/operations.md`
- Modify `packages/zigeffect/docs/schema-governance.md`
- Modify `packages/zigeffect/docs/load-test-observation-harness.md`
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify `packages/zigeffect/docs/roadmap.md`
- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Create the primary doc**

Create `packages/zigeffect/docs/production-telemetry-capture-design.md` with sections:

```markdown
# Production Telemetry Capture Design

`causal-production-telemetry-capture-design` is a schema-governed design report for future production telemetry capture. It does not ingest live telemetry, configure an exporter, send OTLP, write durable production storage, size production capacity, fail CI, add non-NenDB adapter work, add alternate renderer work, or grant mutation authority.

## Usage

...

## Capture Surfaces

...

## Field Contract

...

## Readiness Gates

...

## Negative Fixtures

...

## Agent Guidance

...

## Verification

...
```

- [ ] **Step 2: Add README entry**

Insert after the load-test observation harness section:

```markdown
Print the causal production telemetry capture design report:

```bash
cd packages/zigeffect
zig build causal-production-telemetry-capture-design
zig build causal-production-telemetry-capture-design -- --format json
```

The report uses schema `zigeffect.causal.production-telemetry-capture-design.v1`
and defines the future telemetry capture surfaces, field contract, redaction,
sampling, retention, access, encryption, and OTel bridge review gates. It is
design-only, `mutation_authority=none`, and does not enable live telemetry
ingestion, exporters, durable production writes, CI gates, or production
capacity claims. The full policy is in
[docs/production-telemetry-capture-design.md](docs/production-telemetry-capture-design.md).
```

- [ ] **Step 3: Update governance and roadmap docs**

Add a schema-governance section matching the tool entry and add roadmap/master-roadmap delivered bullets:

```markdown
- Delivered: `causal-production-telemetry-capture-design` publishes
  `zigeffect.causal.production-telemetry-capture-design.v1` with capture
  surfaces, future telemetry field contract, redaction/sampling/retention/
  access/encryption gates, OTel bridge review, local observation separation,
  negative fixtures, and the handoff to
  `codex/zigeffect-causal-production-telemetry-capture-fixtures`.
```

- [ ] **Step 4: Run doc-sensitive checks**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-capture-design
zig build causal-production-hardening-backlog -- --format json
zig build causal-schema-governance -- --format json
cd ../..
git diff --check
```

Expected: PASS.

## Task 6: Final Verification And Commit

**Files:**

- All files touched above.

- [ ] **Step 1: Run focused verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_capture_design.zig
zig build causal-production-telemetry-capture-design
zig build causal-production-telemetry-capture-design -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

Expected: PASS.

- [ ] **Step 2: Run root verification**

Run:

```sh
cd /Users/seanknowles/Desktop/Projects/yachdee
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

Expected: PASS.

- [ ] **Step 3: Commit implementation**

Run:

```sh
git status --short
git add docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-capture-design-implementation.md \
  packages/zigeffect/tools/causal_production_telemetry_capture_design.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/docs/production-telemetry-capture-design.md \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/docs/load-test-observation-harness.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/roadmap.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add production telemetry capture design"
```

Expected: commit succeeds. The next branch is `codex/zigeffect-causal-production-telemetry-capture-fixtures`.

## Self-Review

- Spec coverage: covered schema report, text/JSON output, schema governance, hardening backlog delivery state, docs, no-live-ingestion boundary, no-Cockroach/non-NenDB boundary, SolidJS/WebUI renderer boundary, and next fixture branch.
- Placeholder scan: no unresolved placeholder markers or undefined future behavior remain in the required task steps.
- Type consistency: all planned code uses `OutputFormat`, static report structs, `formatText`, `formatJson`, and the branch/schema constants defined in Task 1.
