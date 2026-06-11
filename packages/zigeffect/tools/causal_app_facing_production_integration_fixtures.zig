const std = @import("std");

pub const app_facing_production_integration_fixtures_schema =
    "zigeffect.causal.app-facing-production-integration-fixtures.v1";
pub const app_facing_production_integration_fixtures_schema_version: u32 = 1;
pub const source_branch =
    "codex/zigeffect-causal-app-facing-production-integration-fixtures";
pub const recommendation =
    "start-app-facing-production-integration-readiness-review";
pub const next_branch =
    "codex/zigeffect-causal-app-facing-production-integration-readiness-review";

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

const AgentRule = struct {
    id: []const u8,
    guidance: []const u8,
};

const source_contracts: []const SourceContract = &.{
    .{
        .id = "app-runtime",
        .schema = "zigeffect.causal.app-runtime.v1",
        .producer = "CausalAppTrace",
        .evidence_role = "bounded request and background-job trace events plus app semantic refs",
        .authority_boundary = "record-only app runtime evidence; no app mutation persistence or production telemetry transport",
    },
    .{
        .id = "agent-query",
        .schema = "zigeffect.causal.agent-query.v1",
        .producer = "causal-query --agent",
        .evidence_role = "compact trace_data and compare_runs evidence with event ids and next-query hints",
        .authority_boundary = "query output only; no raw payload scraping hidden data extraction or mutation authority",
    },
    .{
        .id = "audit-chain-snapshot-compare",
        .schema = "zigeffect.causal.audit-chain-snapshot-compare.v1",
        .producer = "causal-snapshot -- audit-chain-compare",
        .evidence_role = "retained before-after governance posture evidence for app remediation chains",
        .authority_boundary = "comparison evidence only; not proof of source app config data or production mutation",
    },
    .{
        .id = "nendb-durable-history",
        .schema = "zigeffect.causal.nendb-durable-history.v1",
        .producer = "CausalNendbStorageBackendState.durableHistoryReport and causal-nendb-durable-history-hardening",
        .evidence_role = "NenDB durable-history handoff and retained graph evidence refs",
        .authority_boundary = "NenDB-only durable direction; no production durable write or Cockroach adapter scope",
    },
    .{
        .id = "production-telemetry-capture-fixtures",
        .schema = "zigeffect.causal.production-telemetry-capture-fixtures.v1",
        .producer = "causal-production-telemetry-capture-fixtures",
        .evidence_role = "fixture-only telemetry capture boundaries for redaction sampling retention and transport state",
        .authority_boundary = "fixture source only; no live exporter collector endpoint network send or ingestion",
    },
    .{
        .id = "app-remediation-chain",
        .schema = "zigeffect.causal.app-remediation-audit.v1",
        .producer = "causal-app-remediation-audit causal-app-policy-decision causal-app-human-review causal-app-patch-proposal causal-app-application-readiness causal-app-apply",
        .evidence_role = "non-mutating app issue governance artifacts from audit through guarded application evidence",
        .authority_boundary = "governance evidence only; applied remains false unless separate reviewed application evidence exists",
    },
};

const positive_fixtures: []const FixtureRecord = &.{
    .{
        .fixture_id = "worker-request-redacted-lineage",
        .fixture_kind = .positive,
        .integration_surface_id = "worker-request",
        .source_schema = "zigeffect.causal.app-runtime.v1",
        .app_trace_kind = "request",
        .signal_kind = "app-semantic-lineage",
        .lineage_policy = "method-route-runtime-and-ref-only",
        .redaction_state = "refs-only-redacted",
        .sampling_policy = "bounded-request-trace",
        .retention_policy = "nendb-compatible-retention-ref",
        .access_policy_ref = "artifact-access-control:review-required",
        .durable_history_ref = "none-fixture-local-only",
        .audit_chain_compare_ref = "none",
        .agent_query_ref = "causal-query --agent trace_data data_subject_ref",
        .remediation_chain_ref = "none",
        .telemetry_transport_state = "disabled-fixture",
        .durable_write_state = "disabled-fixture",
        .app_mutation_state = "disabled-fixture",
        .review_gate = "app-redaction-reviewed",
        .blocked_claims = &.{ "raw-request-body-capture", "raw-header-capture", "raw-prompt-capture", "credential-token-capture", "pii-or-tenant-identity-capture", "app-mutation-authority" },
        .sample_attributes = &.{ "method=GET", "route=/api/projects/:id", "runtime=worker", "schema_ref=project.summary.v1", "data_subject_ref=project:ref" },
        .expected_agent_use = "Explain app request lineage from route and semantic refs without raw app payloads.",
        .forbidden_inference = "This fixture does not capture request bodies headers prompts credentials tenant ids raw user ids or PII.",
    },
    .{
        .fixture_id = "background-job-nendb-history-handoff",
        .fixture_kind = .positive,
        .integration_surface_id = "background-job",
        .source_schema = "zigeffect.causal.nendb-durable-history.v1",
        .app_trace_kind = "background_job",
        .signal_kind = "durable-history-handoff",
        .lineage_policy = "job-name-artifact-ref-only",
        .redaction_state = "redacted-before-retention",
        .sampling_policy = "bounded-job-trace",
        .retention_policy = "nendb-compatible-retention-ref",
        .access_policy_ref = "artifact-access-control:redacted-viewer",
        .durable_history_ref = "causal-nendb-durable-history-hardening:durable-history-report",
        .audit_chain_compare_ref = "none",
        .agent_query_ref = "causal-query --agent summarize_run",
        .remediation_chain_ref = "none",
        .telemetry_transport_state = "disabled-fixture",
        .durable_write_state = "disabled-fixture",
        .app_mutation_state = "disabled-fixture",
        .review_gate = "nendb-history-reviewed",
        .blocked_claims = &.{ "production-durable-write", "non-nendb-durable-storage", "cockroach-adapter-work", "live-production-telemetry-ingestion" },
        .sample_attributes = &.{ "job_name=sync-project-rollup", "runtime=worker-queue", "durable_history_ref=nendb:fixture", "production_write=false" },
        .expected_agent_use = "Model how background job evidence hands off to NenDB durable history by reference.",
        .forbidden_inference = "This fixture does not write production durable storage or introduce Cockroach scope.",
    },
    .{
        .fixture_id = "agent-query-app-trace-data",
        .fixture_kind = .positive,
        .integration_surface_id = "agent-query",
        .source_schema = "zigeffect.causal.agent-query.v1",
        .app_trace_kind = "request",
        .signal_kind = "trace_data",
        .lineage_policy = "bounded-query-output",
        .redaction_state = "query-redacted",
        .sampling_policy = "query-bounded",
        .retention_policy = "nendb-compatible-retention-ref",
        .access_policy_ref = "artifact-access-control:agent-readable-redacted",
        .durable_history_ref = "optional-nendb-history-ref",
        .audit_chain_compare_ref = "none",
        .agent_query_ref = "causal-query --agent trace_data data_subject_ref",
        .remediation_chain_ref = "none",
        .telemetry_transport_state = "disabled-fixture",
        .durable_write_state = "disabled-fixture",
        .app_mutation_state = "disabled-fixture",
        .review_gate = "agent-query-redaction-reviewed",
        .blocked_claims = &.{ "agent-query-raw-payload-scrape", "raw-request-body-capture", "pii-or-tenant-identity-capture", "app-mutation-authority" },
        .sample_attributes = &.{ "query=trace_data", "reads=bounded", "writes=bounded", "next_query=explain_event" },
        .expected_agent_use = "Cite query ids event ids and next-query hints when explaining app data lineage.",
        .forbidden_inference = "Agent query output is not permission to scrape raw payloads or infer hidden app data.",
    },
    .{
        .fixture_id = "audit-chain-before-after-app-review",
        .fixture_kind = .positive,
        .integration_surface_id = "audit-chain-compare",
        .source_schema = "zigeffect.causal.audit-chain-snapshot-compare.v1",
        .app_trace_kind = "governance",
        .signal_kind = "before-after-review",
        .lineage_policy = "retained-audit-chain-refs",
        .redaction_state = "review-evidence-redacted",
        .sampling_policy = "snapshot-manifest-bounded",
        .retention_policy = "nendb-compatible-retention-ref",
        .access_policy_ref = "artifact-access-control:review-required",
        .durable_history_ref = "optional-nendb-history-ref",
        .audit_chain_compare_ref = "causal-snapshot audit-chain-compare before after",
        .agent_query_ref = "causal-query --agent list_findings",
        .remediation_chain_ref = "app-remediation-chain:reviewed",
        .telemetry_transport_state = "disabled-fixture",
        .durable_write_state = "disabled-fixture",
        .app_mutation_state = "disabled-fixture",
        .review_gate = "audit-chain-compare-reviewed",
        .blocked_claims = &.{ "audit-chain-compare-as-mutation-proof", "app-mutation-authority", "production-durable-write" },
        .sample_attributes = &.{ "left_posture=pending", "right_posture=reviewed", "applied=false", "before_after_evidence=retained-ref" },
        .expected_agent_use = "Compare governance posture and evidence-classification deltas before recommending next review steps.",
        .forbidden_inference = "Audit-chain comparison does not prove source app config data or production mutation.",
    },
    .{
        .fixture_id = "app-remediation-governance-bridge",
        .fixture_kind = .positive,
        .integration_surface_id = "app-remediation",
        .source_schema = "zigeffect.causal.app-remediation-audit.v1",
        .app_trace_kind = "governance",
        .signal_kind = "remediation-chain",
        .lineage_policy = "incident-to-policy-to-proposal-refs",
        .redaction_state = "incident-refs-redacted",
        .sampling_policy = "bounded-incident-list",
        .retention_policy = "nendb-compatible-retention-ref",
        .access_policy_ref = "artifact-access-control:review-required",
        .durable_history_ref = "optional-nendb-history-ref",
        .audit_chain_compare_ref = "optional-audit-chain-compare-ref",
        .agent_query_ref = "causal-query --agent trace_cause incident_event_id",
        .remediation_chain_ref = "audit policy human-review proposal readiness application",
        .telemetry_transport_state = "disabled-fixture",
        .durable_write_state = "disabled-fixture",
        .app_mutation_state = "disabled-fixture",
        .review_gate = "app-remediation-governance-reviewed",
        .blocked_claims = &.{ "app-mutation-authority", "audit-chain-compare-as-mutation-proof", "ci-gate-enforcement" },
        .sample_attributes = &.{ "approval_status=pending", "policy=source-only", "proposal=review-required", "applied=false" },
        .expected_agent_use = "Route app incident evidence through policy review and patch proposal artifacts before any application claim.",
        .forbidden_inference = "A remediation proposal is not permission to edit source config data deployment state or rollback plans.",
    },
    .{
        .fixture_id = "production-telemetry-fixture-boundary",
        .fixture_kind = .positive,
        .integration_surface_id = "production-telemetry-boundary",
        .source_schema = "zigeffect.causal.production-telemetry-capture-fixtures.v1",
        .app_trace_kind = "boundary",
        .signal_kind = "telemetry-fixture-ref",
        .lineage_policy = "fixture-source-contract-only",
        .redaction_state = "redacted-before-export",
        .sampling_policy = "sampled-in-only",
        .retention_policy = "nendb-compatible-retention-ref",
        .access_policy_ref = "artifact-access-control:redacted-viewer",
        .durable_history_ref = "nendb-compatible-retention-ref",
        .audit_chain_compare_ref = "none",
        .agent_query_ref = "none",
        .remediation_chain_ref = "none",
        .telemetry_transport_state = "disabled-fixture",
        .durable_write_state = "disabled-fixture",
        .app_mutation_state = "disabled-fixture",
        .review_gate = "telemetry-fixture-boundary-reviewed",
        .blocked_claims = &.{ "live-production-telemetry-ingestion", "live-exporter-enabled", "production-durable-write", "ci-gate-enforcement" },
        .sample_attributes = &.{ "source_fixture=production-telemetry-capture-fixtures", "transport=disabled", "collector_endpoint=none" },
        .expected_agent_use = "Reuse telemetry fixture boundaries when planning future app production integration readiness review.",
        .forbidden_inference = "This fixture does not enable OTLP collectors network sends live ingestion or CI telemetry gates.",
    },
};

const negative_fixtures: []const NegativeFixture = &.{
    .{
        .id = "raw-request-body-capture",
        .attempted_claim = "App production integration fixtures may capture raw request bodies.",
        .decision = "rejected",
        .reason = "request bodies may contain user content secrets or regulated data",
        .violated_field_or_gate = "redaction_state",
        .safe_alternative = "record route method runtime schema_ref and data_subject_ref only",
    },
    .{
        .id = "raw-header-capture",
        .attempted_claim = "Fixtures may capture raw HTTP headers for app debugging.",
        .decision = "rejected",
        .reason = "headers can contain authorization cookies credentials and tracking identifiers",
        .violated_field_or_gate = "app-redaction-reviewed",
        .safe_alternative = "record header policy refs without header values",
    },
    .{
        .id = "raw-prompt-capture",
        .attempted_claim = "Fixtures may capture raw prompt content.",
        .decision = "rejected",
        .reason = "prompt content must remain outside app production integration fixtures",
        .violated_field_or_gate = "redaction_state",
        .safe_alternative = "record prompt policy refs or redacted artifact ids only",
    },
    .{
        .id = "credential-token-capture",
        .attempted_claim = "Fixtures may include credentials or tokens for debugging.",
        .decision = "rejected",
        .reason = "secret capture is forbidden before and after redaction review",
        .violated_field_or_gate = "credential-redaction",
        .safe_alternative = "record credential_redacted=true style attributes only",
    },
    .{
        .id = "pii-or-tenant-identity-capture",
        .attempted_claim = "Fixtures may include tenant ids raw user ids or PII.",
        .decision = "rejected",
        .reason = "app integration fixtures must use stable redacted refs instead of direct identity values",
        .violated_field_or_gate = "redaction-ref-only-lineage",
        .safe_alternative = "record data_subject_ref domain_entity_ref and schema_ref values that are already redacted",
    },
    .{
        .id = "live-production-telemetry-ingestion",
        .attempted_claim = "This branch ingests live production telemetry.",
        .decision = "rejected",
        .reason = "production_telemetry_ingestion remains false",
        .violated_field_or_gate = "production_telemetry_ingestion",
        .safe_alternative = "use deterministic fixture records for readiness planning",
    },
    .{
        .id = "live-exporter-enabled",
        .attempted_claim = "This branch enables a live exporter or collector endpoint.",
        .decision = "rejected",
        .reason = "live_exporter_enabled remains false and telemetry transport state is disabled-fixture",
        .violated_field_or_gate = "telemetry_transport_state",
        .safe_alternative = "reference production telemetry fixture boundaries only",
    },
    .{
        .id = "production-durable-write",
        .attempted_claim = "This branch writes app causal artifacts to production durable storage.",
        .decision = "rejected",
        .reason = "durable_write_enabled remains false",
        .violated_field_or_gate = "durable_write_state",
        .safe_alternative = "record durable_history_ref values and route writes through future review",
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
        .attempted_claim = "Cockroach adapter work is part of app production integration fixtures.",
        .decision = "rejected",
        .reason = "Cockroach adapter work is explicitly out of scope for this roadmap stage",
        .violated_field_or_gate = "nendb-only-durable-direction",
        .safe_alternative = "use NenDB-compatible retention refs only",
    },
    .{
        .id = "app-mutation-authority",
        .attempted_claim = "Agents may mutate app source config migration data deployment rollout or rollback state.",
        .decision = "rejected",
        .reason = "mutation_authority remains none and app_mutation_enabled remains false",
        .violated_field_or_gate = "mutation_authority",
        .safe_alternative = "route proposals through app readiness and reviewed application boundaries",
    },
    .{
        .id = "audit-chain-compare-as-mutation-proof",
        .attempted_claim = "Audit-chain comparison proves an app change was applied.",
        .decision = "rejected",
        .reason = "audit-chain comparison reports governance deltas but not source or app mutation",
        .violated_field_or_gate = "audit_chain_compare_ref",
        .safe_alternative = "require separate reviewed application evidence before claiming applied=true",
    },
    .{
        .id = "agent-query-raw-payload-scrape",
        .attempted_claim = "Agent query output permits scraping hidden app payloads.",
        .decision = "rejected",
        .reason = "agent queries expose bounded evidence slices and next-query hints only",
        .violated_field_or_gate = "agent_query_ref",
        .safe_alternative = "cite event ids query ids and redacted refs",
    },
    .{
        .id = "ci-gate-enforcement",
        .attempted_claim = "CI may enforce app production integration gates from these fixtures.",
        .decision = "rejected",
        .reason = "ci_gate_enabled remains false",
        .violated_field_or_gate = "ci_gate_enabled",
        .safe_alternative = "emit validation evidence without failing CI on app production thresholds",
    },
    .{
        .id = "react-or-alternate-renderer",
        .attempted_claim = "Workbench production app views may switch to React or another renderer.",
        .decision = "rejected",
        .reason = "workbench direction remains SolidJS inside webui-dev zig-webui",
        .violated_field_or_gate = "solid-webui-direction",
        .safe_alternative = "preserve SolidJS webui fixture direction",
    },
};

const validation_checks: []const ValidationCheck = &.{
    .{
        .id = "source-contract-coverage",
        .status = "passed",
        .evidence = &.{ "app-runtime", "agent-query", "audit-chain-snapshot-compare", "nendb-durable-history", "production-telemetry-capture-fixtures", "app-remediation-chain" },
        .blocks_claim = "app integration fixture source contracts can be inferred from missing evidence",
    },
    .{
        .id = "positive-fixture-surface-coverage",
        .status = "passed",
        .evidence = &.{ "worker-request", "background-job", "agent-query", "audit-chain-compare", "app-remediation", "production-telemetry-boundary" },
        .blocks_claim = "app integration fixture catalog misses a required production-facing surface",
    },
    .{
        .id = "redaction-ref-only-lineage",
        .status = "passed",
        .evidence = &.{ "refs-only-redacted", "query-redacted", "review-evidence-redacted", "incident-refs-redacted" },
        .blocks_claim = "fixtures authorize raw app payload identity or secret capture",
    },
    .{
        .id = "blocked-claim-coverage",
        .status = "passed",
        .evidence = &.{"15 negative fixtures reject raw payload live telemetry durable write mutation CI Cockroach and renderer drift claims"},
        .blocks_claim = "unsafe app production integration claims can pass by omission",
    },
    .{
        .id = "forbidden-value-absence",
        .status = "passed",
        .evidence = &.{"positive fixtures use disabled-fixture none nendb-compatible-retention-ref and redacted refs only"},
        .blocks_claim = "positive fixtures authorize live exporter durable writes app mutation or raw values",
    },
    .{
        .id = "nendb-only-durable-direction",
        .status = "passed",
        .evidence = &.{ "nendb-compatible-retention-ref", "causal-nendb-durable-history-hardening:durable-history-report" },
        .blocks_claim = "non-NenDB or Cockroach durable adapter work is in scope",
    },
    .{
        .id = "no-live-authority",
        .status = "passed",
        .evidence = &.{"applied false mutation none live telemetry false exporter false durable write false app mutation false ci gate false"},
        .blocks_claim = "fixtures grant live operational or mutation authority",
    },
    .{
        .id = "next-branch-handoff",
        .status = "passed",
        .evidence = &.{"recommendation start-app-facing-production-integration-readiness-review"},
        .blocks_claim = "fixture branch can proceed directly to live integration without readiness review",
    },
};

const agent_rules: []const AgentRule = &.{
    .{
        .id = "cite-fixture-and-source-contract",
        .guidance = "Use fixture ids and source contract ids when explaining app-facing production integration evidence.",
    },
    .{
        .id = "prefer-query-evidence",
        .guidance = "Use agent-query refs and event ids instead of scraping raw app artifacts.",
    },
    .{
        .id = "separate-fixtures-from-live-state",
        .guidance = "Treat this catalog as deterministic fixture evidence, not proof of production telemetry or applied app changes.",
    },
    .{
        .id = "route-readiness-review",
        .guidance = "Send future app-facing production integration work through the readiness-review branch before implementation authority.",
    },
};

const non_goals: []const []const u8 = &.{
    "live production telemetry ingestion",
    "OTLP serialization SDK setup collector delivery or network calls",
    "production credentials endpoints hostnames raw user ids tenant ids secrets headers request bodies prompts or raw payload capture",
    "durable production writes",
    "non-NenDB durable adapter work",
    "Cockroach adapter work",
    "app source config migration data deployment rollout rollback or operational mutation",
    "CI enforcement gates",
    "production workbench hosting",
    "React or alternate renderer work",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig test tools/causal_app_facing_production_integration_fixtures.zig",
    "zig build causal-app-facing-production-integration-fixtures",
    "zig build causal-app-facing-production-integration-fixtures -- --format json",
    "zig build causal-app-facing-production-integration-fixtures -- emit worker-request-redacted-lineage --format json",
    "zig build causal-app-facing-production-integration-fixtures -- validate --format json",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
    "cd ../..",
    "bun run check",
    "bun run zig:test",
    "git diff --check",
};

fn sourceContracts() []const SourceContract {
    return source_contracts;
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

fn kindName(kind: FixtureKind) []const u8 {
    return switch (kind) {
        .positive => "positive",
        .negative => "negative",
    };
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
        try appendValidationCheckText(allocator, &output, check);
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
        try output.appendSlice(allocator, "    ");
        try appendSourceContractJsonObject(allocator, &output, contract);
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
        try appendValidationCheckText(allocator, &output, check);
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
        \\app mutation enabled: {}
        \\ci gate enabled: {}
        \\
        \\
    , .{
        app_facing_production_integration_fixtures_schema,
        app_facing_production_integration_fixtures_schema_version,
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
        app_mutation_enabled,
        ci_gate_enabled,
    });
}

fn appendHeaderJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, output, app_facing_production_integration_fixtures_schema);
    try output.print(allocator, ",\n  \"schema_version\": {d}", .{app_facing_production_integration_fixtures_schema_version});
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
        \\  "app_mutation_enabled": {},
        \\  "ci_gate_enabled": {}
    , .{
        production_telemetry_ingestion,
        live_exporter_enabled,
        durable_write_enabled,
        app_mutation_enabled,
        ci_gate_enabled,
    });
}

fn appendSourceContractJsonObject(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    contract: SourceContract,
) !void {
    try output.appendSlice(allocator, "{ \"id\": ");
    try appendJsonString(allocator, output, contract.id);
    try output.appendSlice(allocator, ", \"schema\": ");
    try appendJsonString(allocator, output, contract.schema);
    try output.appendSlice(allocator, ", \"producer\": ");
    try appendJsonString(allocator, output, contract.producer);
    try output.appendSlice(allocator, ", \"evidence_role\": ");
    try appendJsonString(allocator, output, contract.evidence_role);
    try output.appendSlice(allocator, ", \"authority_boundary\": ");
    try appendJsonString(allocator, output, contract.authority_boundary);
    try output.appendSlice(allocator, " }");
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
        \\  integration surface id: {s}
        \\  source schema: {s}
        \\  app trace kind: {s}
        \\  signal kind: {s}
        \\  lineage policy: {s}
        \\  redaction state: {s}
        \\  sampling policy: {s}
        \\  retention policy: {s}
        \\  access policy ref: {s}
        \\  durable history ref: {s}
        \\  audit chain compare ref: {s}
        \\  agent query ref: {s}
        \\  remediation chain ref: {s}
        \\  telemetry transport state: {s}
        \\  durable write state: {s}
        \\  app mutation state: {s}
        \\  review gate: {s}
        \\  blocked claims:
        \\
    , .{
        label,
        fixture.fixture_id,
        kindName(fixture.fixture_kind),
        fixture.integration_surface_id,
        fixture.source_schema,
        fixture.app_trace_kind,
        fixture.signal_kind,
        fixture.lineage_policy,
        fixture.redaction_state,
        fixture.sampling_policy,
        fixture.retention_policy,
        fixture.access_policy_ref,
        fixture.durable_history_ref,
        fixture.audit_chain_compare_ref,
        fixture.agent_query_ref,
        fixture.remediation_chain_ref,
        fixture.telemetry_transport_state,
        fixture.durable_write_state,
        fixture.app_mutation_state,
        fixture.review_gate,
    });
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
    try output.appendSlice(allocator, ", \"integration_surface_id\": ");
    try appendJsonString(allocator, output, fixture.integration_surface_id);
    try output.appendSlice(allocator, ", \"source_schema\": ");
    try appendJsonString(allocator, output, fixture.source_schema);
    try output.appendSlice(allocator, ", \"app_trace_kind\": ");
    try appendJsonString(allocator, output, fixture.app_trace_kind);
    try output.appendSlice(allocator, ", \"signal_kind\": ");
    try appendJsonString(allocator, output, fixture.signal_kind);
    try output.appendSlice(allocator, ", \"lineage_policy\": ");
    try appendJsonString(allocator, output, fixture.lineage_policy);
    try output.appendSlice(allocator, ", \"redaction_state\": ");
    try appendJsonString(allocator, output, fixture.redaction_state);
    try output.appendSlice(allocator, ", \"sampling_policy\": ");
    try appendJsonString(allocator, output, fixture.sampling_policy);
    try output.appendSlice(allocator, ", \"retention_policy\": ");
    try appendJsonString(allocator, output, fixture.retention_policy);
    try output.appendSlice(allocator, ", \"access_policy_ref\": ");
    try appendJsonString(allocator, output, fixture.access_policy_ref);
    try output.appendSlice(allocator, ", \"durable_history_ref\": ");
    try appendJsonString(allocator, output, fixture.durable_history_ref);
    try output.appendSlice(allocator, ", \"audit_chain_compare_ref\": ");
    try appendJsonString(allocator, output, fixture.audit_chain_compare_ref);
    try output.appendSlice(allocator, ", \"agent_query_ref\": ");
    try appendJsonString(allocator, output, fixture.agent_query_ref);
    try output.appendSlice(allocator, ", \"remediation_chain_ref\": ");
    try appendJsonString(allocator, output, fixture.remediation_chain_ref);
    try output.appendSlice(allocator, ", \"telemetry_transport_state\": ");
    try appendJsonString(allocator, output, fixture.telemetry_transport_state);
    try output.appendSlice(allocator, ", \"durable_write_state\": ");
    try appendJsonString(allocator, output, fixture.durable_write_state);
    try output.appendSlice(allocator, ", \"app_mutation_state\": ");
    try appendJsonString(allocator, output, fixture.app_mutation_state);
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

fn appendValidationCheckText(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    check: ValidationCheck,
) !void {
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
    std.debug.print("{s}", .{output});
}

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
