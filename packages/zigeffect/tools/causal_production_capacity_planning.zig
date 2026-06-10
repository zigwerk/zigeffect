const std = @import("std");

pub const production_capacity_planning_schema = "zigeffect.causal.production-capacity-planning.v1";
pub const production_capacity_planning_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-capacity-planning";
pub const next_branch = "codex/zigeffect-causal-production-hardening-completion-audit";

const OutputFormat = enum { text, json };

const generated_by = "causal-production-capacity-planning";
const mode = "local-record";
const mutation_authority = "none";

const SourceContract = struct {
    id: []const u8,
    schema: []const u8,
    producer: []const u8,
    evidence_role: []const u8,
    required_for: []const []const u8,
    missing_evidence_action: []const u8,
    authority_boundary: []const u8,
};

const CapacityDomain = struct {
    id: []const u8,
    category: []const u8,
    planning_question: []const u8,
    required_evidence: []const []const u8,
    model_expression: []const u8,
    review_status: []const u8,
    agent_guidance: []const u8,
};

const StorageGrowthAssumption = struct {
    id: []const u8,
    known_value: []const u8,
    source: []const u8,
    missing_evidence_action: []const u8,
};

const LoadTestFixture = struct {
    scenario_id: []const u8,
    target_capacity_question: []const u8,
    fixture_inputs: []const []const u8,
    evidence_required_before_execution: []const []const u8,
    blocking_missing_evidence: []const u8,
    authority_boundary: []const u8,
};

const ConcurrencyAssumption = struct {
    id: []const u8,
    surface: []const u8,
    assumption: []const u8,
    required_evidence: []const []const u8,
    not_a_claim: []const u8,
};

const ReadinessGate = struct {
    id: []const u8,
    decision: []const u8,
    required_evidence: []const []const u8,
    missing_evidence_action: []const u8,
};

const NegativeCapacityFixture = struct {
    id: []const u8,
    attempted_claim: []const u8,
    decision: []const u8,
    reason: []const u8,
};

const AgentGuidance = struct {
    id: []const u8,
    guidance: []const u8,
};

fn usage() []const u8 {
    return
    \\usage:
    \\  zig build causal-production-capacity-planning
    \\  zig build causal-production-capacity-planning -- --format text
    \\  zig build causal-production-capacity-planning -- --format json
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

const source_contracts: []const SourceContract = &.{
    .{
        .id = "production-artifact-aggregation",
        .schema = "zigeffect.causal.production-artifact-aggregation.v1",
        .producer = "causal-production-artifact-aggregation",
        .evidence_role = "bundle provenance source classes privacy review and source aggregation boundaries",
        .required_for = &.{ "retained-artifact-storage", "load-test fixture scoping", "capacity readiness review" },
        .missing_evidence_action = "block storage growth estimates and request reviewed aggregation bundle provenance",
        .authority_boundary = "record-only source evidence; does not aggregate live production artifacts",
    },
    .{
        .id = "durable-production-retention",
        .schema = "zigeffect.causal.durable-production-retention.v1",
        .producer = "causal-durable-production-retention",
        .evidence_role = "NenDB retention TTL compaction backup and recovery policy",
        .required_for = &.{ "storage growth assumptions", "retention compaction assumptions", "backup and recovery sizing review" },
        .missing_evidence_action = "block retained storage claims and require reviewed NenDB retention policy evidence",
        .authority_boundary = "NenDB adapter planning only; does not write durable data",
    },
    .{
        .id = "wall-clock-benchmark-baselines",
        .schema = "zigeffect.causal.wall-clock-benchmark-baselines.v1",
        .producer = "causal-wall-clock-benchmark-baselines",
        .evidence_role = "scenario families calibration policy environment metadata and advisory review gates",
        .required_for = &.{ "benchmark observation coverage", "load-test fixture plan", "future benchmark harness input shape" },
        .missing_evidence_action = "block capacity claims from timing evidence and request reviewed compatible baseline observations",
        .authority_boundary = "advisory wall-clock records only; does not execute load tests",
    },
    .{
        .id = "live-dashboard-stream",
        .schema = "zigeffect.causal.live-dashboard-stream.v1",
        .producer = "causal-live-dashboard-streaming-workbench",
        .evidence_role = "bounded dashboard frame window read-only workbench transport and truncation policy",
        .required_for = &.{ "dashboard stream window", "workbench concurrency assumptions", "visual graph handoff" },
        .missing_evidence_action = "block dashboard concurrency claims and request reviewed bounded stream fixtures",
        .authority_boundary = "local workbench evidence only; does not host or stream production dashboards",
    },
    .{
        .id = "agent-query",
        .schema = "zigeffect.causal.agent-query.v1",
        .producer = "causal-query --agent",
        .evidence_role = "bounded query slices evidence ids redaction state truncation state and next-query hints",
        .required_for = &.{ "agent query bounds", "agent feedback volume", "capacity investigation workflow" },
        .missing_evidence_action = "block agent query capacity assumptions and request bounded query fixtures",
        .authority_boundary = "read-only query contract; does not mutate traces or registries",
    },
    .{
        .id = "human-agent-feedback-loop",
        .schema = "zigeffect.causal.human-agent-feedback-loop.v1",
        .producer = "causal-human-agent-feedback-loop",
        .evidence_role = "workbench selection agent query before/after comparison regression cluster and proposal handoff records",
        .required_for = &.{ "feedback-loop queue assumptions", "agent workflow concurrency", "completion audit handoff" },
        .missing_evidence_action = "block self-improvement volume claims and request feedback-loop record evidence",
        .authority_boundary = "feedback records only; does not apply proposals or grant mutation authority",
    },
    .{
        .id = "alerting-integrations",
        .schema = "zigeffect.causal.alerting-integrations.v1",
        .producer = "causal-alerting-integrations",
        .evidence_role = "record-only alert preview severity routing escalation gate and integration handoff fixtures",
        .required_for = &.{ "incident handoff volume", "alert review queues", "external integration capacity assumptions" },
        .missing_evidence_action = "block incident volume claims and require reviewed alert preview evidence",
        .authority_boundary = "preview records only; no messages tickets SIEM events or pages are sent",
    },
    .{
        .id = "rollout-automation-guardrails",
        .schema = "zigeffect.causal.rollout-automation-guardrails.v1",
        .producer = "causal-rollout-automation-guardrails",
        .evidence_role = "canary gradual rollout circuit-breaker rollback readiness and negative automation fixtures",
        .required_for = &.{ "rollout handoff volume", "guardrail review queue assumptions", "completion audit readiness" },
        .missing_evidence_action = "block rollout capacity assumptions and request reviewed guardrail evidence",
        .authority_boundary = "rollout evidence only; does not execute deploy rollback or traffic mutation",
    },
};

const capacity_domains: []const CapacityDomain = &.{
    .{
        .id = "retained-artifact-storage",
        .category = "storage",
        .planning_question = "How many reviewed aggregated causal bundles can be retained inside the NenDB retention window?",
        .required_evidence = &.{ "production-artifact-aggregation", "durable-production-retention", "reviewed bundle count observations" },
        .model_expression = "retained_bytes = bundles_per_day * retention_days * average_bytes_per_bundle * backup_multiplier",
        .review_status = "formula-only-needs-observations",
        .agent_guidance = "Do not fill bundles_per_day or average_bytes_per_bundle without reviewed aggregation evidence.",
    },
    .{
        .id = "nendb-retention-compaction",
        .category = "storage",
        .planning_question = "When should retained NenDB graph history compact while preserving queryable evidence?",
        .required_evidence = &.{ "durable-production-retention", "nendb-retention-report", "compaction fixture review" },
        .model_expression = "post_compaction_events = min(current_events, compact_to_events) after compaction_trigger_events",
        .review_status = "policy-known-needs-production-observations",
        .agent_guidance = "Use known retention constants as policy, not proof of production durability.",
    },
    .{
        .id = "benchmark-observation-coverage",
        .category = "benchmark",
        .planning_question = "Which wall-clock scenario families need reviewed observations before capacity planning can become operational?",
        .required_evidence = &.{ "wall-clock-benchmark-baselines", "environment metadata", "sample count and artifact refs" },
        .model_expression = "coverage = reviewed_scenario_families / required_scenario_families",
        .review_status = "needs-reviewed-baseline-observations",
        .agent_guidance = "Coverage can be complete only when all eight scenario families have reviewed compatible records.",
    },
    .{
        .id = "request-trace-volume",
        .category = "runtime",
        .planning_question = "What event volume is expected for bounded app request causal traces?",
        .required_evidence = &.{ "app-request-trace baseline", "production-artifact-aggregation", "runtime event bounds" },
        .model_expression = "request_trace_events = requests_per_second * average_events_per_request * retention_window_seconds",
        .review_status = "needs-traffic-and-trace-observations",
        .agent_guidance = "Never infer production requests per second from local request fixtures.",
    },
    .{
        .id = "background-job-trace-volume",
        .category = "runtime",
        .planning_question = "What retained volume is expected for larger background job traces with dropped-event metadata?",
        .required_evidence = &.{ "background-job-trace baseline", "dropped-event metadata", "job frequency observations" },
        .model_expression = "job_trace_events = jobs_per_hour * average_events_per_job * retention_window_hours",
        .review_status = "needs-job-observations",
        .agent_guidance = "Separate job trace volume from request trace volume and cite dropped-event state.",
    },
    .{
        .id = "artifact-formatting-and-query",
        .category = "artifact",
        .planning_question = "What formatter and bounded query cost should agents expect when reading retained artifacts?",
        .required_evidence = &.{ "causal-artifact-formatting baseline", "causal-query-agent-slices baseline", "agent-query contract" },
        .model_expression = "query_cpu_budget = query_family_count * median_ms_per_query_family",
        .review_status = "needs-reviewed-formatting-and-query-baselines",
        .agent_guidance = "Keep formatting cost separate from query slice cost and never compare incompatible schema versions.",
    },
    .{
        .id = "dashboard-stream-window",
        .category = "workbench",
        .planning_question = "How large can bounded dashboard frame windows be before the local SolidJS workbench needs pagination or sampling?",
        .required_evidence = &.{ "live-dashboard-stream", "bounded stream fixture", "workbench build and UI tests" },
        .model_expression = "dashboard_memory = frames_in_window * average_frame_bytes",
        .review_status = "local-fixture-only",
        .agent_guidance = "Treat the dashboard as a local bounded viewer until production dashboard hosting exists.",
    },
    .{
        .id = "visual-graph-rendering",
        .category = "workbench",
        .planning_question = "What node and edge fixture sizes should the visual graph adapter test before production-scale graph claims?",
        .required_evidence = &.{ "workbench graph visual debugging", "node edge fixture records", "browser canvas verification" },
        .model_expression = "graph_render_cost = nodes * node_cost + edges * edge_cost + layout_overhead",
        .review_status = "needs-node-edge-fixtures",
        .agent_guidance = "Do not claim graph capacity without explicit node edge counts and visual verification.",
    },
    .{
        .id = "agent-query-and-feedback",
        .category = "agent-workflow",
        .planning_question = "How many bounded query and feedback-loop records can a development agent inspect per investigation?",
        .required_evidence = &.{ "agent-query", "human-agent-feedback-loop", "before-after comparison fixtures" },
        .model_expression = "investigation_records = query_slices + feedback_records + comparison_findings",
        .review_status = "needs-feedback-loop-observations",
        .agent_guidance = "Prefer next-query hints and bounded slices over broad artifact dumps.",
    },
    .{
        .id = "alerting-rollout-handoff-volume",
        .category = "operations",
        .planning_question = "What preview record volume can alerting and rollout guardrail handoffs generate before external systems are integrated?",
        .required_evidence = &.{ "alerting-integrations", "rollout-automation-guardrails", "reviewed handoff fixtures" },
        .model_expression = "handoff_records = alert_previews + canary_evidence + circuit_breaker_decisions + rollback_readiness_records",
        .review_status = "preview-only-needs-production-integration-review",
        .agent_guidance = "Preview records are useful for review queues but not incident or rollout production traffic estimates.",
    },
};

const storage_growth_assumptions: []const StorageGrowthAssumption = &.{
    .{ .id = "retention-days", .known_value = "14", .source = "durable-production-retention NenDB policy", .missing_evidence_action = "block retention-window estimates when policy evidence is absent" },
    .{ .id = "max-events-per-bundle", .known_value = "4096", .source = "durable-production-retention NenDB policy", .missing_evidence_action = "block bundle event estimates when retention constants are absent" },
    .{ .id = "compaction-trigger-events", .known_value = "2048", .source = "durable-production-retention NenDB policy", .missing_evidence_action = "block compaction readiness claims when trigger evidence is absent" },
    .{ .id = "compact-to-events", .known_value = "1024", .source = "durable-production-retention NenDB policy", .missing_evidence_action = "block post-compaction estimates when compact-to evidence is absent" },
    .{ .id = "backup-required", .known_value = "true", .source = "durable-production-retention backup policy", .missing_evidence_action = "block production readiness when backup evidence is absent" },
    .{ .id = "recovery-required", .known_value = "true", .source = "durable-production-retention recovery policy", .missing_evidence_action = "block production readiness when recovery evidence is absent" },
    .{ .id = "retained-bundles-per-day", .known_value = "unknown-until-reviewed-observation", .source = "production-artifact-aggregation", .missing_evidence_action = "request reviewed bundle count observations" },
    .{ .id = "average-events-per-bundle", .known_value = "unknown-until-reviewed-observation", .source = "production-artifact-aggregation and NenDB retention reports", .missing_evidence_action = "request reviewed event count observations" },
    .{ .id = "bytes-per-event-estimate", .known_value = "unknown-until-reviewed-observation", .source = "future benchmark observation harness", .missing_evidence_action = "request reviewed serialized artifact byte observations" },
    .{ .id = "backup-multiplier", .known_value = "requires-reviewed-policy", .source = "future production backup policy", .missing_evidence_action = "request reviewed backup copy and compression policy" },
    .{ .id = "compaction-overhead-factor", .known_value = "requires-reviewed-policy", .source = "future NenDB compaction observation", .missing_evidence_action = "request reviewed compaction overhead observation" },
};

const load_test_fixture_plan: []const LoadTestFixture = &.{
    .{
        .scenario_id = "app-request-trace",
        .target_capacity_question = "bounded request trace recording overhead under representative request concurrency",
        .fixture_inputs = &.{ "request event count fixture", "redaction state", "semantic refs", "retained-event limit" },
        .evidence_required_before_execution = &.{ "reviewed aggregation provenance", "request trace baseline", "runtime event bounds" },
        .blocking_missing_evidence = "missing reviewed request trace baseline or aggregation provenance",
        .authority_boundary = "fixture plan only; no request load is generated",
    },
    .{
        .scenario_id = "background-job-trace",
        .target_capacity_question = "bounded background job trace overhead and dropped-event reporting",
        .fixture_inputs = &.{ "job event count fixture", "dropped-event metadata", "resource ownership refs" },
        .evidence_required_before_execution = &.{ "reviewed job baseline", "retention policy", "dropped-event contract" },
        .blocking_missing_evidence = "missing reviewed background job baseline",
        .authority_boundary = "fixture plan only; no job runner is invoked",
    },
    .{
        .scenario_id = "causal-artifact-formatting",
        .target_capacity_question = "text JSON and DOT formatting overhead for representative retained artifacts",
        .fixture_inputs = &.{ "artifact byte size", "event count", "schema version", "redaction metadata" },
        .evidence_required_before_execution = &.{ "reviewed formatting baseline", "schema governance", "aggregation bundle fixture" },
        .blocking_missing_evidence = "missing compatible artifact formatting baseline",
        .authority_boundary = "fixture plan only; no production artifacts are read",
    },
    .{
        .scenario_id = "causal-query-agent-slices",
        .target_capacity_question = "bounded agent query response cost by query family",
        .fixture_inputs = &.{ "query family", "response bound", "artifact refs", "next-query hints" },
        .evidence_required_before_execution = &.{ "agent-query contract", "reviewed query baseline", "redaction review" },
        .blocking_missing_evidence = "missing bounded query fixture or reviewed baseline",
        .authority_boundary = "fixture plan only; no agent automation is run",
    },
    .{
        .scenario_id = "causal-compare-before-after",
        .target_capacity_question = "before after comparison overhead and finding volume for development loops",
        .fixture_inputs = &.{ "baseline artifact", "after artifact", "finding count", "source commit refs" },
        .evidence_required_before_execution = &.{ "reviewed compare baseline", "feedback-loop comparison workflow", "artifact refs" },
        .blocking_missing_evidence = "missing paired artifact fixtures",
        .authority_boundary = "fixture plan only; no remediation proposal is applied",
    },
    .{
        .scenario_id = "causal-dev-loop-package-tests",
        .target_capacity_question = "package test causal artifact capture overhead in the development loop",
        .fixture_inputs = &.{ "package test command", "test count", "before artifact", "after artifact" },
        .evidence_required_before_execution = &.{ "dev-loop baseline", "human-agent feedback-loop handoff", "CI artifact policy" },
        .blocking_missing_evidence = "missing reviewed package test baseline",
        .authority_boundary = "fixture plan only; does not execute package tests",
    },
    .{
        .scenario_id = "workbench-solid-build",
        .target_capacity_question = "SolidJS workbench build and local viewer overhead inside webui-dev/zig-webui",
        .fixture_inputs = &.{ "Bun lockfile", "SolidJS workbench scripts", "sample artifact", "visual graph sample" },
        .evidence_required_before_execution = &.{ "workbench build baseline", "live dashboard stream contract", "visual graph fixture" },
        .blocking_missing_evidence = "missing reviewed SolidJS workbench baseline",
        .authority_boundary = "fixture plan only; no alternate renderer support is introduced",
    },
    .{
        .scenario_id = "ci-baseline-capture",
        .target_capacity_question = "CI causal artifact capture overhead before current-branch verification",
        .fixture_inputs = &.{ "CI runner class", "source checkout ref", "artifact refs", "environment metadata" },
        .evidence_required_before_execution = &.{ "CI baseline contract", "artifact aggregation contract", "schema governance" },
        .blocking_missing_evidence = "missing reviewed CI runner baseline",
        .authority_boundary = "fixture plan only; no CI job is scheduled",
    },
};

const concurrency_assumptions: []const ConcurrencyAssumption = &.{
    .{
        .id = "single-artifact-workbench",
        .surface = "SolidJS workbench",
        .assumption = "The first production-planning fixture views one retained artifact or one sampled bundle at a time.",
        .required_evidence = &.{ "workbench-session", "artifact-access-control", "bounded sample artifact" },
        .not_a_claim = "not a multi-user production dashboard claim",
    },
    .{
        .id = "bounded-dashboard-stream",
        .surface = "Live tab",
        .assumption = "Dashboard stream tests stay within a declared frame window with truncation metadata.",
        .required_evidence = &.{ "live-dashboard-stream", "bounded stream fixture", "truncation state" },
        .not_a_claim = "not a production websocket or streaming service capacity claim",
    },
    .{
        .id = "lazy-visual-graph",
        .surface = "Visual Graph tab",
        .assumption = "Graph rendering should plan for lazy perspective changes and explicit node edge fixture sizes.",
        .required_evidence = &.{ "visual graph fixture", "node count", "edge count", "browser screenshot verification" },
        .not_a_claim = "not a production graph database or graph layout capacity claim",
    },
    .{
        .id = "read-only-graph-perspectives",
        .surface = "Graph adapter",
        .assumption = "Cause topology ownership and lineage perspectives remain read-only projections over one causal truth model.",
        .required_evidence = &.{ "unified-spine-contract", "workbench graph visual debugging", "agent-query" },
        .not_a_claim = "not an editable remediation planner claim",
    },
    .{
        .id = "bounded-agent-query",
        .surface = "Agent query interface",
        .assumption = "Agents consume bounded graph slices with evidence ids rather than unbounded artifact dumps.",
        .required_evidence = &.{ "agent-query", "redaction state", "truncation state", "next-query hints" },
        .not_a_claim = "not an unbounded agent memory or search capacity claim",
    },
    .{
        .id = "local-feedback-clusters",
        .surface = "Human-agent feedback loop",
        .assumption = "Regression clusters remain local record-only evidence until durable history learning is separately reviewed.",
        .required_evidence = &.{ "human-agent-feedback-loop", "before-after comparison", "guarded proposal handoff" },
        .not_a_claim = "not a self-applying remediation authority claim",
    },
    .{
        .id = "preview-only-alert-rollout",
        .surface = "Operations handoff",
        .assumption = "Alert and rollout records are preview queues for reviewers before external integrations send or execute anything.",
        .required_evidence = &.{ "alerting-integrations", "rollout-automation-guardrails", "negative automation fixtures" },
        .not_a_claim = "not an incident-management or rollout automation capacity claim",
    },
};

const readiness_gates: []const ReadinessGate = &.{
    .{
        .id = "aggregation-provenance-reviewed",
        .decision = "required before storage estimates",
        .required_evidence = &.{ "source bundle ids", "source classes", "privacy review", "aggregation bundle fixture" },
        .missing_evidence_action = "block retained-artifact-storage model inputs",
    },
    .{
        .id = "retention-policy-reviewed",
        .decision = "required before NenDB retention and backup assumptions",
        .required_evidence = &.{ "retention days", "bundle event limit", "compaction trigger", "backup required", "recovery required" },
        .missing_evidence_action = "block storage growth and compaction claims",
    },
    .{
        .id = "benchmark-baselines-reviewed",
        .decision = "required before load-test fixture execution",
        .required_evidence = &.{ "all eight scenario families", "environment metadata", "sample count", "artifact refs" },
        .missing_evidence_action = "keep benchmark inputs advisory and request reviewed observations",
    },
    .{
        .id = "dashboard-boundary-reviewed",
        .decision = "required before workbench stream sizing",
        .required_evidence = &.{ "bounded frame window", "truncation metadata", "SolidJS workbench verification" },
        .missing_evidence_action = "block dashboard stream capacity claims",
    },
    .{
        .id = "graph-boundary-reviewed",
        .decision = "required before visual graph sizing",
        .required_evidence = &.{ "node count fixture", "edge count fixture", "layout perspective", "canvas verification" },
        .missing_evidence_action = "block visual graph capacity claims",
    },
    .{
        .id = "agent-query-bounds-reviewed",
        .decision = "required before agent workflow capacity assumptions",
        .required_evidence = &.{ "bounded response policy", "query family list", "redaction state", "truncation state" },
        .missing_evidence_action = "block agent query and feedback volume assumptions",
    },
    .{
        .id = "alert-rollout-handoff-reviewed",
        .decision = "required before operations handoff volume assumptions",
        .required_evidence = &.{ "alert preview records", "canary evidence records", "circuit breaker decisions", "rollback readiness records" },
        .missing_evidence_action = "block incident and rollout volume estimates",
    },
    .{
        .id = "load-test-plan-ready",
        .decision = "ready for future load-test harness design",
        .required_evidence = &.{ "fixture scenario ids", "blocking evidence list", "authority boundary", "negative capacity fixtures" },
        .missing_evidence_action = "defer load-test harness implementation",
    },
    .{
        .id = "capacity-plan-ready-for-review",
        .decision = "handoff to production hardening completion audit",
        .required_evidence = &.{ "source contracts", "capacity domains", "storage assumptions", "fixture plan", "readiness gates" },
        .missing_evidence_action = "keep production-capacity-planning open",
    },
};

const negative_capacity_fixtures: []const NegativeCapacityFixture = &.{
    .{
        .id = "unreviewed-benchmark-capacity-claim",
        .attempted_claim = "capacity is sufficient because one local wall-clock baseline is fast",
        .decision = "reject",
        .reason = "wall-clock baselines are advisory and require compatible reviewed observations before capacity planning",
    },
    .{
        .id = "storage-estimate-without-provenance",
        .attempted_claim = "retained storage can be estimated without aggregation bundle provenance",
        .decision = "reject",
        .reason = "storage growth depends on reviewed source class bundle count event count and byte-size evidence",
    },
    .{
        .id = "ttl-enforcement-without-timestamps",
        .attempted_claim = "TTL enforcement is production-ready without capture timestamps or retention reports",
        .decision = "reject",
        .reason = "retention claims need capture timestamps and NenDB retention report evidence",
    },
    .{
        .id = "dashboard-concurrency-from-local-workbench",
        .attempted_claim = "production dashboard concurrency follows from a local SolidJS workbench sample",
        .decision = "reject",
        .reason = "local workbench fixtures prove viewer boundaries only, not hosted production dashboard capacity",
    },
    .{
        .id = "graph-capacity-without-node-edge-fixtures",
        .attempted_claim = "graph visualization is production-scale without node edge fixture evidence",
        .decision = "reject",
        .reason = "visual graph capacity needs explicit node edge counts layout perspective and render verification",
    },
    .{
        .id = "incident-volume-from-alert-previews",
        .attempted_claim = "incident volume can be inferred from alert preview fixtures",
        .decision = "reject",
        .reason = "alert previews are record-only handoff evidence and do not represent production incident traffic",
    },
    .{
        .id = "rollout-volume-from-canary-guardrails",
        .attempted_claim = "rollout traffic capacity can be inferred from canary guardrail records",
        .decision = "reject",
        .reason = "rollout guardrails define review evidence and do not execute or measure traffic mutation",
    },
    .{
        .id = "autoscaling-without-telemetry",
        .attempted_claim = "autoscaling recommendations can be made without production telemetry and human review",
        .decision = "reject",
        .reason = "this report has no live telemetry and mutation authority is none",
    },
};

const agent_guidance: []const AgentGuidance = &.{
    .{ .id = "cite-source-contracts", .guidance = "Every capacity summary should cite the upstream schema and producer that supplied the evidence." },
    .{ .id = "separate-policy-from-observation", .guidance = "NenDB retention constants are reviewed policy values; traffic volume and byte estimates remain unknown until observations exist." },
    .{ .id = "keep-wall-clock-advisory", .guidance = "Use wall-clock baselines to plan fixture coverage, not to claim production throughput." },
    .{ .id = "prefer-bounds-over-averages", .guidance = "When evidence is partial, report bounds required and missing evidence rather than optimistic average capacity." },
    .{ .id = "preserve-human-review", .guidance = "Recommend completion-audit review before any future load-test harness or production sizing work." },
    .{ .id = "respect-mutation-boundary", .guidance = "Do not apply registry config deployment alert rollout app or production changes from this report." },
    .{ .id = "nendb-only", .guidance = "Keep durable planning on the NenDB adapter path and do not introduce non-NenDB durable adapter work." },
    .{ .id = "solidjs-webui-only", .guidance = "Keep workbench capacity assumptions on SolidJS inside webui-dev/zig-webui; do not add alternate renderer scope." },
};

const non_goals: []const []const u8 = &.{
    "live production telemetry ingestion",
    "load-test execution",
    "autoscaling provisioning or infrastructure mutation",
    "production capacity or cost claims",
    "production dashboard hosting",
    "automatic CI failure gates from timing",
    "durable writes",
    "non-NenDB durable adapter work",
    "alternate frontend renderer support",
    "source config registry app deployment rollout alert ticket page or production mutation",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig test tools/causal_production_capacity_planning.zig",
    "zig build causal-production-capacity-planning",
    "zig build causal-production-capacity-planning -- --format json",
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

fn sourceContracts() []const SourceContract {
    return source_contracts;
}

fn capacityDomains() []const CapacityDomain {
    return capacity_domains;
}

fn storageGrowthAssumptions() []const StorageGrowthAssumption {
    return storage_growth_assumptions;
}

fn loadTestFixturePlan() []const LoadTestFixture {
    return load_test_fixture_plan;
}

fn concurrencyAssumptions() []const ConcurrencyAssumption {
    return concurrency_assumptions;
}

fn readinessGates() []const ReadinessGate {
    return readiness_gates;
}

fn negativeCapacityFixtures() []const NegativeCapacityFixture {
    return negative_capacity_fixtures;
}

fn agentGuidance() []const AgentGuidance {
    return agent_guidance;
}

fn nonGoals() []const []const u8 {
    return non_goals;
}

fn verificationCommands() []const []const u8 {
    return verification_commands;
}

fn formatProductionCapacityPlanningText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal production capacity planning\n");
    try output.print(allocator, "schema: {s}\n", .{production_capacity_planning_schema});
    try output.print(allocator, "schema_version: {d}\n", .{production_capacity_planning_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "mode: {s}\n", .{mode});
    try output.appendSlice(allocator, "applied: false\n");
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "next branch: {s}\n\n", .{next_branch});

    try output.appendSlice(allocator, "planning boundary:\n");
    try output.appendSlice(allocator, "- record-only local planning contract\n");
    try output.appendSlice(allocator, "- not a production capacity claim\n");
    try output.appendSlice(allocator, "- no telemetry ingestion load-test execution provisioning or infrastructure mutation\n");
    try output.appendSlice(allocator, "- durable direction remains NenDB adapter only\n");
    try output.appendSlice(allocator, "- workbench direction remains SolidJS inside webui-dev/zig-webui\n\n");

    try output.appendSlice(allocator, "source contracts:\n");
    for (sourceContracts()) |contract| {
        try output.print(allocator, "- {s}\n", .{contract.id});
        try output.print(allocator, "  schema: {s}\n", .{contract.schema});
        try output.print(allocator, "  producer: {s}\n", .{contract.producer});
        try output.print(allocator, "  evidence role: {s}\n", .{contract.evidence_role});
        try output.appendSlice(allocator, "  required for:");
        for (contract.required_for) |item| try output.print(allocator, " {s};", .{item});
        try output.append(allocator, '\n');
        try output.print(allocator, "  missing evidence action: {s}\n", .{contract.missing_evidence_action});
        try output.print(allocator, "  authority boundary: {s}\n", .{contract.authority_boundary});
    }

    try output.appendSlice(allocator, "\ncapacity domains:\n");
    for (capacityDomains()) |domain| {
        try output.print(allocator, "- {s}\n", .{domain.id});
        try output.print(allocator, "  category: {s}\n", .{domain.category});
        try output.print(allocator, "  planning question: {s}\n", .{domain.planning_question});
        try output.appendSlice(allocator, "  required evidence:");
        for (domain.required_evidence) |item| try output.print(allocator, " {s};", .{item});
        try output.append(allocator, '\n');
        try output.print(allocator, "  model expression: {s}\n", .{domain.model_expression});
        try output.print(allocator, "  review status: {s}\n", .{domain.review_status});
        try output.print(allocator, "  agent guidance: {s}\n", .{domain.agent_guidance});
    }

    try output.appendSlice(allocator, "\nstorage growth assumptions:\n");
    for (storageGrowthAssumptions()) |assumption| {
        try output.print(allocator, "- {s}: {s}\n", .{ assumption.id, assumption.known_value });
        try output.print(allocator, "  source: {s}\n", .{assumption.source});
        try output.print(allocator, "  missing evidence action: {s}\n", .{assumption.missing_evidence_action});
    }

    try output.appendSlice(allocator, "\nload-test fixture plan:\n");
    for (loadTestFixturePlan()) |fixture| {
        try output.print(allocator, "- {s}\n", .{fixture.scenario_id});
        try output.print(allocator, "  target capacity question: {s}\n", .{fixture.target_capacity_question});
        try output.appendSlice(allocator, "  fixture inputs:");
        for (fixture.fixture_inputs) |input| try output.print(allocator, " {s};", .{input});
        try output.append(allocator, '\n');
        try output.appendSlice(allocator, "  evidence required before execution:");
        for (fixture.evidence_required_before_execution) |evidence| try output.print(allocator, " {s};", .{evidence});
        try output.append(allocator, '\n');
        try output.print(allocator, "  blocking missing evidence: {s}\n", .{fixture.blocking_missing_evidence});
        try output.print(allocator, "  authority boundary: {s}\n", .{fixture.authority_boundary});
    }

    try output.appendSlice(allocator, "\nconcurrency assumptions:\n");
    for (concurrencyAssumptions()) |assumption| {
        try output.print(allocator, "- {s}: {s}\n", .{ assumption.id, assumption.surface });
        try output.print(allocator, "  assumption: {s}\n", .{assumption.assumption});
        try output.appendSlice(allocator, "  required evidence:");
        for (assumption.required_evidence) |evidence| try output.print(allocator, " {s};", .{evidence});
        try output.append(allocator, '\n');
        try output.print(allocator, "  not a claim: {s}\n", .{assumption.not_a_claim});
    }

    try output.appendSlice(allocator, "\nreadiness gates:\n");
    for (readinessGates()) |gate| {
        try output.print(allocator, "- {s}: {s}\n", .{ gate.id, gate.decision });
        try output.appendSlice(allocator, "  required evidence:");
        for (gate.required_evidence) |evidence| try output.print(allocator, " {s};", .{evidence});
        try output.append(allocator, '\n');
        try output.print(allocator, "  missing evidence action: {s}\n", .{gate.missing_evidence_action});
    }

    try output.appendSlice(allocator, "\nnegative capacity fixtures:\n");
    for (negativeCapacityFixtures()) |fixture| {
        try output.print(allocator, "- {s}: {s}\n", .{ fixture.id, fixture.decision });
        try output.print(allocator, "  attempted claim: {s}\n", .{fixture.attempted_claim});
        try output.print(allocator, "  reason: {s}\n", .{fixture.reason});
    }

    try output.appendSlice(allocator, "\nagent guidance:\n");
    for (agentGuidance()) |guidance| try output.print(allocator, "- {s}: {s}\n", .{ guidance.id, guidance.guidance });

    try output.appendSlice(allocator, "\nnon-goals:\n");
    for (nonGoals()) |item| try output.print(allocator, "- {s}\n", .{item});

    try output.appendSlice(allocator, "\nverification commands:\n");
    for (verificationCommands()) |command| try output.print(allocator, "- {s}\n", .{command});

    return output.toOwnedSlice(allocator);
}

fn formatProductionCapacityPlanningJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringProperty(allocator, &output, "schema", production_capacity_planning_schema, true, 2);
    try output.print(allocator, "  \"schema_version\": {d},\n", .{production_capacity_planning_schema_version});
    try appendJsonStringProperty(allocator, &output, "producer", generated_by, true, 2);
    try appendJsonStringProperty(allocator, &output, "mode", mode, true, 2);
    try output.appendSlice(allocator, "  \"applied\": false,\n");
    try appendJsonStringProperty(allocator, &output, "mutation_authority", mutation_authority, true, 2);
    try appendJsonStringProperty(allocator, &output, "source_branch", source_branch, true, 2);

    try output.appendSlice(allocator, "  \"source_contracts\": [\n");
    for (sourceContracts(), 0..) |contract, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", contract.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "schema", contract.schema, true, 6);
        try appendJsonStringProperty(allocator, &output, "producer", contract.producer, true, 6);
        try appendJsonStringProperty(allocator, &output, "evidence_role", contract.evidence_role, true, 6);
        try appendIndentedStringArrayProperty(allocator, &output, "required_for", contract.required_for, true, 6);
        try appendJsonStringProperty(allocator, &output, "missing_evidence_action", contract.missing_evidence_action, true, 6);
        try appendJsonStringProperty(allocator, &output, "authority_boundary", contract.authority_boundary, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < sourceContracts().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"capacity_domains\": [\n");
    for (capacityDomains(), 0..) |domain, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", domain.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "category", domain.category, true, 6);
        try appendJsonStringProperty(allocator, &output, "planning_question", domain.planning_question, true, 6);
        try appendIndentedStringArrayProperty(allocator, &output, "required_evidence", domain.required_evidence, true, 6);
        try appendJsonStringProperty(allocator, &output, "model_expression", domain.model_expression, true, 6);
        try appendJsonStringProperty(allocator, &output, "review_status", domain.review_status, true, 6);
        try appendJsonStringProperty(allocator, &output, "agent_guidance", domain.agent_guidance, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < capacityDomains().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"storage_growth_assumptions\": [\n");
    for (storageGrowthAssumptions(), 0..) |assumption, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", assumption.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "known_value", assumption.known_value, true, 6);
        try appendJsonStringProperty(allocator, &output, "source", assumption.source, true, 6);
        try appendJsonStringProperty(allocator, &output, "missing_evidence_action", assumption.missing_evidence_action, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < storageGrowthAssumptions().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"load_test_fixture_plan\": [\n");
    for (loadTestFixturePlan(), 0..) |fixture, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "scenario_id", fixture.scenario_id, true, 6);
        try appendJsonStringProperty(allocator, &output, "target_capacity_question", fixture.target_capacity_question, true, 6);
        try appendIndentedStringArrayProperty(allocator, &output, "fixture_inputs", fixture.fixture_inputs, true, 6);
        try appendIndentedStringArrayProperty(allocator, &output, "evidence_required_before_execution", fixture.evidence_required_before_execution, true, 6);
        try appendJsonStringProperty(allocator, &output, "blocking_missing_evidence", fixture.blocking_missing_evidence, true, 6);
        try appendJsonStringProperty(allocator, &output, "authority_boundary", fixture.authority_boundary, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < loadTestFixturePlan().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"concurrency_assumptions\": [\n");
    for (concurrencyAssumptions(), 0..) |assumption, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", assumption.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "surface", assumption.surface, true, 6);
        try appendJsonStringProperty(allocator, &output, "assumption", assumption.assumption, true, 6);
        try appendIndentedStringArrayProperty(allocator, &output, "required_evidence", assumption.required_evidence, true, 6);
        try appendJsonStringProperty(allocator, &output, "not_a_claim", assumption.not_a_claim, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < concurrencyAssumptions().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"readiness_gates\": [\n");
    for (readinessGates(), 0..) |gate, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", gate.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "decision", gate.decision, true, 6);
        try appendIndentedStringArrayProperty(allocator, &output, "required_evidence", gate.required_evidence, true, 6);
        try appendJsonStringProperty(allocator, &output, "missing_evidence_action", gate.missing_evidence_action, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < readinessGates().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"negative_capacity_fixtures\": [\n");
    for (negativeCapacityFixtures(), 0..) |fixture, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", fixture.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "attempted_claim", fixture.attempted_claim, true, 6);
        try appendJsonStringProperty(allocator, &output, "decision", fixture.decision, true, 6);
        try appendJsonStringProperty(allocator, &output, "reason", fixture.reason, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < negativeCapacityFixtures().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"agent_guidance\": [\n");
    for (agentGuidance(), 0..) |guidance, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", guidance.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "guidance", guidance.guidance, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < agentGuidance().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"non_goals\": ");
    try appendStringArray(allocator, &output, nonGoals());
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"verification_commands\": ");
    try appendStringArray(allocator, &output, verificationCommands());
    try output.appendSlice(allocator, ",\n");
    try appendJsonStringProperty(allocator, &output, "next_branch", next_branch, false, 2);
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatProductionCapacityPlanningText(init.gpa),
        .json => try formatProductionCapacityPlanningJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-capacity-planning error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn appendIndent(allocator: std.mem.Allocator, output: *std.ArrayList(u8), spaces: usize) !void {
    for (0..spaces) |_| try output.append(allocator, ' ');
}

fn appendJsonStringProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: []const u8,
    comma: bool,
    indent: usize,
) !void {
    try appendIndent(allocator, output, indent);
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendJsonString(allocator, output, value);
    if (comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendIndentedStringArrayProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    values: []const []const u8,
    comma: bool,
    indent: usize,
) !void {
    try appendIndent(allocator, output, indent);
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendStringArray(allocator, output, values);
    if (comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendStringArray(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    values: []const []const u8,
) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.append(allocator, ']');
}

fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

fn hasSourceContract(id: []const u8) bool {
    for (sourceContracts()) |contract| {
        if (std.mem.eql(u8, contract.id, id)) return true;
    }
    return false;
}

fn hasCapacityDomain(id: []const u8) bool {
    for (capacityDomains()) |domain| {
        if (std.mem.eql(u8, domain.id, id)) return true;
    }
    return false;
}

fn hasStorageAssumption(id: []const u8, value: []const u8) bool {
    for (storageGrowthAssumptions()) |assumption| {
        if (std.mem.eql(u8, assumption.id, id) and std.mem.eql(u8, assumption.known_value, value)) return true;
    }
    return false;
}

fn hasReadinessGate(id: []const u8) bool {
    for (readinessGates()) |gate| {
        if (std.mem.eql(u8, gate.id, id)) return true;
    }
    return false;
}

fn hasNegativeFixture(id: []const u8) bool {
    for (negativeCapacityFixtures()) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

test "production capacity planning usage names command and formats" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-production-capacity-planning") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--format text|json") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.production-capacity-planning.v1", production_capacity_planning_schema);
}

test "production capacity planning parses format options" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-production-capacity-planning"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-production-capacity-planning", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-production-capacity-planning", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-production-capacity-planning", "--format", "yaml" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-production-capacity-planning", "--json" }));
}

test "production capacity planning source contracts cover upstream evidence" {
    try std.testing.expectEqual(@as(usize, 8), sourceContracts().len);
    try std.testing.expect(hasSourceContract("production-artifact-aggregation"));
    try std.testing.expect(hasSourceContract("durable-production-retention"));
    try std.testing.expect(hasSourceContract("wall-clock-benchmark-baselines"));
    try std.testing.expect(hasSourceContract("live-dashboard-stream"));
    try std.testing.expect(hasSourceContract("agent-query"));
    try std.testing.expect(hasSourceContract("human-agent-feedback-loop"));
    try std.testing.expect(hasSourceContract("alerting-integrations"));
    try std.testing.expect(hasSourceContract("rollout-automation-guardrails"));
}

test "production capacity planning domains cover storage benchmark workbench and handoff surfaces" {
    try std.testing.expectEqual(@as(usize, 10), capacityDomains().len);
    try std.testing.expect(hasCapacityDomain("retained-artifact-storage"));
    try std.testing.expect(hasCapacityDomain("nendb-retention-compaction"));
    try std.testing.expect(hasCapacityDomain("benchmark-observation-coverage"));
    try std.testing.expect(hasCapacityDomain("request-trace-volume"));
    try std.testing.expect(hasCapacityDomain("background-job-trace-volume"));
    try std.testing.expect(hasCapacityDomain("artifact-formatting-and-query"));
    try std.testing.expect(hasCapacityDomain("dashboard-stream-window"));
    try std.testing.expect(hasCapacityDomain("visual-graph-rendering"));
    try std.testing.expect(hasCapacityDomain("agent-query-and-feedback"));
    try std.testing.expect(hasCapacityDomain("alerting-rollout-handoff-volume"));
}

test "production capacity planning cites known NenDB retention constants" {
    try std.testing.expect(hasStorageAssumption("retention-days", "14"));
    try std.testing.expect(hasStorageAssumption("max-events-per-bundle", "4096"));
    try std.testing.expect(hasStorageAssumption("compaction-trigger-events", "2048"));
    try std.testing.expect(hasStorageAssumption("compact-to-events", "1024"));
    try std.testing.expect(hasStorageAssumption("backup-required", "true"));
    try std.testing.expect(hasStorageAssumption("recovery-required", "true"));
}

test "production capacity planning readiness gates require reviewed evidence" {
    try std.testing.expect(hasReadinessGate("aggregation-provenance-reviewed"));
    try std.testing.expect(hasReadinessGate("retention-policy-reviewed"));
    try std.testing.expect(hasReadinessGate("benchmark-baselines-reviewed"));
    try std.testing.expect(hasReadinessGate("dashboard-boundary-reviewed"));
    try std.testing.expect(hasReadinessGate("graph-boundary-reviewed"));
    try std.testing.expect(hasReadinessGate("agent-query-bounds-reviewed"));
    try std.testing.expect(hasReadinessGate("alert-rollout-handoff-reviewed"));
    try std.testing.expect(hasReadinessGate("load-test-plan-ready"));
    try std.testing.expect(hasReadinessGate("capacity-plan-ready-for-review"));
}

test "production capacity planning negative fixtures block over-claiming" {
    try std.testing.expect(hasNegativeFixture("unreviewed-benchmark-capacity-claim"));
    try std.testing.expect(hasNegativeFixture("storage-estimate-without-provenance"));
    try std.testing.expect(hasNegativeFixture("ttl-enforcement-without-timestamps"));
    try std.testing.expect(hasNegativeFixture("dashboard-concurrency-from-local-workbench"));
    try std.testing.expect(hasNegativeFixture("autoscaling-without-telemetry"));
}

test "production capacity planning text report explains planning boundary" {
    const report = try formatProductionCapacityPlanningText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "production capacity planning") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "record-only") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation authority: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "not a production capacity claim") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, next_branch) != null);
}

test "production capacity planning json report is machine readable" {
    const report = try formatProductionCapacityPlanningJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-capacity-planning.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"source_contracts\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"capacity_domains\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"readiness_gates\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"next_branch\": \"codex/zigeffect-causal-production-hardening-completion-audit\"") != null);
}
