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

const source_contracts: []const SourceContract = &.{
    .{
        .id = "load-test-observation-harness",
        .schema = "zigeffect.causal.load-test-observation-harness.v1",
        .producer = "causal-load-test-observation-harness",
        .evidence_role = "local advisory timing observations and scenario catalog for future fixture design",
        .authority_boundary = "local observations only; not production telemetry or capacity evidence",
    },
    .{
        .id = "causal-otel-record",
        .schema = "zigeffect.causal.otel_record.v1",
        .producer = "CausalOtelBackendState",
        .evidence_role = "exporter-neutral span and span-event record mapping",
        .authority_boundary = "record bridge only; no OTLP serialization network send SDK setup or collector endpoint",
    },
    .{
        .id = "backend-conformance",
        .schema = "zigeffect.causal.backend-conformance.v1",
        .producer = "causal-backend-conformance",
        .evidence_role = "assigned redacted bounded stored event behavior and sampled-out event exclusion",
        .authority_boundary = "backend behavior test evidence; not live telemetry ingestion",
    },
    .{
        .id = "production-artifact-aggregation",
        .schema = "zigeffect.causal.production-artifact-aggregation.v1",
        .producer = "causal-production-artifact-aggregation",
        .evidence_role = "source provenance redaction state trust boundary and aggregation review",
        .authority_boundary = "reviewed source contract only; does not aggregate live production artifacts",
    },
    .{
        .id = "artifact-access-control",
        .schema = "zigeffect.causal.artifact-access-control.v1",
        .producer = "causal-artifact-access-control",
        .evidence_role = "visibility class redacted-only access and review decisions",
        .authority_boundary = "access decision record only; no production sharing action",
    },
    .{
        .id = "encryption-at-rest-policy",
        .schema = "zigeffect.causal.encryption-at-rest-policy.v1",
        .producer = "causal-encryption-at-rest-policy",
        .evidence_role = "key ownership redaction ordering and retained artifact encryption gate",
        .authority_boundary = "policy evidence only; no retained production storage is written",
    },
    .{
        .id = "production-capacity-planning",
        .schema = "zigeffect.causal.production-capacity-planning.v1",
        .producer = "causal-production-capacity-planning",
        .evidence_role = "capacity domains negative capacity fixtures and no-claim boundary",
        .authority_boundary = "planning-only; does not size production capacity",
    },
};

const capture_surfaces: []const CaptureSurface = &.{
    .{
        .id = "runtime-trace",
        .source = "core causal runtime events",
        .signal = "spans or span events through the existing OTel record bridge",
        .boundary = "assigned redacted bounded stored events only",
        .agent_guidance = "Use only when the event kind and runtime ids are present in retained causal evidence.",
    },
    .{
        .id = "app-semantic",
        .source = "app semantic trace API events",
        .signal = "redacted data refs domain refs schema refs policy decisions artifacts and responses",
        .boundary = "no raw request bodies headers credentials prompts or PII",
        .agent_guidance = "Classify app behavior with refs and schema names, not raw payloads.",
    },
    .{
        .id = "backend-export-otel",
        .source = "backend conformance and CausalOtelBackendState",
        .signal = "exporter-neutral CausalOtelRecord values",
        .boundary = "no OTLP serialization network send SDK setup or collector endpoint",
        .agent_guidance = "Treat this as mapping design for future fixtures, not a live exporter.",
    },
    .{
        .id = "redaction-access",
        .source = "aggregation access-control and encryption policy contracts",
        .signal = "redaction state trust boundary visibility class and review gate names",
        .boundary = "redacted-only evidence until broader access is reviewed",
        .agent_guidance = "Check redaction, access, and encryption gates before citing retained evidence.",
    },
    .{
        .id = "local-observation-correlation",
        .source = "local load-test observation records",
        .signal = "scenario id command status sample count median p95 and review gate",
        .boundary = "local observations shape design but do not become production capacity evidence",
        .agent_guidance = "Keep local observations advisory and separate from production telemetry claims.",
    },
};

const telemetry_fields: []const TelemetryField = &.{
    .{
        .name = "capture_surface_id",
        .required = true,
        .purpose = "Identifies the approved telemetry capture surface.",
        .forbidden_values = &.{ "unknown-live-source", "production-hostname" },
    },
    .{
        .name = "source_schema",
        .required = true,
        .purpose = "Names the schema that produced the source evidence.",
        .forbidden_values = &.{ "unspecified", "ad-hoc-json" },
    },
    .{
        .name = "signal_kind",
        .required = true,
        .purpose = "Classifies the future signal as runtime event app semantic record span span-event or local observation ref.",
        .forbidden_values = &.{ "raw-payload", "raw-header", "raw-prompt" },
    },
    .{
        .name = "event_kind_policy",
        .required = true,
        .purpose = "States whether event kinds are allowlisted bounded and taxonomy-reviewed.",
        .forbidden_values = &.{ "unbounded", "freeform" },
    },
    .{
        .name = "redaction_state",
        .required = true,
        .purpose = "Records whether the future telemetry evidence is redacted before storage or export.",
        .forbidden_values = &.{ "raw", "unknown" },
    },
    .{
        .name = "sampling_policy",
        .required = true,
        .purpose = "Records sampling and cardinality limits before telemetry leaves the runtime.",
        .forbidden_values = &.{ "unsampled-unbounded", "sampled-out-forwarded" },
    },
    .{
        .name = "retention_policy",
        .required = true,
        .purpose = "Names the retained-evidence policy and confirms NenDB-compatible durable direction.",
        .forbidden_values = &.{ "infinite", "cockroach-required" },
    },
    .{
        .name = "access_policy_ref",
        .required = true,
        .purpose = "Points to artifact access-control review before evidence is shared.",
        .forbidden_values = &.{ "public-by-default", "missing" },
    },
    .{
        .name = "encryption_policy_ref",
        .required = true,
        .purpose = "Points to encryption-at-rest policy before retained production artifacts exist.",
        .forbidden_values = &.{ "plaintext-retained", "missing" },
    },
    .{
        .name = "telemetry_transport_state",
        .required = true,
        .purpose = "Keeps future transport state explicit and disabled until reviewed.",
        .forbidden_values = &.{ "live-exporter-enabled", "collector-endpoint-configured" },
    },
    .{
        .name = "durable_write_state",
        .required = true,
        .purpose = "Keeps future storage authority explicit and disabled until reviewed.",
        .forbidden_values = &.{ "production-write-enabled", "non-nendb" },
    },
    .{
        .name = "local_observation_refs",
        .required = true,
        .purpose = "Links local advisory observations without promoting them to production evidence.",
        .forbidden_values = &.{ "capacity-proof", "production-slo-proof" },
    },
    .{
        .name = "review_gate",
        .required = true,
        .purpose = "Names the gate that must pass before fixtures or live telemetry work proceeds.",
        .forbidden_values = &.{ "auto-approved", "none" },
    },
    .{
        .name = "blocked_claims",
        .required = true,
        .purpose = "Lists claims that agents must not infer from the design report.",
        .forbidden_values = &.{ "empty", "implicit" },
    },
};

const readiness_gates: []const ReadinessGate = &.{
    .{
        .id = "schema-registered",
        .decision = "required",
        .required_evidence = &.{ "schema governance entry", "tool text output", "tool json output" },
        .blocks_until = "schema governance inventory includes this v1 schema",
    },
    .{
        .id = "redaction-reviewed",
        .decision = "required",
        .required_evidence = &.{ "forbidden field list", "redaction state field", "negative raw payload fixtures" },
        .blocks_until = "raw request header prompt credential and PII capture are blocked",
    },
    .{
        .id = "sampling-bounded",
        .decision = "required",
        .required_evidence = &.{ "event kind policy", "cardinality boundary", "sampled-out exclusion contract" },
        .blocks_until = "sampling and cardinality rules are explicit",
    },
    .{
        .id = "retention-nendb-compatible",
        .decision = "required",
        .required_evidence = &.{ "NenDB retention direction", "durable write state", "non-NenDB negative fixture" },
        .blocks_until = "durable direction remains NenDB adapter only",
    },
    .{
        .id = "access-policy-reviewed",
        .decision = "required",
        .required_evidence = &.{ "artifact access-control schema", "visibility class", "redacted-only sharing rule" },
        .blocks_until = "access policy review is cited",
    },
    .{
        .id = "encryption-policy-reviewed",
        .decision = "required",
        .required_evidence = &.{ "encryption-at-rest policy schema", "key ownership", "redaction ordering" },
        .blocks_until = "encryption policy review is cited",
    },
    .{
        .id = "otel-bridge-reviewed",
        .decision = "required",
        .required_evidence = &.{ "CausalOtelRecord bridge", "backend conformance", "no live exporter flag" },
        .blocks_until = "OTel mapping is reviewed without enabling export",
    },
    .{
        .id = "local-observation-separated",
        .decision = "required",
        .required_evidence = &.{ "load-test observation harness", "local advisory boundary", "capacity negative fixture" },
        .blocks_until = "local observations cannot be treated as production telemetry or capacity proof",
    },
    .{
        .id = "capacity-claim-blocked",
        .decision = "required",
        .required_evidence = &.{ "production-capacity-planning no-claim boundary", "blocked claims field", "negative capacity fixture" },
        .blocks_until = "capacity sizing remains future work",
    },
    .{
        .id = "fixture-handoff-ready",
        .decision = "required",
        .required_evidence = &.{ "next branch", "negative fixture list", "verification commands" },
        .blocks_until = "future fixtures can be modeled safely without live systems",
    },
};

const negative_fixtures: []const NegativeFixture = &.{
    .{
        .id = "live-exporter-enabled",
        .attempted_claim = "This branch enables a production telemetry exporter.",
        .decision = "rejected",
        .reason = "live_exporter_enabled is false and transport remains design-only",
    },
    .{
        .id = "otlp-collector-endpoint-configured",
        .attempted_claim = "This branch configures an OTLP collector endpoint.",
        .decision = "rejected",
        .reason = "collector endpoints and network sends are out of scope",
    },
    .{
        .id = "raw-request-body-capture",
        .attempted_claim = "Production request bodies may be captured.",
        .decision = "rejected",
        .reason = "app semantic evidence must use redacted refs and schema refs",
    },
    .{
        .id = "raw-header-capture",
        .attempted_claim = "Raw headers may be captured.",
        .decision = "rejected",
        .reason = "headers can contain credentials and tracking identifiers",
    },
    .{
        .id = "raw-prompt-capture",
        .attempted_claim = "Raw prompts may be captured.",
        .decision = "rejected",
        .reason = "prompt content must not enter this telemetry design contract",
    },
    .{
        .id = "credential-token-capture",
        .attempted_claim = "Credentials or tokens may be captured for debugging.",
        .decision = "rejected",
        .reason = "secret capture is forbidden before and after redaction review",
    },
    .{
        .id = "unbounded-attribute-cardinality",
        .attempted_claim = "Telemetry attributes may be arbitrary and unbounded.",
        .decision = "rejected",
        .reason = "sampling and cardinality rules must be explicit before fixture work",
    },
    .{
        .id = "sampled-out-event-forwarded",
        .attempted_claim = "Sampled-out events may still be forwarded to telemetry.",
        .decision = "rejected",
        .reason = "backend conformance excludes sampled-out events from downstream storage",
    },
    .{
        .id = "local-observation-as-production-capacity",
        .attempted_claim = "Local timing observations prove production capacity.",
        .decision = "rejected",
        .reason = "local observations are advisory and separated from capacity evidence",
    },
    .{
        .id = "non-nendb-durable-storage",
        .attempted_claim = "Durable telemetry storage may use a non-NenDB adapter.",
        .decision = "rejected",
        .reason = "durable direction is NenDB adapter only for this roadmap path",
    },
    .{
        .id = "cockroach-adapter-work",
        .attempted_claim = "Cockroach telemetry adapter work is included.",
        .decision = "rejected",
        .reason = "Cockroach adapter work is explicitly out of scope for this roadmap stage",
    },
    .{
        .id = "react-or-alternate-renderer",
        .attempted_claim = "Workbench telemetry UI may switch to React or another renderer.",
        .decision = "rejected",
        .reason = "workbench direction remains SolidJS inside webui-dev zig-webui",
    },
    .{
        .id = "ci-telemetry-gate",
        .attempted_claim = "CI may fail on production telemetry timing or capture gates.",
        .decision = "rejected",
        .reason = "CI telemetry gates require future reviewed fixtures and thresholds",
    },
    .{
        .id = "mutation-authority-granted",
        .attempted_claim = "Agents may mutate source config registry deployment rollout alert app or production state.",
        .decision = "rejected",
        .reason = "mutation_authority remains none",
    },
};

const agent_rules: []const AgentRule = &.{
    .{
        .id = "classify-surface-first",
        .guidance = "Identify the capture surface before reasoning about source schema fields or future fixture work.",
    },
    .{
        .id = "cite-governance-gates",
        .guidance = "Cite redaction sampling retention access encryption and OTel bridge gates when proposing telemetry fixtures.",
    },
    .{
        .id = "separate-local-from-production",
        .guidance = "Treat local observation records as advisory design input, not production telemetry or capacity evidence.",
    },
    .{
        .id = "block-live-claims",
        .guidance = "Do not infer live ingestion exporters collector endpoints durable writes CI gates capacity sizing or mutation authority.",
    },
};

const non_goals: []const []const u8 = &.{
    "live production telemetry ingestion",
    "OTLP serialization SDK setup collector delivery or network calls",
    "production credentials endpoints secrets headers request bodies prompts or raw payload capture",
    "durable production writes",
    "non-NenDB durable adapter work",
    "Cockroach adapter work",
    "production capacity sizing autoscaling or cost estimates",
    "production load generation",
    "CI timing or telemetry gates",
    "production dashboards or multi-user hosting",
    "React or alternate renderer work",
    "source config registry deployment rollout alert app or production mutation authority",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig test tools/causal_production_telemetry_capture_design.zig",
    "zig build causal-production-telemetry-capture-design",
    "zig build causal-production-telemetry-capture-design -- --format json",
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
    \\  zig build causal-production-telemetry-capture-design
    \\  zig build causal-production-telemetry-capture-design -- --format text
    \\  zig build causal-production-telemetry-capture-design -- --format json
    \\
    \\formats:
    \\  --format text|json
    \\
    ;
}

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

fn formatText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

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
        \\
        \\
    , .{
        production_telemetry_capture_design_schema,
        production_telemetry_capture_design_schema_version,
        status,
        generated_by,
        source_branch,
        recommendation,
        next_branch,
        applied,
        mutation_authority,
        production_telemetry_ingestion,
        live_exporter_enabled,
    });

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

    try output.appendSlice(allocator, "\ncapture surfaces:\n");
    for (capture_surfaces) |surface| {
        try output.print(allocator,
            \\- capture surface: {s}
            \\  source: {s}
            \\  signal: {s}
            \\  boundary: {s}
            \\  agent guidance: {s}
            \\
        , .{ surface.id, surface.source, surface.signal, surface.boundary, surface.agent_guidance });
    }

    try output.appendSlice(allocator, "\ntelemetry fields:\n");
    for (telemetry_fields) |field| {
        try output.print(allocator,
            \\- telemetry field: {s}
            \\  required: {}
            \\  purpose: {s}
            \\  forbidden values:
            \\
        , .{ field.name, field.required, field.purpose });
        for (field.forbidden_values) |value| {
            try output.print(allocator, "    - {s}\n", .{value});
        }
    }

    try output.appendSlice(allocator, "\nreadiness gates:\n");
    for (readiness_gates) |gate| {
        try output.print(allocator,
            \\- readiness gate: {s}
            \\  decision: {s}
            \\  required evidence:
            \\
        , .{ gate.id, gate.decision });
        for (gate.required_evidence) |evidence| {
            try output.print(allocator, "    - {s}\n", .{evidence});
        }
        try output.print(allocator, "  blocks until: {s}\n", .{gate.blocks_until});
    }

    try output.appendSlice(allocator, "\nnegative fixtures:\n");
    for (negative_fixtures) |fixture| {
        try output.print(allocator,
            \\- negative fixture: {s}
            \\  attempted claim: {s}
            \\  decision: {s}
            \\  reason: {s}
            \\
        , .{ fixture.id, fixture.attempted_claim, fixture.decision, fixture.reason });
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

fn formatJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(&output, allocator, production_telemetry_capture_design_schema);
    try output.print(allocator, ",\n  \"schema_version\": {d}", .{production_telemetry_capture_design_schema_version});
    try output.appendSlice(allocator, ",\n  \"status\": ");
    try appendJsonString(&output, allocator, status);
    try output.appendSlice(allocator, ",\n  \"generated_by\": ");
    try appendJsonString(&output, allocator, generated_by);
    try output.appendSlice(allocator, ",\n  \"source_branch\": ");
    try appendJsonString(&output, allocator, source_branch);
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(&output, allocator, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch\": ");
    try appendJsonString(&output, allocator, next_branch);
    try output.print(allocator, ",\n  \"applied\": {},\n  \"mutation_authority\": ", .{applied});
    try appendJsonString(&output, allocator, mutation_authority);
    try output.print(allocator, ",\n  \"production_telemetry_ingestion\": {},\n  \"live_exporter_enabled\": {}", .{ production_telemetry_ingestion, live_exporter_enabled });

    try output.appendSlice(allocator, ",\n  \"source_contracts\": [\n");
    for (source_contracts, 0..) |contract, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    { \"id\": ");
        try appendJsonString(&output, allocator, contract.id);
        try output.appendSlice(allocator, ", \"schema\": ");
        try appendJsonString(&output, allocator, contract.schema);
        try output.appendSlice(allocator, ", \"producer\": ");
        try appendJsonString(&output, allocator, contract.producer);
        try output.appendSlice(allocator, ", \"evidence_role\": ");
        try appendJsonString(&output, allocator, contract.evidence_role);
        try output.appendSlice(allocator, ", \"authority_boundary\": ");
        try appendJsonString(&output, allocator, contract.authority_boundary);
        try output.appendSlice(allocator, " }");
    }
    try output.appendSlice(allocator, "\n  ],\n  \"capture_surfaces\": [\n");
    for (capture_surfaces, 0..) |surface, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    { \"capture_surface_id\": ");
        try appendJsonString(&output, allocator, surface.id);
        try output.appendSlice(allocator, ", \"source\": ");
        try appendJsonString(&output, allocator, surface.source);
        try output.appendSlice(allocator, ", \"signal\": ");
        try appendJsonString(&output, allocator, surface.signal);
        try output.appendSlice(allocator, ", \"boundary\": ");
        try appendJsonString(&output, allocator, surface.boundary);
        try output.appendSlice(allocator, ", \"agent_guidance\": ");
        try appendJsonString(&output, allocator, surface.agent_guidance);
        try output.appendSlice(allocator, " }");
    }
    try output.appendSlice(allocator, "\n  ],\n  \"telemetry_fields\": [\n");
    for (telemetry_fields, 0..) |field, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    { \"name\": ");
        try appendJsonString(&output, allocator, field.name);
        try output.print(allocator, ", \"required\": {}", .{field.required});
        try output.appendSlice(allocator, ", \"purpose\": ");
        try appendJsonString(&output, allocator, field.purpose);
        try output.appendSlice(allocator, ", \"forbidden_values\": ");
        try appendJsonStringArray(&output, allocator, field.forbidden_values);
        try output.appendSlice(allocator, " }");
    }
    try output.appendSlice(allocator, "\n  ],\n  \"readiness_gates\": [\n");
    for (readiness_gates, 0..) |gate, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    { \"id\": ");
        try appendJsonString(&output, allocator, gate.id);
        try output.appendSlice(allocator, ", \"decision\": ");
        try appendJsonString(&output, allocator, gate.decision);
        try output.appendSlice(allocator, ", \"required_evidence\": ");
        try appendJsonStringArray(&output, allocator, gate.required_evidence);
        try output.appendSlice(allocator, ", \"blocks_until\": ");
        try appendJsonString(&output, allocator, gate.blocks_until);
        try output.appendSlice(allocator, " }");
    }
    try output.appendSlice(allocator, "\n  ],\n  \"negative_fixtures\": [\n");
    for (negative_fixtures, 0..) |fixture, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    { \"id\": ");
        try appendJsonString(&output, allocator, fixture.id);
        try output.appendSlice(allocator, ", \"attempted_claim\": ");
        try appendJsonString(&output, allocator, fixture.attempted_claim);
        try output.appendSlice(allocator, ", \"decision\": ");
        try appendJsonString(&output, allocator, fixture.decision);
        try output.appendSlice(allocator, ", \"reason\": ");
        try appendJsonString(&output, allocator, fixture.reason);
        try output.appendSlice(allocator, " }");
    }
    try output.appendSlice(allocator, "\n  ],\n  \"agent_rules\": [\n");
    for (agent_rules, 0..) |rule, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    { \"id\": ");
        try appendJsonString(&output, allocator, rule.id);
        try output.appendSlice(allocator, ", \"guidance\": ");
        try appendJsonString(&output, allocator, rule.guidance);
        try output.appendSlice(allocator, " }");
    }
    try output.appendSlice(allocator, "\n  ],\n  \"non_goals\": ");
    try appendJsonStringArray(&output, allocator, non_goals);
    try output.appendSlice(allocator, ",\n  \"verification_commands\": ");
    try appendJsonStringArray(&output, allocator, verification_commands);
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
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

fn appendJsonStringArray(output: *std.ArrayList(u8), allocator: std.mem.Allocator, values: []const []const u8) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(output, allocator, value);
    }
    try output.append(allocator, ']');
}

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
