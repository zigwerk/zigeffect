# zigeffect Causal App-Facing Production Integration Fixtures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic fixture-only CLI that documents and validates app-facing production integration evidence across app traces, agent queries, audit-chain comparison, NenDB durable history, production telemetry fixtures, and app remediation governance.

**Architecture:** Add one focused Zig tool with compile-time fixture data and text/JSON renderers. Register it in `packages/zigeffect/build.zig`, then update schema governance, production backlog, and docs so the new schema is discoverable by agents and future readiness-review work.

**Tech Stack:** Zig build system, Zig stdlib-only CLI implementation, existing zigeffect schema governance and production-hardening backlog tooling, Bun root verification commands.

---

## File Structure

- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_fixtures.zig`
  - Owns schema constants, source contracts, positive fixtures, negative fixtures, validation checks, text/JSON rendering, CLI parsing, and unit tests.
- Modify: `packages/zigeffect/build.zig`
  - Registers the executable, run step, and test artifact.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Adds `zigeffect.causal.app-facing-production-integration-fixtures.v1` to the schema registry and tests.
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Marks `app-facing-production-integration-fixtures` delivered and advances recommendation to readiness review.
- Create: `packages/zigeffect/docs/app-facing-production-integration-fixtures.md`
  - Documents the command, fixture boundaries, use cases, and non-goals.
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
  - Adds the delivered item and command examples.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Marks branch 47 delivered and names branch 48 as readiness review.
- Modify: `packages/zigeffect/README.md`
  - Adds a short user-facing command section.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Adds app-facing production fixture guidance for agents.

## Task 1: Red Test For New Fixture Tool Constants

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_fixtures.zig`

- [ ] **Step 1: Write the failing test**

Create the file with tests only:

```zig
const std = @import("std");

test "app-facing production integration fixture metadata is stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-fixtures.v1",
        app_facing_production_integration_fixtures_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), app_facing_production_integration_fixtures_schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-fixtures",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-production-integration-readiness-review",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-readiness-review",
        next_branch,
    );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_fixtures.zig
```

Expected: FAIL with undeclared identifier errors for the schema constants.

- [ ] **Step 3: Add minimal constants**

Add these constants above the test:

```zig
pub const app_facing_production_integration_fixtures_schema =
    "zigeffect.causal.app-facing-production-integration-fixtures.v1";
pub const app_facing_production_integration_fixtures_schema_version: u32 = 1;
pub const source_branch =
    "codex/zigeffect-causal-app-facing-production-integration-fixtures";
pub const recommendation =
    "start-app-facing-production-integration-readiness-review";
pub const next_branch =
    "codex/zigeffect-causal-app-facing-production-integration-readiness-review";
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_fixtures.zig
```

Expected: PASS.

## Task 2: Fixture Data And Coverage Tests

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_fixtures.zig`

- [ ] **Step 1: Write failing coverage tests**

Add tests for source contracts, positive fixtures, negative fixtures, and validation checks:

```zig
test "source contracts cover app integration evidence producers" {
    const contracts = sourceContracts();
    try expectSourceContract(contracts, "app-runtime", "zigeffect.causal.app-runtime.v1");
    try expectSourceContract(contracts, "agent-query", "zigeffect.causal.agent-query.v1");
    try expectSourceContract(contracts, "audit-chain-snapshot-compare", "zigeffect.causal.audit-chain-snapshot-compare.v1");
    try expectSourceContract(contracts, "nendb-durable-history", "zigeffect.causal.nendb-durable-history.v1");
    try expectSourceContract(contracts, "production-telemetry-capture-fixtures", "zigeffect.causal.production-telemetry-capture-fixtures.v1");
    try expectSourceContract(contracts, "app-remediation-chain", "zigeffect.causal.app-remediation-audit.v1");
}

test "positive fixtures cover request job query audit remediation telemetry and nendb handoff" {
    const fixtures = positiveFixtures();
    try expectFixture(fixtures, "worker-request-redacted-lineage");
    try expectFixture(fixtures, "background-job-nendb-history-handoff");
    try expectFixture(fixtures, "agent-query-app-trace-data");
    try expectFixture(fixtures, "audit-chain-before-after-app-review");
    try expectFixture(fixtures, "app-remediation-governance-bridge");
    try expectFixture(fixtures, "production-telemetry-fixture-boundary");
}

test "negative fixtures block unsafe app production integration claims" {
    const negatives = negativeFixtures();
    try expectNegativeFixture(negatives, "raw-request-body-capture");
    try expectNegativeFixture(negatives, "raw-header-capture");
    try expectNegativeFixture(negatives, "raw-prompt-capture");
    try expectNegativeFixture(negatives, "credential-token-capture");
    try expectNegativeFixture(negatives, "pii-or-tenant-identity-capture");
    try expectNegativeFixture(negatives, "live-production-telemetry-ingestion");
    try expectNegativeFixture(negatives, "live-exporter-enabled");
    try expectNegativeFixture(negatives, "production-durable-write");
    try expectNegativeFixture(negatives, "non-nendb-durable-storage");
    try expectNegativeFixture(negatives, "cockroach-adapter-work");
    try expectNegativeFixture(negatives, "app-mutation-authority");
    try expectNegativeFixture(negatives, "audit-chain-compare-as-mutation-proof");
    try expectNegativeFixture(negatives, "agent-query-raw-payload-scrape");
    try expectNegativeFixture(negatives, "ci-gate-enforcement");
    try expectNegativeFixture(negatives, "react-or-alternate-renderer");
}

test "validation checks cover app integration safety gates" {
    const checks = validationChecks();
    try expectValidationCheck(checks, "source-contract-coverage");
    try expectValidationCheck(checks, "positive-fixture-surface-coverage");
    try expectValidationCheck(checks, "redaction-ref-only-lineage");
    try expectValidationCheck(checks, "blocked-claim-coverage");
    try expectValidationCheck(checks, "forbidden-value-absence");
    try expectValidationCheck(checks, "nendb-only-durable-direction");
    try expectValidationCheck(checks, "no-live-authority");
    try expectValidationCheck(checks, "next-branch-handoff");
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_fixtures.zig
```

Expected: FAIL with undeclared identifiers for fixture structs, arrays, and helper functions.

- [ ] **Step 3: Add fixture structs, arrays, and lookup helpers**

Implement:

```zig
const generated_by = "causal-app-facing-production-integration-fixtures";
const status = "fixtures-only";
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const durable_write_enabled = false;
const app_mutation_enabled = false;
const ci_gate_enabled = false;
const applied = false;

const OutputFormat = enum { text, json };
const Mode = enum { catalog, emit, validate };
const FixtureKind = enum { positive, negative };

const Options = struct {
    mode: Mode,
    format: OutputFormat,
    fixture_id: ?[]const u8 = null,
};

const SourceContract = struct {
    id: []const u8,
    schema: []const u8,
    producer: []const u8,
    evidence_role: []const u8,
    authority_boundary: []const u8,
};

const FixtureRecord = struct {
    fixture_id: []const u8,
    fixture_kind: FixtureKind,
    integration_surface_id: []const u8,
    source_schema: []const u8,
    app_trace_kind: []const u8,
    signal_kind: []const u8,
    lineage_policy: []const u8,
    redaction_state: []const u8,
    sampling_policy: []const u8,
    retention_policy: []const u8,
    access_policy_ref: []const u8,
    durable_history_ref: []const u8,
    audit_chain_compare_ref: []const u8,
    agent_query_ref: []const u8,
    remediation_chain_ref: []const u8,
    telemetry_transport_state: []const u8,
    durable_write_state: []const u8,
    app_mutation_state: []const u8,
    review_gate: []const u8,
    blocked_claims: []const []const u8,
    sample_attributes: []const []const u8,
    expected_agent_use: []const u8,
    forbidden_inference: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    attempted_claim: []const u8,
    decision: []const u8,
    reason: []const u8,
    violated_field_or_gate: []const u8,
    safe_alternative: []const u8,
};

const ValidationCheck = struct {
    id: []const u8,
    status: []const u8,
    evidence: []const []const u8,
    blocks_claim: []const u8,
};
```

Populate arrays with the ids and schemas from the design spec. Add helper functions:

```zig
fn sourceContracts() []const SourceContract { return source_contracts; }
fn positiveFixtures() []const FixtureRecord { return positive_fixtures; }
fn negativeFixtures() []const NegativeFixture { return negative_fixtures; }
fn validationChecks() []const ValidationCheck { return validation_checks; }

fn findFixture(id: []const u8) ?FixtureRecord {
    for (positive_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.fixture_id, id)) return fixture;
    }
    return null;
}

fn expectSourceContract(contracts: []const SourceContract, id: []const u8, schema: []const u8) !void {
    for (contracts) |contract| {
        if (std.mem.eql(u8, contract.id, id)) {
            try std.testing.expectEqualStrings(schema, contract.schema);
            return;
        }
    }
    try std.testing.expect(false);
}

fn expectFixture(fixtures: []const FixtureRecord, id: []const u8) !void {
    for (fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.fixture_id, id)) return;
    }
    try std.testing.expect(false);
}

fn expectNegativeFixture(fixtures: []const NegativeFixture, id: []const u8) !void {
    for (fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return;
    }
    try std.testing.expect(false);
}

fn expectValidationCheck(checks: []const ValidationCheck, id: []const u8) !void {
    for (checks) |check| {
        if (std.mem.eql(u8, check.id, id)) return;
    }
    try std.testing.expect(false);
}
```

The arrays must contain exactly the ids named in the tests, with no source
contract claiming live authority.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_fixtures.zig
```

Expected: PASS.

## Task 3: Text And JSON Rendering

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_fixtures.zig`

- [ ] **Step 1: Write failing rendering tests**

Add tests:

```zig
test "catalog text names schema fixtures and blocked live authority" {
    const report = try formatCatalogText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.app-facing-production-integration-fixtures.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "positive fixtures:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "worker-request-redacted-lineage") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation authority: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "live exporter enabled: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app mutation enabled: false") != null);
}

test "catalog json names schema fixtures and blocked live authority" {
    const report = try formatCatalogJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-fixtures.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"positive_fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"fixture_id\": \"worker-request-redacted-lineage\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"app_mutation_enabled\": false") != null);
}

test "emit fixture json returns one selected positive fixture" {
    const fixture = findFixture("worker-request-redacted-lineage").?;
    const report = try formatFixtureJson(std.testing.allocator, fixture);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"fixture_id\": \"worker-request-redacted-lineage\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"fixture_id\": \"background-job-nendb-history-handoff\"") == null);
}

test "validation json emits validation checks without fixture catalog" {
    const report = try formatValidationJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"validation_checks\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"source-contract-coverage\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"positive_fixtures\"") == null);
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_fixtures.zig
```

Expected: FAIL with undeclared renderer functions.

- [ ] **Step 3: Implement renderers**

Implement renderer functions following the allocation and formatting style in
`tools/causal_production_telemetry_capture_fixtures.zig`. The required
function signatures are:

```zig
fn formatCatalogText(allocator: std.mem.Allocator) ![]const u8;
fn formatCatalogJson(allocator: std.mem.Allocator) ![]const u8;
fn formatFixtureText(allocator: std.mem.Allocator, fixture: FixtureRecord) ![]const u8;
fn formatFixtureJson(allocator: std.mem.Allocator, fixture: FixtureRecord) ![]const u8;
fn formatValidationText(allocator: std.mem.Allocator) ![]const u8;
fn formatValidationJson(allocator: std.mem.Allocator) ![]const u8;
fn appendHeaderText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void;
fn appendHeaderJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void;
fn appendFixtureText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixture: FixtureRecord, label: []const u8) !void;
fn appendFixtureJsonObject(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixture: FixtureRecord) !void;
fn appendNegativeFixtureJsonObject(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixture: NegativeFixture) !void;
fn appendValidationCheckJsonObject(allocator: std.mem.Allocator, output: *std.ArrayList(u8), check: ValidationCheck) !void;
fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void;
fn appendJsonStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void;
```

Implementation requirements:

- each formatter creates `var output = std.ArrayList(u8).empty`;
- each formatter uses `errdefer output.deinit(allocator)`;
- each formatter returns `try output.toOwnedSlice(allocator)`;
- text catalog output prints header metadata, source contracts, positive
  fixtures, negative fixtures, validation checks, agent rules, non-goals, and
  verification commands;
- JSON catalog output prints those sections as properties:
  `source_contracts`, `positive_fixtures`, `negative_fixtures`,
  `validation_checks`, `agent_rules`, `non_goals`, and
  `verification_commands`;
- fixture output prints the header and one property/section named `fixture`;
- validation output prints the header and `validation_checks` only;
- JSON string escaping handles `"`, `\`, newline, carriage return, and tab.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_fixtures.zig
```

Expected: PASS.

## Task 4: CLI Parsing And Main

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_fixtures.zig`

- [ ] **Step 1: Write failing CLI parsing tests**

Add tests:

```zig
test "parse options defaults to catalog text" {
    const args = [_][]const u8{"causal-app-facing-production-integration-fixtures"};
    const options = try parseOptions(&args);
    try std.testing.expectEqual(Mode.catalog, options.mode);
    try std.testing.expectEqual(OutputFormat.text, options.format);
    try std.testing.expect(options.fixture_id == null);
}

test "parse options accepts json catalog" {
    const args = [_][]const u8{ "tool", "--format", "json" };
    const options = try parseOptions(&args);
    try std.testing.expectEqual(Mode.catalog, options.mode);
    try std.testing.expectEqual(OutputFormat.json, options.format);
}

test "parse options accepts emit fixture json" {
    const args = [_][]const u8{ "tool", "emit", "worker-request-redacted-lineage", "--format", "json" };
    const options = try parseOptions(&args);
    try std.testing.expectEqual(Mode.emit, options.mode);
    try std.testing.expectEqual(OutputFormat.json, options.format);
    try std.testing.expectEqualStrings("worker-request-redacted-lineage", options.fixture_id.?);
}

test "parse options accepts validate json" {
    const args = [_][]const u8{ "tool", "validate", "--format", "json" };
    const options = try parseOptions(&args);
    try std.testing.expectEqual(Mode.validate, options.mode);
    try std.testing.expectEqual(OutputFormat.json, options.format);
}

test "parse options rejects unknown fixture and format" {
    const bad_fixture = [_][]const u8{ "tool", "emit", "missing" };
    try std.testing.expectError(error.UnknownFixture, parseOptions(&bad_fixture));

    const bad_format = [_][]const u8{ "tool", "--format", "yaml" };
    try std.testing.expectError(error.UnknownFormat, parseOptions(&bad_format));
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_fixtures.zig
```

Expected: FAIL with undeclared `parseOptions`.

- [ ] **Step 3: Implement CLI parser and main**

Implement these parser helpers:

```zig
fn usage() []const u8 {
    return
    \\usage:
    \\  zig build causal-app-facing-production-integration-fixtures
    \\  zig build causal-app-facing-production-integration-fixtures -- --format text
    \\  zig build causal-app-facing-production-integration-fixtures -- --format json
    \\  zig build causal-app-facing-production-integration-fixtures -- emit <fixture-id> [--format text|json]
    \\  zig build causal-app-facing-production-integration-fixtures -- validate [--format text|json]
    \\
    \\fixtures:
    \\  worker-request-redacted-lineage
    \\  background-job-nendb-history-handoff
    \\  agent-query-app-trace-data
    \\  audit-chain-before-after-app-review
    \\  app-remediation-governance-bridge
    \\  production-telemetry-fixture-boundary
    \\
    ;
}

fn kindName(kind: FixtureKind) []const u8 {
    return switch (kind) {
        .positive => "positive",
        .negative => "negative",
    };
}

fn parseFormat(value: []const u8) !OutputFormat {
    if (std.mem.eql(u8, value, "text")) return .text;
    if (std.mem.eql(u8, value, "json")) return .json;
    return error.UnknownFormat;
}

fn parseOptions(args: []const []const u8) !Options {
    var options = Options{ .mode = .catalog, .format = .text };
    var index: usize = if (args.len > 0) 1 else 0;

    if (index < args.len) {
        if (std.mem.eql(u8, args[index], "emit")) {
            options.mode = .emit;
            index += 1;
            if (index >= args.len) return error.MissingFixture;
            if (findFixture(args[index]) == null) return error.UnknownFixture;
            options.fixture_id = args[index];
            index += 1;
        } else if (std.mem.eql(u8, args[index], "validate")) {
            options.mode = .validate;
            index += 1;
        }
    }

    while (index < args.len) {
        if (std.mem.eql(u8, args[index], "--format")) {
            index += 1;
            if (index >= args.len) return error.MissingFormat;
            options.format = try parseFormat(args[index]);
            index += 1;
            continue;
        }
        return error.UnknownFlag;
    }

    return options;
}
```

Add the executable entry point:

```zig

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(args) catch |err| {
        std.debug.print("causal-app-facing-production-integration-fixtures error: {s}\n{s}", .{ @errorName(err), usage() });
        std.process.exit(1);
    };

    const output = switch (options.mode) {
        .catalog => switch (options.format) {
            .text => try formatCatalogText(allocator),
            .json => try formatCatalogJson(allocator),
        },
        .emit => blk: {
            const fixture = findFixture(options.fixture_id.?) orelse unreachable;
            break :blk switch (options.format) {
                .text => try formatFixtureText(allocator, fixture),
                .json => try formatFixtureJson(allocator, fixture),
            };
        },
        .validate => switch (options.format) {
            .text => try formatValidationText(allocator),
            .json => try formatValidationJson(allocator),
        },
    };
    defer allocator.free(output);
    try std.io.getStdOut().writeAll(output);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_fixtures.zig
```

Expected: PASS.

## Task 5: Build Target Integration

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the build module, executable, run step, and tests**

Insert after the production telemetry capture fixtures block:

```zig
const causal_app_facing_production_integration_fixtures_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_facing_production_integration_fixtures.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_app_facing_production_integration_fixtures_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-facing-production-integration-fixtures",
    .root_module = causal_app_facing_production_integration_fixtures_tool_module,
});
const run_causal_app_facing_production_integration_fixtures_tool = b.addRunArtifact(causal_app_facing_production_integration_fixtures_tool);
if (b.args) |args| run_causal_app_facing_production_integration_fixtures_tool.addArgs(args);
const causal_app_facing_production_integration_fixtures_step = b.step("causal-app-facing-production-integration-fixtures", "Print causal app-facing production integration fixture catalog");
causal_app_facing_production_integration_fixtures_step.dependOn(&run_causal_app_facing_production_integration_fixtures_tool.step);

const causal_app_facing_production_integration_fixtures_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-facing-production-integration-fixtures-tests",
    .root_module = causal_app_facing_production_integration_fixtures_tool_module,
});
const run_causal_app_facing_production_integration_fixtures_tool_tests = b.addRunArtifact(causal_app_facing_production_integration_fixtures_tool_tests);
test_step.dependOn(&run_causal_app_facing_production_integration_fixtures_tool_tests.step);
```

- [ ] **Step 2: Run the build command**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-fixtures -- --format json
```

Expected: PASS and JSON includes the new schema.

## Task 6: Schema Governance

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] **Step 1: Add failing schema governance expectations**

Add `try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-fixtures.v1");` to the schema coverage test.

Add text and JSON assertions:

```zig
try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-fixtures.v1") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-fixtures.v1\"") != null);
```

- [ ] **Step 2: Run the governance test to verify failure**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
```

Expected: FAIL because the schema entry is missing.

- [ ] **Step 3: Add schema entry**

Add an entry near `app-runtime` / app and production integration schemas:

```zig
.{
    .schema = "zigeffect.causal.app-facing-production-integration-fixtures.v1",
    .version = 1,
    .category = "app-runtime",
    .status = "current",
    .emitted_by = &.{"causal-app-facing-production-integration-fixtures"},
    .consumed_by = &.{ "agents", "reviewers", "future app-facing production integration readiness review", "future SolidJS workbench production app views" },
    .compatibility = &.{ "strict-v1", "fixture-only", "record-only", "nendb-only", "no-cockroach", "no-live-telemetry", "no-production-mutation" },
    .governance_requirements = &.{ "fixture tool tests", "source contract coverage", "redaction negative fixtures", "backlog update", "docs update" },
},
```

- [ ] **Step 4: Run governance test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
```

Expected: PASS.

## Task 7: Backlog And Roadmap Updates

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add failing backlog tests**

Update tests to expect:

```zig
try expectBacklogItem("app-facing-production-integration-fixtures");
try expectBacklogItemStatus("app-facing-production-integration-fixtures", "delivered");
try std.testing.expect(std.mem.indexOf(u8, report, "recommendation: start-app-facing-production-integration-readiness-review") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "recommended next branch: codex/zigeffect-causal-app-facing-production-integration-readiness-review") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-fixtures") != null);
```

Update JSON expectations similarly:

```zig
try std.testing.expect(std.mem.indexOf(u8, report, "\"recommended_next_branch\": \"codex/zigeffect-causal-app-facing-production-integration-readiness-review\"") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-fixtures\"") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-fixtures\"") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-fixtures -- validate --format json") != null);
```

- [ ] **Step 2: Run backlog test to verify failure**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: FAIL because the item and recommendation are not updated yet.

- [ ] **Step 3: Update backlog source**

Change:

```zig
pub const recommendation = "start-app-facing-production-integration-readiness-review";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-production-integration-readiness-review";
```

Add a delivered `BacklogItem` with:

- id `app-facing-production-integration-fixtures`;
- priority `P1`;
- status `delivered`;
- depends on app semantic trace API, agent query interface, audit-chain snapshot compare, NenDB durable-history hardening, production telemetry capture fixtures, and app remediation governance;
- evidence sources including the new spec, plan, tool, and docs;
- branch `codex/zigeffect-causal-app-facing-production-integration-fixtures`;
- guidance that agents should cite fixture ids, keep refs redacted, and route future authority through readiness review.

Add verification commands for the new CLI.

- [ ] **Step 4: Update docs and roadmap**

In `production-hardening-backlog.md`, change the recommendation section and add a delivered section for app-facing production integration fixtures with command examples.

In the master roadmap, mark branch 47 delivered and add branch 48:

```markdown
48. `codex/zigeffect-causal-app-facing-production-integration-readiness-review`
   - Next: consume the fixture catalog and decide whether app-facing production
     integration is ready for implementation proposal work without granting
     live telemetry, durable writes, app mutation, CI gates, Cockroach scope, or
     alternate renderer scope.
```

- [ ] **Step 5: Run backlog test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: PASS.

## Task 8: User Docs

**Files:**
- Create: `packages/zigeffect/docs/app-facing-production-integration-fixtures.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`

- [ ] **Step 1: Write docs**

Create the dedicated doc with:

```markdown
# App-Facing Production Integration Fixtures

`causal-app-facing-production-integration-fixtures` emits
`zigeffect.causal.app-facing-production-integration-fixtures.v1` as a
deterministic fixture-only catalog for app production evidence.

It provides `catalog`, `emit <fixture-id>`, and `validate` modes. It keeps
`mutation_authority=none`, `applied=false`, live telemetry disabled, durable
writes disabled, app mutation disabled, and CI gates disabled. Durable handoff
is NenDB-only, and Cockroach adapter work remains out of scope.
```

Include command examples, fixture ids, source contracts, negative claims, and
the explicit no-live/no-mutation/NenDB-only boundaries.

- [ ] **Step 2: Update README**

Add a short command section near the app runtime/remediation docs:

```markdown
Print app-facing production integration fixtures:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-fixtures
zig build causal-app-facing-production-integration-fixtures -- validate --format json
```
```

- [ ] **Step 3: Update agent-observable runtime docs**

Add an agent guidance paragraph explaining how agents should use the fixtures
as safe references before production readiness review.

## Task 9: Focused Verification And Implementation Commit

**Files:**
- All touched files.

- [ ] **Step 1: Run focused tool tests and build commands**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_fixtures.zig
zig build causal-app-facing-production-integration-fixtures
zig build causal-app-facing-production-integration-fixtures -- --format json
zig build causal-app-facing-production-integration-fixtures -- emit worker-request-redacted-lineage --format json
zig build causal-app-facing-production-integration-fixtures -- validate --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: all PASS.

- [ ] **Step 2: Run broader verification**

Run:

```bash
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all PASS.

- [ ] **Step 3: Review changed files**

Run:

```bash
git status --short
git diff --stat
```

Expected: only the planned files changed.

- [ ] **Step 4: Commit implementation**

Run:

```bash
git add packages/zigeffect/tools/causal_app_facing_production_integration_fixtures.zig packages/zigeffect/build.zig packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/tools/causal_production_hardening_backlog.zig packages/zigeffect/docs/app-facing-production-integration-fixtures.md packages/zigeffect/docs/production-hardening-backlog.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md packages/zigeffect/README.md packages/zigeffect/docs/agent-observable-runtime.md
git commit -m "feat(zigeffect): add app-facing production integration fixtures"
```

Expected: commit succeeds.

## Plan Self-Review

- Spec coverage: the plan covers CLI, schema metadata, source contracts,
  positive fixtures, negative fixtures, validation, build integration, schema
  governance, backlog, roadmap, docs, and verification.
- Placeholder scan: the plan contains no deferred behavior or placeholder code
  blocks.
- Type consistency: names for schema, command, branch, recommendation, next
  branch, fixture ids, and validation ids match the design spec.
