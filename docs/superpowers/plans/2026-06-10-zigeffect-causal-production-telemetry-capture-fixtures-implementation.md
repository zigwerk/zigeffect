# zigeffect Causal Production Telemetry Capture Fixtures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a schema-governed, record-only production telemetry capture fixture catalog with selected-fixture output and deterministic validation.

**Architecture:** Create one Zig report tool backed by static reviewed tables. The default command emits a catalog, `emit <fixture-id>` emits a named fixture, and `validate` emits coverage checks; all modes preserve `applied=false`, `mutation_authority="none"`, no live ingestion, no durable writes, and no CI gate authority.

**Tech Stack:** Zig 0.16 build steps and tests, existing zigeffect causal report patterns, Markdown docs, Bun verification commands.

---

## Files And Responsibilities

- Create `packages/zigeffect/tools/causal_production_telemetry_capture_fixtures.zig`
  - Owns schema `zigeffect.causal.production-telemetry-capture-fixtures.v1`.
  - Emits catalog text/JSON.
  - Emits selected fixture text/JSON with `emit <fixture-id>`.
  - Emits validation text/JSON with `validate`.
  - Defines source contracts, positive fixtures, negative fixtures, validation
    checks, agent rules, non-goals, and verification commands.
  - Tests parser behavior, schema constants, fixture coverage, negative claim
    coverage, selected fixture output, validation output, and authority fields.

- Modify `packages/zigeffect/build.zig`
  - Adds `causal-production-telemetry-capture-fixtures` executable step.
  - Adds tool tests to `zig build test`.
  - Adds tool and tests to `zig build examples`.

- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Registers `zigeffect.causal.production-telemetry-capture-fixtures.v1`.
  - Updates schema-count expectation from `51` to `52`.
  - Adds tests for fixture schema text/JSON output.

- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Adds `production-telemetry-capture-fixtures` as delivered.
  - Updates recommendation to `start-production-telemetry-readiness-review`.
  - Updates recommended next branch to
    `codex/zigeffect-causal-production-telemetry-readiness-review`.
  - Adds fixture commands to verification commands.

- Create `packages/zigeffect/docs/production-telemetry-capture-fixtures.md`
  - Documents command usage, schema, positive fixtures, negative fixtures,
    validation checks, agent guidance, non-goals, and verification.

- Modify docs:
  - `packages/zigeffect/README.md`
  - `packages/zigeffect/docs/operations.md`
  - `packages/zigeffect/docs/schema-governance.md`
  - `packages/zigeffect/docs/production-telemetry-capture-design.md`
  - `packages/zigeffect/docs/production-hardening-backlog.md`
  - `packages/zigeffect/docs/roadmap.md`
  - `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Command Contract

Supported invocations:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-capture-fixtures
zig build causal-production-telemetry-capture-fixtures -- --format json
zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json
zig build causal-production-telemetry-capture-fixtures -- validate --format json
```

Parser rules:

- No args after the executable means catalog text.
- `--format text|json` selects catalog output.
- `emit <fixture-id>` selects a fixture and defaults to text.
- `emit <fixture-id> --format json` emits selected fixture JSON.
- `validate` defaults to text.
- `validate --format json` emits validation JSON.
- `emit` without a fixture returns `error.MissingFixture`.
- Unknown fixture id returns `error.UnknownFixture`.
- `--format` without value returns `error.MissingFormat`.
- Unknown format returns `error.UnknownFormat`.
- Unknown flag or subcommand returns `error.UnknownFlag`.

## Task 1: Add Failing Tool Tests

**Files:**

- Create: `packages/zigeffect/tools/causal_production_telemetry_capture_fixtures.zig`

- [ ] **Step 1: Create the initial tool skeleton**

Use this skeleton:

```zig
const std = @import("std");

pub const production_telemetry_capture_fixtures_schema = "zigeffect.causal.production-telemetry-capture-fixtures.v1";
pub const production_telemetry_capture_fixtures_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-capture-fixtures";
pub const recommendation = "start-production-telemetry-readiness-review";
pub const next_branch = "codex/zigeffect-causal-production-telemetry-readiness-review";

const generated_by = "causal-production-telemetry-capture-fixtures";
const status = "fixtures-only";
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const durable_write_enabled = false;
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
    capture_surface_id: []const u8,
    source_schema: []const u8,
    signal_kind: []const u8,
    event_kind_policy: []const u8,
    redaction_state: []const u8,
    sampling_policy: []const u8,
    retention_policy: []const u8,
    access_policy_ref: []const u8,
    encryption_policy_ref: []const u8,
    telemetry_transport_state: []const u8,
    durable_write_state: []const u8,
    local_observation_refs: []const []const u8,
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

const AgentRule = struct {
    id: []const u8,
    guidance: []const u8,
};

fn parseOptions(args: []const []const u8) !Options {
    _ = args;
    return error.ExpectedRedFailure;
}

fn findFixture(id: []const u8) ?FixtureRecord {
    _ = id;
    return null;
}

fn positiveFixtures() []const FixtureRecord {
    return &.{};
}

fn negativeFixtures() []const NegativeFixture {
    return &.{};
}

fn validationChecks() []const ValidationCheck {
    return &.{};
}

fn formatCatalogText(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return error.ExpectedRedFailure;
}

fn formatCatalogJson(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return error.ExpectedRedFailure;
}

fn formatFixtureJson(allocator: std.mem.Allocator, fixture: FixtureRecord) ![]const u8 {
    _ = allocator;
    _ = fixture;
    return error.ExpectedRedFailure;
}

fn formatValidationJson(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return error.ExpectedRedFailure;
}
```

- [ ] **Step 2: Add failing tests**

Append these tests to the skeleton:

```zig
test "production telemetry capture fixtures expose schema and blocked authority constants" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-capture-fixtures.v1", production_telemetry_capture_fixtures_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_capture_fixtures_schema_version);
    try std.testing.expectEqualStrings("start-production-telemetry-readiness-review", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-readiness-review", next_branch);
    try std.testing.expectEqualStrings("none", mutation_authority);
    try std.testing.expect(!production_telemetry_ingestion);
    try std.testing.expect(!live_exporter_enabled);
    try std.testing.expect(!durable_write_enabled);
    try std.testing.expect(!ci_gate_enabled);
    try std.testing.expect(!applied);
}

test "production telemetry capture fixtures parse catalog emit and validate options" {
    try std.testing.expectEqual(Mode.catalog, (try parseOptions(&.{"zigeffect-causal-production-telemetry-capture-fixtures"})).mode);
    try std.testing.expectEqual(OutputFormat.json, (try parseOptions(&.{ "zigeffect-causal-production-telemetry-capture-fixtures", "--format", "json" })).format);

    const emit = try parseOptions(&.{ "zigeffect-causal-production-telemetry-capture-fixtures", "emit", "runtime-trace-span-event", "--format", "json" });
    try std.testing.expectEqual(Mode.emit, emit.mode);
    try std.testing.expectEqual(OutputFormat.json, emit.format);
    try std.testing.expectEqualStrings("runtime-trace-span-event", emit.fixture_id.?);

    const validate = try parseOptions(&.{ "zigeffect-causal-production-telemetry-capture-fixtures", "validate", "--format", "json" });
    try std.testing.expectEqual(Mode.validate, validate.mode);
    try std.testing.expectEqual(OutputFormat.json, validate.format);

    try std.testing.expectError(error.MissingFixture, parseOptions(&.{ "zigeffect-causal-production-telemetry-capture-fixtures", "emit" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-production-telemetry-capture-fixtures", "--format" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-production-telemetry-capture-fixtures", "--format", "yaml" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-production-telemetry-capture-fixtures", "--json" }));
}

test "production telemetry capture fixtures cover positive surfaces and negative claims" {
    try std.testing.expectEqual(@as(usize, 6), positiveFixtures().len);
    try std.testing.expect(findFixture("runtime-trace-span-event") != null);
    try std.testing.expect(findFixture("app-semantic-redacted-ref") != null);
    try std.testing.expect(findFixture("backend-export-otel-record") != null);
    try std.testing.expect(findFixture("redaction-access-evidence") != null);
    try std.testing.expect(findFixture("local-observation-correlation-ref") != null);
    try std.testing.expect(findFixture("sampling-boundary-sampled-in") != null);

    try std.testing.expectEqual(@as(usize, 14), negativeFixtures().len);
    try expectNegativeFixture("live-exporter-enabled");
    try expectNegativeFixture("raw-request-body-capture");
    try expectNegativeFixture("non-nendb-durable-storage");
    try expectNegativeFixture("cockroach-adapter-work");
    try expectNegativeFixture("react-or-alternate-renderer");
    try expectNegativeFixture("mutation-authority-granted");
}

test "production telemetry capture fixtures catalog output is bounded and non-live" {
    const report = try formatCatalogText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.production-telemetry-capture-fixtures.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production telemetry ingestion: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "live exporter enabled: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "durable write enabled: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "ci gate enabled: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "positive fixture: runtime-trace-span-event") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "negative fixture: raw-request-body-capture") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "validation check: required-field-coverage") != null);
}

test "production telemetry capture fixtures json output is machine readable" {
    const catalog = try formatCatalogJson(std.testing.allocator);
    defer std.testing.allocator.free(catalog);

    try std.testing.expect(std.mem.indexOf(u8, catalog, "\"schema\": \"zigeffect.causal.production-telemetry-capture-fixtures.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "\"production_telemetry_ingestion\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "\"live_exporter_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "\"durable_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "\"ci_gate_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "\"fixture_id\": \"runtime-trace-span-event\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "\"id\": \"local-observation-as-production-capacity\"") != null);

    const fixture = findFixture("runtime-trace-span-event").?;
    const selected = try formatFixtureJson(std.testing.allocator, fixture);
    defer std.testing.allocator.free(selected);
    try std.testing.expect(std.mem.indexOf(u8, selected, "\"fixture_id\": \"runtime-trace-span-event\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, selected, "\"telemetry_transport_state\": \"disabled-fixture\"") != null);

    const validation = try formatValidationJson(std.testing.allocator);
    defer std.testing.allocator.free(validation);
    try std.testing.expect(std.mem.indexOf(u8, validation, "\"id\": \"required-field-coverage\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, validation, "\"status\": \"passed\"") != null);
}
```

- [ ] **Step 3: Add helper test functions**

Add these helpers below the tests or before them:

```zig
fn expectNegativeFixture(id: []const u8) !void {
    for (negativeFixtures()) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return;
    }
    return error.MissingNegativeFixture;
}
```

- [ ] **Step 4: Run the focused test and confirm RED**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_capture_fixtures.zig
```

Expected: FAIL with `ExpectedRedFailure` from `parseOptions`,
`formatCatalogText`, `formatCatalogJson`, `formatFixtureJson`, or
`formatValidationJson`.

## Task 2: Implement Fixture Tables, Parser, Validation, And Renderers

**Files:**

- Modify: `packages/zigeffect/tools/causal_production_telemetry_capture_fixtures.zig`

- [ ] **Step 1: Add static source contracts**

Add a `source_contracts` constant with these ids:

```zig
const source_contracts: []const SourceContract = &.{
    .{ .id = "production-telemetry-capture-design", .schema = "zigeffect.causal.production-telemetry-capture-design.v1", .producer = "causal-production-telemetry-capture-design", .evidence_role = "approved capture surfaces required fields readiness gates and negative fixture ids", .authority_boundary = "design and fixture handoff only; no live telemetry" },
    .{ .id = "load-test-observation-harness", .schema = "zigeffect.causal.load-test-observation-harness.v1", .producer = "causal-load-test-observation-harness", .evidence_role = "local advisory observation refs for fixture correlation", .authority_boundary = "local observations only; not production telemetry or capacity evidence" },
    .{ .id = "causal-otel-record", .schema = "zigeffect.causal.otel_record.v1", .producer = "CausalOtelBackendState", .evidence_role = "exporter-neutral span and span-event record shape", .authority_boundary = "record bridge only; no OTLP serialization network send SDK setup or collector endpoint" },
    .{ .id = "backend-conformance", .schema = "zigeffect.causal.backend-conformance.v1", .producer = "causal-backend-conformance", .evidence_role = "redacted bounded stored event and sampled-out exclusion evidence", .authority_boundary = "backend behavior evidence only; not live telemetry ingestion" },
    .{ .id = "production-artifact-aggregation", .schema = "zigeffect.causal.production-artifact-aggregation.v1", .producer = "causal-production-artifact-aggregation", .evidence_role = "source provenance redaction state trust boundary and aggregation review", .authority_boundary = "reviewed contract only; no aggregation of live production artifacts" },
    .{ .id = "artifact-access-control", .schema = "zigeffect.causal.artifact-access-control.v1", .producer = "causal-artifact-access-control", .evidence_role = "redacted-only access policy refs", .authority_boundary = "access decision record only; no production sharing action" },
    .{ .id = "encryption-at-rest-policy", .schema = "zigeffect.causal.encryption-at-rest-policy.v1", .producer = "causal-encryption-at-rest-policy", .evidence_role = "redaction ordering and encrypted artifact fixture policy", .authority_boundary = "policy evidence only; no retained production storage is written" },
};
```

- [ ] **Step 2: Add static positive fixtures**

Add a `positive_fixtures` constant with these fixture ids:

```zig
const positive_fixtures: []const FixtureRecord = &.{
    .{
        .fixture_id = "runtime-trace-span-event",
        .fixture_kind = .positive,
        .capture_surface_id = "runtime-trace",
        .source_schema = "zigeffect.causal.otel_record.v1",
        .signal_kind = "span-event",
        .event_kind_policy = "allowlisted-bounded",
        .redaction_state = "redacted-before-export",
        .sampling_policy = "sampled-in-only",
        .retention_policy = "nendb-compatible-retention-ref",
        .access_policy_ref = "artifact-access-control:redacted-viewer",
        .encryption_policy_ref = "encryption-at-rest-policy:retained-fixture",
        .telemetry_transport_state = "disabled-fixture",
        .durable_write_state = "disabled-fixture",
        .local_observation_refs = &.{},
        .review_gate = "otel-bridge-reviewed",
        .blocked_claims = &.{ "live-exporter-enabled", "otlp-collector-endpoint-configured", "mutation-authority-granted" },
        .sample_attributes = &.{ "run_id=fixture-run", "event_id=fixture-event", "span_event_kind=causal.event" },
        .expected_agent_use = "Explain runtime trace event shape without inferring live export.",
        .forbidden_inference = "This fixture does not send OTLP or configure a collector.",
    },
    .{
        .fixture_id = "app-semantic-redacted-ref",
        .fixture_kind = .positive,
        .capture_surface_id = "app-semantic",
        .source_schema = "zigeffect.causal.app-runtime.v1",
        .signal_kind = "app-semantic",
        .event_kind_policy = "schema-ref-only",
        .redaction_state = "refs-only-redacted",
        .sampling_policy = "bounded-domain-action",
        .retention_policy = "nendb-compatible-retention-ref",
        .access_policy_ref = "artifact-access-control:review-required",
        .encryption_policy_ref = "encryption-at-rest-policy:redaction-before-retention",
        .telemetry_transport_state = "disabled-fixture",
        .durable_write_state = "disabled-fixture",
        .local_observation_refs = &.{},
        .review_gate = "redaction-reviewed",
        .blocked_claims = &.{ "raw-request-body-capture", "raw-header-capture", "raw-prompt-capture", "credential-token-capture" },
        .sample_attributes = &.{ "schema_ref=fixture.schema", "data_ref=redacted:data", "domain_ref=fixture.action" },
        .expected_agent_use = "Model app behavior with refs and schema names.",
        .forbidden_inference = "This fixture does not capture request bodies headers prompts credentials or PII.",
    },
    .{
        .fixture_id = "backend-export-otel-record",
        .fixture_kind = .positive,
        .capture_surface_id = "backend-export-otel",
        .source_schema = "zigeffect.causal.otel_record.v1",
        .signal_kind = "span",
        .event_kind_policy = "allowlisted-bounded",
        .redaction_state = "redacted-before-bridge",
        .sampling_policy = "sampled-in-only",
        .retention_policy = "nendb-compatible-retention-ref",
        .access_policy_ref = "artifact-access-control:redacted-viewer",
        .encryption_policy_ref = "encryption-at-rest-policy:retained-fixture",
        .telemetry_transport_state = "disabled-fixture",
        .durable_write_state = "disabled-fixture",
        .local_observation_refs = &.{},
        .review_gate = "otel-bridge-reviewed",
        .blocked_claims = &.{ "live-exporter-enabled", "otlp-collector-endpoint-configured", "sampled-out-event-forwarded" },
        .sample_attributes = &.{ "trace_id=fixture-trace", "span_id=fixture-span", "parent_id=fixture-parent" },
        .expected_agent_use = "Inspect OTel bridge shape without transport authority.",
        .forbidden_inference = "This fixture does not serialize or send OTLP records.",
    },
    .{
        .fixture_id = "redaction-access-evidence",
        .fixture_kind = .positive,
        .capture_surface_id = "redaction-access",
        .source_schema = "zigeffect.causal.production-artifact-aggregation.v1",
        .signal_kind = "policy-evidence",
        .event_kind_policy = "policy-ref-only",
        .redaction_state = "redacted-only",
        .sampling_policy = "policy-record",
        .retention_policy = "nendb-compatible-retention-ref",
        .access_policy_ref = "artifact-access-control:denied-unreviewed",
        .encryption_policy_ref = "encryption-at-rest-policy:key-owner-reviewed",
        .telemetry_transport_state = "disabled-fixture",
        .durable_write_state = "disabled-fixture",
        .local_observation_refs = &.{},
        .review_gate = "access-policy-reviewed",
        .blocked_claims = &.{ "credential-token-capture", "mutation-authority-granted" },
        .sample_attributes = &.{ "visibility=redacted", "trust_boundary=fixture", "review=required" },
        .expected_agent_use = "Cite redaction access and encryption gates for retained evidence.",
        .forbidden_inference = "This fixture does not share retained production artifacts.",
    },
    .{
        .fixture_id = "local-observation-correlation-ref",
        .fixture_kind = .positive,
        .capture_surface_id = "local-observation-correlation",
        .source_schema = "zigeffect.causal.load-test-observation-harness.v1",
        .signal_kind = "local-observation-ref",
        .event_kind_policy = "local-advisory-ref",
        .redaction_state = "redacted-local-snippet",
        .sampling_policy = "bounded-local-iterations",
        .retention_policy = "nendb-compatible-retention-ref",
        .access_policy_ref = "artifact-access-control:local-fixture",
        .encryption_policy_ref = "encryption-at-rest-policy:future-retention-review",
        .telemetry_transport_state = "disabled-fixture",
        .durable_write_state = "disabled-fixture",
        .local_observation_refs = &.{ "local-observation:app-request-trace" },
        .review_gate = "local-observation-separated",
        .blocked_claims = &.{ "local-observation-as-production-capacity", "ci-telemetry-gate" },
        .sample_attributes = &.{ "scenario_id=app-request-trace", "review_gate=needs-review", "capacity_claim=false" },
        .expected_agent_use = "Link advisory local observations without promoting them to production evidence.",
        .forbidden_inference = "This fixture does not prove production capacity or production telemetry.",
    },
    .{
        .fixture_id = "sampling-boundary-sampled-in",
        .fixture_kind = .positive,
        .capture_surface_id = "runtime-trace",
        .source_schema = "zigeffect.causal.backend-conformance.v1",
        .signal_kind = "sampling-policy",
        .event_kind_policy = "allowlisted-bounded",
        .redaction_state = "redacted-before-storage",
        .sampling_policy = "sampled-in-only-sampled-out-excluded",
        .retention_policy = "nendb-compatible-retention-ref",
        .access_policy_ref = "artifact-access-control:redacted-viewer",
        .encryption_policy_ref = "encryption-at-rest-policy:retained-fixture",
        .telemetry_transport_state = "disabled-fixture",
        .durable_write_state = "disabled-fixture",
        .local_observation_refs = &.{},
        .review_gate = "sampling-bounded",
        .blocked_claims = &.{ "unbounded-attribute-cardinality", "sampled-out-event-forwarded" },
        .sample_attributes = &.{ "sample_decision=sampled-in", "cardinality=bounded", "sampled_out_forwarded=false" },
        .expected_agent_use = "Explain sampling boundary and sampled-out exclusion.",
        .forbidden_inference = "This fixture does not permit unbounded attributes or sampled-out forwarding.",
    },
};
```

- [ ] **Step 3: Add static negative fixtures and validation checks**

Add `negative_fixtures`, `validation_checks`, `agent_rules`,
`non_goals`, and `verification_commands` constants. The negative fixture ids
must match the design spec exactly:

```zig
const validation_checks: []const ValidationCheck = &.{
    .{ .id = "positive-fixture-surface-coverage", .status = "passed", .evidence = &.{ "runtime-trace", "app-semantic", "backend-export-otel", "redaction-access", "local-observation-correlation" }, .blocks_claim = "missing capture surface fixture coverage" },
    .{ .id = "required-field-coverage", .status = "passed", .evidence = &.{ "all positive fixtures carry the required telemetry field contract" }, .blocks_claim = "fixture records can omit required telemetry fields" },
    .{ .id = "negative-fixture-claim-coverage", .status = "passed", .evidence = &.{ "14 negative fixtures cover design blocked claims" }, .blocks_claim = "blocked telemetry claims can be inferred from missing fixtures" },
    .{ .id = "forbidden-value-absence", .status = "passed", .evidence = &.{ "no positive fixture uses raw live unbounded non-nendb ci or mutation values" }, .blocks_claim = "positive fixtures authorize forbidden values" },
    .{ .id = "local-observation-separated", .status = "passed", .evidence = &.{ "local observations appear only as refs" }, .blocks_claim = "local observations prove production telemetry or capacity" },
    .{ .id = "nendb-retention-direction", .status = "passed", .evidence = &.{ "retention policy remains nendb-compatible-retention-ref" }, .blocks_claim = "non-NenDB durable adapter work is in scope" },
    .{ .id = "solid-webui-direction", .status = "passed", .evidence = &.{ "React and alternate renderer fixture is rejected" }, .blocks_claim = "fixture work switches workbench renderer" },
    .{ .id = "authority-boundary", .status = "passed", .evidence = &.{ "applied false mutation none live durable ci disabled" }, .blocks_claim = "fixtures grant operational mutation authority" },
};
```

- [ ] **Step 4: Implement helpers and parser**

Implement:

```zig
fn kindName(kind: FixtureKind) []const u8 {
    return switch (kind) {
        .positive => "positive",
        .negative => "negative",
    };
}

fn positiveFixtures() []const FixtureRecord {
    return positive_fixtures;
}

fn negativeFixtures() []const NegativeFixture {
    return negative_fixtures;
}

fn validationChecks() []const ValidationCheck {
    return validation_checks;
}

fn findFixture(id: []const u8) ?FixtureRecord {
    for (positive_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.fixture_id, id)) return fixture;
    }
    return null;
}
```

Implement `parseOptions` using a small index loop:

```zig
fn parseFormat(value: []const u8) !OutputFormat {
    if (std.mem.eql(u8, value, "text")) return .text;
    if (std.mem.eql(u8, value, "json")) return .json;
    return error.UnknownFormat;
}
```

`parseOptions` should start from `args[1..]`, default to catalog text, parse
`emit` and `validate` before remaining flags, and validate fixture ids with
`findFixture`.

- [ ] **Step 5: Implement JSON string escaping and renderers**

Use the escaping pattern from existing report tools:

```zig
fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |char| {
        switch (char) {
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '"' => try output.appendSlice(allocator, "\\\""),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, char),
        }
    }
    try output.append(allocator, '"');
}
```

Implement these renderers:

- `formatCatalogText`
- `formatCatalogJson`
- `formatFixtureText`
- `formatFixtureJson`
- `formatValidationText`
- `formatValidationJson`

Text output must include these exact labels for tests:

```text
schema: zigeffect.causal.production-telemetry-capture-fixtures.v1
production telemetry ingestion: false
live exporter enabled: false
durable write enabled: false
ci gate enabled: false
positive fixture: runtime-trace-span-event
negative fixture: raw-request-body-capture
validation check: required-field-coverage
```

JSON output must include these exact keys:

```json
"schema"
"production_telemetry_ingestion"
"live_exporter_enabled"
"durable_write_enabled"
"ci_gate_enabled"
"positive_fixtures"
"negative_fixtures"
"validation_checks"
```

- [ ] **Step 6: Implement `main`**

Add:

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const options = parseOptions(args) catch |err| {
        std.debug.print("causal-production-telemetry-capture-fixtures error: {s}\n{s}", .{ @errorName(err), usage() });
        return err;
    };

    const report = switch (options.mode) {
        .catalog => switch (options.format) {
            .text => try formatCatalogText(allocator),
            .json => try formatCatalogJson(allocator),
        },
        .emit => blk: {
            const fixture = findFixture(options.fixture_id.?).?;
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
    defer allocator.free(report);

    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll(report);
}
```

- [ ] **Step 7: Run focused test and fix failures**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_capture_fixtures.zig
```

Expected: all tests in the new tool pass.

## Task 3: Wire Build, Schema Governance, And Backlog

**Files:**

- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Add build step**

In `packages/zigeffect/build.zig`, add a module/executable/test block next to
`causal_production_telemetry_capture_design_tool_module`:

```zig
const causal_production_telemetry_capture_fixtures_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_telemetry_capture_fixtures.zig"),
    .target = target,
    .optimize = optimize,
});
const causal_production_telemetry_capture_fixtures_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-telemetry-capture-fixtures",
    .root_module = causal_production_telemetry_capture_fixtures_tool_module,
});
const run_causal_production_telemetry_capture_fixtures_tool = b.addRunArtifact(causal_production_telemetry_capture_fixtures_tool);
if (b.args) |args| run_causal_production_telemetry_capture_fixtures_tool.addArgs(args);
const causal_production_telemetry_capture_fixtures_step = b.step("causal-production-telemetry-capture-fixtures", "Print causal production telemetry capture fixture catalog");
causal_production_telemetry_capture_fixtures_step.dependOn(&run_causal_production_telemetry_capture_fixtures_tool.step);

const causal_production_telemetry_capture_fixtures_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-telemetry-capture-fixtures-tests",
    .root_module = causal_production_telemetry_capture_fixtures_tool_module,
});
const run_causal_production_telemetry_capture_fixtures_tool_tests = b.addRunArtifact(causal_production_telemetry_capture_fixtures_tool_tests);
test_step.dependOn(&run_causal_production_telemetry_capture_fixtures_tool_tests.step);
examples_step.dependOn(&run_causal_production_telemetry_capture_fixtures_tool.step);
examples_step.dependOn(&run_causal_production_telemetry_capture_fixtures_tool_tests.step);
```

- [ ] **Step 2: Register schema governance entry**

In `packages/zigeffect/tools/causal_schema_governance.zig`, insert after
`production-telemetry-capture-design`:

```zig
.{
    .schema = "zigeffect.causal.production-telemetry-capture-fixtures.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-production-telemetry-capture-fixtures"},
    .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry readiness review" },
    .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "fixtures-only", "no-live-ingestion" },
    .governance_requirements = &.{ "fixture catalog tests", "validation report tests", "negative telemetry fixtures", "next-branch handoff" },
},
```

Update tests:

```zig
try expectSchema(entries, "zigeffect.causal.production-telemetry-capture-fixtures.v1");
try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-capture-fixtures.v1") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_count\": 52") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-capture-fixtures.v1\"") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "fixtures-only") != null);
```

- [ ] **Step 3: Update hardening backlog constants and item**

In `packages/zigeffect/tools/causal_production_hardening_backlog.zig`:

- set `recommendation` to `start-production-telemetry-readiness-review`;
- set `recommended_next_branch` to
  `codex/zigeffect-causal-production-telemetry-readiness-review`;
- add a delivered backlog item with id `production-telemetry-capture-fixtures`;
- append `production-telemetry-capture-fixtures` to `dependency_order`;
- add verification commands:

```zig
"zig build causal-production-telemetry-capture-fixtures",
"zig build causal-production-telemetry-capture-fixtures -- --format json",
"zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json",
"zig build causal-production-telemetry-capture-fixtures -- validate --format json",
```

Update tests to assert:

```zig
try expectBacklogItem("production-telemetry-capture-fixtures");
try expectBacklogItemStatus("production-telemetry-capture-fixtures", "delivered");
try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-capture-fixtures") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-capture-fixtures") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-capture-fixtures\"") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-capture-fixtures -- validate --format json") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "codex/zigeffect-causal-production-telemetry-readiness-review") != null);
```

- [ ] **Step 4: Run integration commands**

Run:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-capture-fixtures
zig build causal-production-telemetry-capture-fixtures -- --format json
zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json
zig build causal-production-telemetry-capture-fixtures -- validate --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: all commands exit 0 and print the new schema/branch fields.

## Task 4: Update Documentation

**Files:**

- Create: `packages/zigeffect/docs/production-telemetry-capture-fixtures.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-telemetry-capture-design.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Create fixture docs**

Create `packages/zigeffect/docs/production-telemetry-capture-fixtures.md`
with these sections:

```markdown
# zigeffect Causal Production Telemetry Capture Fixtures

`causal-production-telemetry-capture-fixtures` emits deterministic fixture
records for future production telemetry capture. The fixtures are examples and
validation evidence only.

## Command

## Boundary

## Positive Fixtures

## Negative Fixtures

## Validation

## Agent Guidance

## Verification
```

The Boundary section must state that live ingestion, exporters, OTLP sends,
collector endpoints, durable production writes, CI gates, production capacity
claims, non-NenDB adapter work, alternate renderers, and mutation authority are
out of scope.

- [ ] **Step 2: Update README and operations command lists**

Add the command group:

```sh
zig build causal-production-telemetry-capture-fixtures
zig build causal-production-telemetry-capture-fixtures -- --format json
zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json
zig build causal-production-telemetry-capture-fixtures -- validate --format json
```

Add prose that the schema is
`zigeffect.causal.production-telemetry-capture-fixtures.v1` and that the next
branch is
`codex/zigeffect-causal-production-telemetry-readiness-review`.

- [ ] **Step 3: Update schema governance docs**

Add a section:

```markdown
- `zigeffect.causal.production-telemetry-capture-fixtures.v1`

The production-telemetry-capture-fixtures report is record-only,
fixtures-only, and no-live-ingestion. It is emitted by
`causal-production-telemetry-capture-fixtures` and consumed by agents,
reviewers, the production-hardening backlog, and future production telemetry
readiness review work.
```

- [ ] **Step 4: Update roadmap and backlog docs**

Update the production hardening backlog and roadmap to mark the fixture branch
delivered, then set the current next branch to
`codex/zigeffect-causal-production-telemetry-readiness-review`.

- [ ] **Step 5: Run docs checks**

Run:

```sh
git diff --check
```

Expected: exit 0.

## Task 5: Full Verification And Commit

**Files:**

- All files touched in Tasks 1-4.

- [ ] **Step 1: Format Zig files**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_production_telemetry_capture_fixtures.zig tools/causal_schema_governance.zig tools/causal_production_hardening_backlog.zig build.zig
```

Expected: exit 0.

- [ ] **Step 2: Run focused fixture verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_capture_fixtures.zig
zig build causal-production-telemetry-capture-fixtures
zig build causal-production-telemetry-capture-fixtures -- --format json
zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json
zig build causal-production-telemetry-capture-fixtures -- validate --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: every command exits 0.

- [ ] **Step 3: Run package verification**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test
```

Expected: every command exits 0.

- [ ] **Step 4: Run repo verification**

Run:

```sh
cd ../..
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

Expected:

- workbench tests: `45 pass`, `0 fail`;
- workbench typecheck exits 0;
- workbench build exits 0;
- `bun run check` exits 0;
- `bun run zig:test` exits 0;
- `git diff --check` exits 0.

- [ ] **Step 5: Stage and commit**

Run:

```sh
git add packages/zigeffect/tools/causal_production_telemetry_capture_fixtures.zig \
  packages/zigeffect/docs/production-telemetry-capture-fixtures.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/docs/production-telemetry-capture-design.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/roadmap.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add production telemetry capture fixtures"
```

Expected: one implementation commit on
`codex/zigeffect-causal-production-telemetry-capture-fixtures`.
