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

const source_contracts: []const SourceContract = &.{
    .{
        .id = "production-telemetry-capture-design",
        .schema = "zigeffect.causal.production-telemetry-capture-design.v1",
        .producer = "causal-production-telemetry-capture-design",
        .evidence_role = "approved capture surfaces required fields readiness gates and negative fixture ids",
        .authority_boundary = "design and fixture handoff only; no live telemetry",
    },
    .{
        .id = "load-test-observation-harness",
        .schema = "zigeffect.causal.load-test-observation-harness.v1",
        .producer = "causal-load-test-observation-harness",
        .evidence_role = "local advisory observation refs for fixture correlation",
        .authority_boundary = "local observations only; not production telemetry or capacity evidence",
    },
    .{
        .id = "causal-otel-record",
        .schema = "zigeffect.causal.otel_record.v1",
        .producer = "CausalOtelBackendState",
        .evidence_role = "exporter-neutral span and span-event record shape",
        .authority_boundary = "record bridge only; no OTLP serialization network send SDK setup or collector endpoint",
    },
    .{
        .id = "backend-conformance",
        .schema = "zigeffect.causal.backend-conformance.v1",
        .producer = "causal-backend-conformance",
        .evidence_role = "redacted bounded stored event and sampled-out exclusion evidence",
        .authority_boundary = "backend behavior evidence only; not live telemetry ingestion",
    },
    .{
        .id = "production-artifact-aggregation",
        .schema = "zigeffect.causal.production-artifact-aggregation.v1",
        .producer = "causal-production-artifact-aggregation",
        .evidence_role = "source provenance redaction state trust boundary and aggregation review",
        .authority_boundary = "reviewed contract only; no aggregation of live production artifacts",
    },
    .{
        .id = "artifact-access-control",
        .schema = "zigeffect.causal.artifact-access-control.v1",
        .producer = "causal-artifact-access-control",
        .evidence_role = "redacted-only access policy refs",
        .authority_boundary = "access decision record only; no production sharing action",
    },
    .{
        .id = "encryption-at-rest-policy",
        .schema = "zigeffect.causal.encryption-at-rest-policy.v1",
        .producer = "causal-encryption-at-rest-policy",
        .evidence_role = "redaction ordering and encrypted artifact fixture policy",
        .authority_boundary = "policy evidence only; no retained production storage is written",
    },
};

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
        .local_observation_refs = &.{"local-observation:app-request-trace"},
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

const negative_fixtures: []const NegativeFixture = &.{
    .{
        .id = "live-exporter-enabled",
        .attempted_claim = "The fixture branch enables a production telemetry exporter.",
        .decision = "rejected",
        .reason = "live_exporter_enabled remains false and transport state is disabled-fixture",
        .violated_field_or_gate = "telemetry_transport_state",
        .safe_alternative = "use fixture records to model shape before exporter review",
    },
    .{
        .id = "otlp-collector-endpoint-configured",
        .attempted_claim = "The fixture branch configures an OTLP collector endpoint.",
        .decision = "rejected",
        .reason = "collector endpoints and network sends remain out of scope",
        .violated_field_or_gate = "otel-bridge-reviewed",
        .safe_alternative = "cite CausalOtelRecord fixture fields only",
    },
    .{
        .id = "raw-request-body-capture",
        .attempted_claim = "A fixture may include raw production request bodies.",
        .decision = "rejected",
        .reason = "app semantic fixtures use schema refs and data refs only",
        .violated_field_or_gate = "redaction_state",
        .safe_alternative = "use redacted refs and blocked_claims",
    },
    .{
        .id = "raw-header-capture",
        .attempted_claim = "A fixture may include raw headers.",
        .decision = "rejected",
        .reason = "headers can contain credentials and tracking identifiers",
        .violated_field_or_gate = "redaction-reviewed",
        .safe_alternative = "use header policy refs without header values",
    },
    .{
        .id = "raw-prompt-capture",
        .attempted_claim = "A fixture may include raw prompt content.",
        .decision = "rejected",
        .reason = "prompt content must not enter telemetry fixture records",
        .violated_field_or_gate = "redaction_state",
        .safe_alternative = "use prompt policy refs without prompt values",
    },
    .{
        .id = "credential-token-capture",
        .attempted_claim = "A fixture may include credentials or tokens for debugging.",
        .decision = "rejected",
        .reason = "secret capture is forbidden before and after redaction review",
        .violated_field_or_gate = "redaction-reviewed",
        .safe_alternative = "use credential_redacted=true style attributes only",
    },
    .{
        .id = "unbounded-attribute-cardinality",
        .attempted_claim = "Fixture attributes may be arbitrary and unbounded.",
        .decision = "rejected",
        .reason = "event kind and attribute cardinality must remain bounded",
        .violated_field_or_gate = "event_kind_policy",
        .safe_alternative = "use allowlisted-bounded fixture attributes",
    },
    .{
        .id = "sampled-out-event-forwarded",
        .attempted_claim = "A sampled-out event may still be forwarded in telemetry.",
        .decision = "rejected",
        .reason = "backend conformance excludes sampled-out events from downstream storage",
        .violated_field_or_gate = "sampling_policy",
        .safe_alternative = "model sampled-in records and explicit sampled-out exclusion",
    },
    .{
        .id = "local-observation-as-production-capacity",
        .attempted_claim = "Local observation fixture refs prove production capacity.",
        .decision = "rejected",
        .reason = "local observations are advisory and separate from production telemetry",
        .violated_field_or_gate = "local-observation-separated",
        .safe_alternative = "cite local observations as advisory refs only",
    },
    .{
        .id = "non-nendb-durable-storage",
        .attempted_claim = "Fixture work may introduce non-NenDB durable storage.",
        .decision = "rejected",
        .reason = "durable direction remains NenDB adapter only",
        .violated_field_or_gate = "retention_policy",
        .safe_alternative = "keep retention_policy set to nendb-compatible-retention-ref",
    },
    .{
        .id = "cockroach-adapter-work",
        .attempted_claim = "Cockroach telemetry adapter work is included.",
        .decision = "rejected",
        .reason = "Cockroach adapter work is explicitly out of scope for this roadmap stage",
        .violated_field_or_gate = "retention-nendb-compatible",
        .safe_alternative = "use NenDB-compatible retention refs only",
    },
    .{
        .id = "react-or-alternate-renderer",
        .attempted_claim = "Workbench telemetry UI may switch to React or another renderer.",
        .decision = "rejected",
        .reason = "workbench direction remains SolidJS inside webui-dev zig-webui",
        .violated_field_or_gate = "solid-webui-direction",
        .safe_alternative = "preserve SolidJS webui fixture direction",
    },
    .{
        .id = "ci-telemetry-gate",
        .attempted_claim = "CI may fail on production telemetry fixture thresholds.",
        .decision = "rejected",
        .reason = "CI telemetry gates require future reviewed thresholds and evidence",
        .violated_field_or_gate = "ci_gate_enabled",
        .safe_alternative = "emit validation evidence without failing CI on telemetry thresholds",
    },
    .{
        .id = "mutation-authority-granted",
        .attempted_claim = "Agents may mutate source config registry deployment rollout alert app or production state.",
        .decision = "rejected",
        .reason = "mutation_authority remains none",
        .violated_field_or_gate = "mutation_authority",
        .safe_alternative = "route future proposals through readiness review",
    },
};

const validation_checks: []const ValidationCheck = &.{
    .{
        .id = "positive-fixture-surface-coverage",
        .status = "passed",
        .evidence = &.{ "runtime-trace", "app-semantic", "backend-export-otel", "redaction-access", "local-observation-correlation" },
        .blocks_claim = "missing capture surface fixture coverage",
    },
    .{
        .id = "required-field-coverage",
        .status = "passed",
        .evidence = &.{"all positive fixtures carry the required telemetry field contract"},
        .blocks_claim = "fixture records can omit required telemetry fields",
    },
    .{
        .id = "negative-fixture-claim-coverage",
        .status = "passed",
        .evidence = &.{"14 negative fixtures cover design blocked claims"},
        .blocks_claim = "blocked telemetry claims can be inferred from missing fixtures",
    },
    .{
        .id = "forbidden-value-absence",
        .status = "passed",
        .evidence = &.{"no positive fixture uses raw live unbounded non-nendb ci or mutation values"},
        .blocks_claim = "positive fixtures authorize forbidden values",
    },
    .{
        .id = "local-observation-separated",
        .status = "passed",
        .evidence = &.{"local observations appear only as refs"},
        .blocks_claim = "local observations prove production telemetry or capacity",
    },
    .{
        .id = "nendb-retention-direction",
        .status = "passed",
        .evidence = &.{"retention policy remains nendb-compatible-retention-ref"},
        .blocks_claim = "non-NenDB durable adapter work is in scope",
    },
    .{
        .id = "solid-webui-direction",
        .status = "passed",
        .evidence = &.{"React and alternate renderer fixture is rejected"},
        .blocks_claim = "fixture work switches workbench renderer",
    },
    .{
        .id = "authority-boundary",
        .status = "passed",
        .evidence = &.{"applied false mutation none live durable ci disabled"},
        .blocks_claim = "fixtures grant operational mutation authority",
    },
};

const agent_rules: []const AgentRule = &.{
    .{
        .id = "cite-fixture-id",
        .guidance = "Use fixture ids and validation checks when proposing future telemetry work.",
    },
    .{
        .id = "separate-shape-from-live-evidence",
        .guidance = "Treat fixtures as record shape examples, not live production telemetry.",
    },
    .{
        .id = "block-forbidden-claims",
        .guidance = "Use negative fixtures to reject raw payload endpoint credential non-NenDB CI renderer and mutation claims.",
    },
    .{
        .id = "route-readiness-review",
        .guidance = "Send future implementation proposals through the readiness-review branch before live telemetry work.",
    },
};

const non_goals: []const []const u8 = &.{
    "live production telemetry ingestion",
    "OTLP serialization SDK setup collector delivery or network calls",
    "production credentials endpoints hostnames raw user ids tenant ids secrets headers request bodies prompts or raw payload capture",
    "durable production writes",
    "non-NenDB durable adapter work",
    "Cockroach adapter work",
    "production capacity sizing autoscaling cost estimates or production load generation",
    "CI timing gates or telemetry gates",
    "production dashboards multi-user hosting or production dashboard streaming",
    "React or alternate renderer work",
    "source config registry deployment rollout alert app or production mutation authority",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig test tools/causal_production_telemetry_capture_fixtures.zig",
    "zig build causal-production-telemetry-capture-fixtures",
    "zig build causal-production-telemetry-capture-fixtures -- --format json",
    "zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json",
    "zig build causal-production-telemetry-capture-fixtures -- validate --format json",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
    "cd ../..",
    "bun run zigeffect:workbench:test",
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:build",
    "bun run check",
    "bun run zig:test",
    "git diff --check",
};

fn usage() []const u8 {
    return
    \\usage:
    \\  zig build causal-production-telemetry-capture-fixtures
    \\  zig build causal-production-telemetry-capture-fixtures -- --format text
    \\  zig build causal-production-telemetry-capture-fixtures -- --format json
    \\  zig build causal-production-telemetry-capture-fixtures -- emit <fixture-id> [--format text|json]
    \\  zig build causal-production-telemetry-capture-fixtures -- validate [--format text|json]
    \\
    \\fixtures:
    \\  runtime-trace-span-event
    \\  app-semantic-redacted-ref
    \\  backend-export-otel-record
    \\  redaction-access-evidence
    \\  local-observation-correlation-ref
    \\  sampling-boundary-sampled-in
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

fn findFixture(id: []const u8) ?FixtureRecord {
    for (positive_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.fixture_id, id)) return fixture;
    }
    return null;
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

fn formatCatalogText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try appendHeaderText(allocator, &output);

    try output.appendSlice(allocator, "source contracts:\n");
    for (source_contracts) |contract| {
        try output.print(allocator,
            \\- source contract: {s}
            \\  schema: {s}
            \\  producer: {s}
            \\  evidence role: {s}
            \\  authority boundary: {s}
            \\
        , .{ contract.id, contract.schema, contract.producer, contract.evidence_role, contract.authority_boundary });
    }

    try output.appendSlice(allocator, "\npositive fixtures:\n");
    for (positive_fixtures) |fixture| {
        try appendFixtureText(allocator, &output, fixture, "- positive fixture");
    }

    try output.appendSlice(allocator, "\nnegative fixtures:\n");
    for (negative_fixtures) |fixture| {
        try output.print(allocator,
            \\- negative fixture: {s}
            \\  attempted claim: {s}
            \\  decision: {s}
            \\  reason: {s}
            \\  violated field or gate: {s}
            \\  safe alternative: {s}
            \\
        , .{ fixture.id, fixture.attempted_claim, fixture.decision, fixture.reason, fixture.violated_field_or_gate, fixture.safe_alternative });
    }

    try output.appendSlice(allocator, "\nvalidation checks:\n");
    for (validation_checks) |check| {
        try output.print(allocator,
            \\- validation check: {s}
            \\  status: {s}
            \\  evidence:
            \\
        , .{ check.id, check.status });
        for (check.evidence) |evidence| {
            try output.print(allocator, "    - {s}\n", .{evidence});
        }
        try output.print(allocator, "  blocks claim: {s}\n", .{check.blocks_claim});
    }

    try output.appendSlice(allocator, "\nagent rules:\n");
    for (agent_rules) |rule| {
        try output.print(allocator, "- agent rule: {s}\n  guidance: {s}\n", .{ rule.id, rule.guidance });
    }

    try output.appendSlice(allocator, "\nnon-goals:\n");
    for (non_goals) |goal| {
        try output.print(allocator, "- {s}\n", .{goal});
    }

    try output.appendSlice(allocator, "\nverification commands:\n");
    for (verification_commands) |command| {
        try output.print(allocator, "- {s}\n", .{command});
    }

    return output.toOwnedSlice(allocator);
}

fn formatCatalogJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendHeaderJson(allocator, &output);

    try output.appendSlice(allocator, ",\n  \"source_contracts\": [\n");
    for (source_contracts, 0..) |contract, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    { \"id\": ");
        try appendJsonString(allocator, &output, contract.id);
        try output.appendSlice(allocator, ", \"schema\": ");
        try appendJsonString(allocator, &output, contract.schema);
        try output.appendSlice(allocator, ", \"producer\": ");
        try appendJsonString(allocator, &output, contract.producer);
        try output.appendSlice(allocator, ", \"evidence_role\": ");
        try appendJsonString(allocator, &output, contract.evidence_role);
        try output.appendSlice(allocator, ", \"authority_boundary\": ");
        try appendJsonString(allocator, &output, contract.authority_boundary);
        try output.appendSlice(allocator, " }");
    }

    try output.appendSlice(allocator, "\n  ],\n  \"positive_fixtures\": [\n");
    for (positive_fixtures, 0..) |fixture, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    ");
        try appendFixtureJsonObject(allocator, &output, fixture);
    }

    try output.appendSlice(allocator, "\n  ],\n  \"negative_fixtures\": [\n");
    for (negative_fixtures, 0..) |fixture, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    ");
        try appendNegativeFixtureJsonObject(allocator, &output, fixture);
    }

    try output.appendSlice(allocator, "\n  ],\n  \"validation_checks\": [\n");
    for (validation_checks, 0..) |check, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    ");
        try appendValidationCheckJsonObject(allocator, &output, check);
    }

    try output.appendSlice(allocator, "\n  ],\n  \"agent_rules\": [\n");
    for (agent_rules, 0..) |rule, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    { \"id\": ");
        try appendJsonString(allocator, &output, rule.id);
        try output.appendSlice(allocator, ", \"guidance\": ");
        try appendJsonString(allocator, &output, rule.guidance);
        try output.appendSlice(allocator, " }");
    }
    try output.appendSlice(allocator, "\n  ],\n  \"non_goals\": ");
    try appendJsonStringArray(allocator, &output, non_goals);
    try output.appendSlice(allocator, ",\n  \"verification_commands\": ");
    try appendJsonStringArray(allocator, &output, verification_commands);
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatFixtureText(allocator: std.mem.Allocator, fixture: FixtureRecord) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try appendHeaderText(allocator, &output);
    try output.appendSlice(allocator, "selected fixture:\n");
    try appendFixtureText(allocator, &output, fixture, "- fixture");
    return output.toOwnedSlice(allocator);
}

fn formatFixtureJson(allocator: std.mem.Allocator, fixture: FixtureRecord) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendHeaderJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"fixture\": ");
    try appendFixtureJsonObject(allocator, &output, fixture);
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatValidationText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try appendHeaderText(allocator, &output);
    try output.appendSlice(allocator, "validation checks:\n");
    for (validation_checks) |check| {
        try output.print(allocator,
            \\- validation check: {s}
            \\  status: {s}
            \\  evidence:
            \\
        , .{ check.id, check.status });
        for (check.evidence) |evidence| {
            try output.print(allocator, "    - {s}\n", .{evidence});
        }
        try output.print(allocator, "  blocks claim: {s}\n", .{check.blocks_claim});
    }

    return output.toOwnedSlice(allocator);
}

fn formatValidationJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendHeaderJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"validation_checks\": [\n");
    for (validation_checks, 0..) |check, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    ");
        try appendValidationCheckJsonObject(allocator, &output, check);
    }
    try output.appendSlice(allocator, "\n  ]\n}\n");

    return output.toOwnedSlice(allocator);
}

fn appendHeaderText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.print(allocator,
        \\schema: {s}
        \\schema version: {d}
        \\status: {s}
        \\generated by: {s}
        \\source branch: {s}
        \\recommendation: {s}
        \\next branch: {s}
        \\applied: {}
        \\mutation authority: {s}
        \\production telemetry ingestion: {}
        \\live exporter enabled: {}
        \\durable write enabled: {}
        \\ci gate enabled: {}
        \\
        \\
    , .{
        production_telemetry_capture_fixtures_schema,
        production_telemetry_capture_fixtures_schema_version,
        status,
        generated_by,
        source_branch,
        recommendation,
        next_branch,
        applied,
        mutation_authority,
        production_telemetry_ingestion,
        live_exporter_enabled,
        durable_write_enabled,
        ci_gate_enabled,
    });
}

fn appendHeaderJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, output, production_telemetry_capture_fixtures_schema);
    try output.print(allocator, ",\n  \"schema_version\": {d}", .{production_telemetry_capture_fixtures_schema_version});
    try output.appendSlice(allocator, ",\n  \"status\": ");
    try appendJsonString(allocator, output, status);
    try output.appendSlice(allocator, ",\n  \"generated_by\": ");
    try appendJsonString(allocator, output, generated_by);
    try output.appendSlice(allocator, ",\n  \"source_branch\": ");
    try appendJsonString(allocator, output, source_branch);
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(allocator, output, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch\": ");
    try appendJsonString(allocator, output, next_branch);
    try output.print(allocator, ",\n  \"applied\": {},\n  \"mutation_authority\": ", .{applied});
    try appendJsonString(allocator, output, mutation_authority);
    try output.print(allocator,
        \\,
        \\  "production_telemetry_ingestion": {},
        \\  "live_exporter_enabled": {},
        \\  "durable_write_enabled": {},
        \\  "ci_gate_enabled": {}
    , .{ production_telemetry_ingestion, live_exporter_enabled, durable_write_enabled, ci_gate_enabled });
}

fn appendFixtureText(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    fixture: FixtureRecord,
    label: []const u8,
) !void {
    try output.print(allocator,
        \\{s}: {s}
        \\  fixture kind: {s}
        \\  capture surface id: {s}
        \\  source schema: {s}
        \\  signal kind: {s}
        \\  event kind policy: {s}
        \\  redaction state: {s}
        \\  sampling policy: {s}
        \\  retention policy: {s}
        \\  access policy ref: {s}
        \\  encryption policy ref: {s}
        \\  telemetry transport state: {s}
        \\  durable write state: {s}
        \\  local observation refs:
        \\
    , .{
        label,
        fixture.fixture_id,
        kindName(fixture.fixture_kind),
        fixture.capture_surface_id,
        fixture.source_schema,
        fixture.signal_kind,
        fixture.event_kind_policy,
        fixture.redaction_state,
        fixture.sampling_policy,
        fixture.retention_policy,
        fixture.access_policy_ref,
        fixture.encryption_policy_ref,
        fixture.telemetry_transport_state,
        fixture.durable_write_state,
    });
    if (fixture.local_observation_refs.len == 0) {
        try output.appendSlice(allocator, "    - none\n");
    } else {
        for (fixture.local_observation_refs) |ref| {
            try output.print(allocator, "    - {s}\n", .{ref});
        }
    }
    try output.print(allocator,
        \\  review gate: {s}
        \\  blocked claims:
        \\
    , .{fixture.review_gate});
    for (fixture.blocked_claims) |claim| {
        try output.print(allocator, "    - {s}\n", .{claim});
    }
    try output.appendSlice(allocator, "  sample attributes:\n");
    for (fixture.sample_attributes) |attribute| {
        try output.print(allocator, "    - {s}\n", .{attribute});
    }
    try output.print(allocator,
        \\  expected agent use: {s}
        \\  forbidden inference: {s}
        \\
    , .{ fixture.expected_agent_use, fixture.forbidden_inference });
}

fn appendFixtureJsonObject(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixture: FixtureRecord) !void {
    try output.appendSlice(allocator, "{ \"fixture_id\": ");
    try appendJsonString(allocator, output, fixture.fixture_id);
    try output.appendSlice(allocator, ", \"fixture_kind\": ");
    try appendJsonString(allocator, output, kindName(fixture.fixture_kind));
    try output.appendSlice(allocator, ", \"capture_surface_id\": ");
    try appendJsonString(allocator, output, fixture.capture_surface_id);
    try output.appendSlice(allocator, ", \"source_schema\": ");
    try appendJsonString(allocator, output, fixture.source_schema);
    try output.appendSlice(allocator, ", \"signal_kind\": ");
    try appendJsonString(allocator, output, fixture.signal_kind);
    try output.appendSlice(allocator, ", \"event_kind_policy\": ");
    try appendJsonString(allocator, output, fixture.event_kind_policy);
    try output.appendSlice(allocator, ", \"redaction_state\": ");
    try appendJsonString(allocator, output, fixture.redaction_state);
    try output.appendSlice(allocator, ", \"sampling_policy\": ");
    try appendJsonString(allocator, output, fixture.sampling_policy);
    try output.appendSlice(allocator, ", \"retention_policy\": ");
    try appendJsonString(allocator, output, fixture.retention_policy);
    try output.appendSlice(allocator, ", \"access_policy_ref\": ");
    try appendJsonString(allocator, output, fixture.access_policy_ref);
    try output.appendSlice(allocator, ", \"encryption_policy_ref\": ");
    try appendJsonString(allocator, output, fixture.encryption_policy_ref);
    try output.appendSlice(allocator, ", \"telemetry_transport_state\": ");
    try appendJsonString(allocator, output, fixture.telemetry_transport_state);
    try output.appendSlice(allocator, ", \"durable_write_state\": ");
    try appendJsonString(allocator, output, fixture.durable_write_state);
    try output.appendSlice(allocator, ", \"local_observation_refs\": ");
    try appendJsonStringArray(allocator, output, fixture.local_observation_refs);
    try output.appendSlice(allocator, ", \"review_gate\": ");
    try appendJsonString(allocator, output, fixture.review_gate);
    try output.appendSlice(allocator, ", \"blocked_claims\": ");
    try appendJsonStringArray(allocator, output, fixture.blocked_claims);
    try output.appendSlice(allocator, ", \"sample_attributes\": ");
    try appendJsonStringArray(allocator, output, fixture.sample_attributes);
    try output.appendSlice(allocator, ", \"expected_agent_use\": ");
    try appendJsonString(allocator, output, fixture.expected_agent_use);
    try output.appendSlice(allocator, ", \"forbidden_inference\": ");
    try appendJsonString(allocator, output, fixture.forbidden_inference);
    try output.appendSlice(allocator, " }");
}

fn appendNegativeFixtureJsonObject(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixture: NegativeFixture) !void {
    try output.appendSlice(allocator, "{ \"id\": ");
    try appendJsonString(allocator, output, fixture.id);
    try output.appendSlice(allocator, ", \"attempted_claim\": ");
    try appendJsonString(allocator, output, fixture.attempted_claim);
    try output.appendSlice(allocator, ", \"decision\": ");
    try appendJsonString(allocator, output, fixture.decision);
    try output.appendSlice(allocator, ", \"reason\": ");
    try appendJsonString(allocator, output, fixture.reason);
    try output.appendSlice(allocator, ", \"violated_field_or_gate\": ");
    try appendJsonString(allocator, output, fixture.violated_field_or_gate);
    try output.appendSlice(allocator, ", \"safe_alternative\": ");
    try appendJsonString(allocator, output, fixture.safe_alternative);
    try output.appendSlice(allocator, " }");
}

fn appendValidationCheckJsonObject(allocator: std.mem.Allocator, output: *std.ArrayList(u8), check: ValidationCheck) !void {
    try output.appendSlice(allocator, "{ \"id\": ");
    try appendJsonString(allocator, output, check.id);
    try output.appendSlice(allocator, ", \"status\": ");
    try appendJsonString(allocator, output, check.status);
    try output.appendSlice(allocator, ", \"evidence\": ");
    try appendJsonStringArray(allocator, output, check.evidence);
    try output.appendSlice(allocator, ", \"blocks_claim\": ");
    try appendJsonString(allocator, output, check.blocks_claim);
    try output.appendSlice(allocator, " }");
}

fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn appendJsonStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.append(allocator, ']');
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(args) catch |err| {
        std.debug.print("causal-production-telemetry-capture-fixtures error: {s}\n{s}", .{ @errorName(err), usage() });
        std.process.exit(1);
    };

    const output = switch (options.mode) {
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
    defer allocator.free(output);
    std.debug.print("{s}", .{output});
}

fn expectNegativeFixture(id: []const u8) !void {
    for (negativeFixtures()) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return;
    }
    return error.MissingNegativeFixture;
}

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
    try std.testing.expectError(error.UnknownFixture, parseOptions(&.{ "zigeffect-causal-production-telemetry-capture-fixtures", "emit", "missing-fixture" }));
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
