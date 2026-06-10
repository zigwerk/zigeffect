const std = @import("std");

pub const production_hardening_completion_audit_schema = "zigeffect.causal.production-hardening-completion-audit.v1";
pub const production_hardening_completion_audit_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-hardening-completion-audit";
pub const recommendation = "start-load-test-observation-harness";
pub const next_branch = "codex/zigeffect-causal-load-test-observation-harness";

const OutputFormat = enum { text, json };

const generated_by = "causal-production-hardening-completion-audit";
const mode = "local-record";
const mutation_authority = "none";

const MilestoneCheck = struct {
    id: []const u8,
    status: []const u8,
    schema: []const u8,
    command: []const u8,
    doc: []const u8,
    evidence: []const u8,
    completion_boundary: []const u8,
    agent_guidance: []const u8,
};

const BoundaryCheck = struct {
    id: []const u8,
    decision: []const u8,
    evidence: []const u8,
    blocked_claim: []const u8,
    agent_guidance: []const u8,
};

const RemainingEvidenceGap = struct {
    id: []const u8,
    status: []const u8,
    reason: []const u8,
    recommended_branch: []const u8,
    blocked_until: []const u8,
};

const NegativeAuditFixture = struct {
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
    \\  zig build causal-production-hardening-completion-audit
    \\  zig build causal-production-hardening-completion-audit -- --format text
    \\  zig build causal-production-hardening-completion-audit -- --format json
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

const milestone_checks: []const MilestoneCheck = &.{
    .{
        .id = "production-artifact-aggregation",
        .status = "delivered",
        .schema = "zigeffect.causal.production-artifact-aggregation.v1",
        .command = "zig build causal-production-artifact-aggregation -- --format json",
        .doc = "packages/zigeffect/docs/production-artifact-aggregation.md",
        .evidence = "Aggregation bundle contract source provenance privacy review gate and multi-source fixture are delivered.",
        .completion_boundary = "Does not ingest live production telemetry or write durable storage.",
        .agent_guidance = "Use as provenance evidence before durable retention or capacity assumptions.",
    },
    .{
        .id = "durable-production-retention",
        .status = "delivered",
        .schema = "zigeffect.causal.durable-production-retention.v1",
        .command = "zig build causal-durable-production-retention -- --format json",
        .doc = "packages/zigeffect/docs/durable-production-retention.md",
        .evidence = "NenDB-only retention TTL compaction backup recovery and retained-bundle fixture are delivered.",
        .completion_boundary = "Does not restore production data enforce TTL from wall-clock time or add non-NenDB adapters.",
        .agent_guidance = "Treat retention constants as policy evidence, not production durability proof.",
    },
    .{
        .id = "production-deployment-runbooks",
        .status = "delivered",
        .schema = "zigeffect.causal.production-deployment-runbooks.v1",
        .command = "zig build causal-production-deployment-runbooks -- --format json",
        .doc = "packages/zigeffect/docs/production-deployment-runbooks.md",
        .evidence = "Manual deploy rollback causal verification and incident response checklists are delivered.",
        .completion_boundary = "Does not deploy services roll back services page humans or automate production actions.",
        .agent_guidance = "Use runbooks as review gates before any future automation branch.",
    },
    .{
        .id = "artifact-access-control",
        .status = "delivered",
        .schema = "zigeffect.causal.artifact-access-control.v1",
        .command = "zig build causal-artifact-access-control -- --format json",
        .doc = "packages/zigeffect/docs/artifact-access-control.md",
        .evidence = "Visibility classes role labels permission matrix decisions denied-view fixtures and audit fields are delivered.",
        .completion_boundary = "Does not authenticate users enforce live RBAC or grant workbench mutation authority.",
        .agent_guidance = "Use as policy evidence only; live RBAC enforcement remains future.",
    },
    .{
        .id = "unified-causal-spine-contract",
        .status = "delivered",
        .schema = "zigeffect.causal.unified-spine-contract.v1",
        .command = "zig build causal-unified-spine-contract -- --format json",
        .doc = "packages/zigeffect/docs/unified-spine-contract.md",
        .evidence = "Canonical runtime ids app semantic ids relationship taxonomy policy boundary and projection rules are delivered.",
        .completion_boundary = "Does not change live runtime emission or write durable indexes.",
        .agent_guidance = "Use as the shared vocabulary for human workbench agent query and NenDB projections.",
    },
    .{
        .id = "deep-runtime-internals",
        .status = "delivered",
        .schema = "zigeffect.causal.v1",
        .command = "zig build test",
        .doc = "packages/zigeffect/docs/agent-observable-runtime.md",
        .evidence = "Runtime facts for layers services scopes fibers resources finalizers retries defects interruptions and cause chains are represented through the causal spine.",
        .completion_boundary = "Does not record raw payloads secrets or unbounded internal state.",
        .agent_guidance = "Use typed runtime facts and stable ids rather than verbose labels.",
    },
    .{
        .id = "app-semantic-trace-api",
        .status = "delivered",
        .schema = "zigeffect.causal.app-runtime.v1",
        .command = "zig build test",
        .doc = "packages/zigeffect/docs/agent-observable-runtime.md",
        .evidence = "App semantic refs for data reads transforms writes service calls domain actions policies artifacts and responses are delivered.",
        .completion_boundary = "Does not record raw request bodies prompts credentials PII or headers.",
        .agent_guidance = "Record semantic references and lineage, not sensitive payloads.",
    },
    .{
        .id = "agent-query-interface",
        .status = "partial",
        .schema = "zigeffect.causal.agent-query.v1",
        .command = "zig build causal-query -- --agent",
        .doc = "packages/zigeffect/docs/agent-observable-runtime.md",
        .evidence = "Runtime bounded query JSON and app semantic trace_data slices are delivered; arbitrary cross-run comparison remains future.",
        .completion_boundary = "Read-only bounded slices only; no artifact mutation and no unbounded search.",
        .agent_guidance = "Use existing query families for evidence slices and keep compare_runs as a future gap.",
    },
    .{
        .id = "encryption-at-rest-policy",
        .status = "delivered",
        .schema = "zigeffect.causal.encryption-at-rest-policy.v1",
        .command = "zig build causal-encryption-at-rest-policy -- --format json",
        .doc = "packages/zigeffect/docs/encryption-at-rest-policy.md",
        .evidence = "Encryption domains key owner labels rotation evidence encrypted fixture metadata redaction ordering and denied fixtures are delivered.",
        .completion_boundary = "Does not encrypt bytes decrypt bytes generate keys call a KMS or implement storage encryption.",
        .agent_guidance = "Use as policy for future encrypted stores, not evidence that bytes are encrypted.",
    },
    .{
        .id = "alerting-integrations",
        .status = "delivered",
        .schema = "zigeffect.causal.alerting-integrations.v1",
        .command = "zig build causal-alerting-integrations -- --format json",
        .doc = "packages/zigeffect/docs/alerting-integrations.md",
        .evidence = "Record-only channel contracts severity routing escalation gates payload fields preview fixtures and denied fixtures are delivered.",
        .completion_boundary = "Does not send notifications create tickets forward SIEM events page humans read secrets or call networks.",
        .agent_guidance = "Treat alert records as previews until a live integration branch is reviewed.",
    },
    .{
        .id = "live-dashboard-streaming-workbench",
        .status = "delivered",
        .schema = "zigeffect.causal.live-dashboard-stream.v1",
        .command = "zig build causal-live-dashboard-streaming-workbench -- --format json",
        .doc = "packages/zigeffect/docs/live-dashboard-streaming-workbench.md",
        .evidence = "Bounded stream contract local fixture Live tab Visual Graph tab and Solid G6 adapter boundary are delivered.",
        .completion_boundary = "Does not ingest production telemetry host a production dashboard or write durable stores.",
        .agent_guidance = "Use as local bounded viewer evidence only.",
    },
    .{
        .id = "workbench-graph-visual-debugging",
        .status = "delivered",
        .schema = "zigeffect.causal.workbench-session.v1",
        .command = "bun run zigeffect:workbench:test",
        .doc = "packages/zigeffect/docs/production-hardening-backlog.md",
        .evidence = "Visual Graph cause topology ownership and lineage perspectives sample fixture selection panels and canvas verification are delivered.",
        .completion_boundary = "Does not add editable remediation planning or alternate frontend renderer support.",
        .agent_guidance = "Keep graph debugging read-only and SolidJS plus zig-webui aligned.",
    },
    .{
        .id = "human-agent-feedback-loop",
        .status = "delivered",
        .schema = "zigeffect.causal.human-agent-feedback-loop.v1",
        .command = "zig build causal-human-agent-feedback-loop -- --format json",
        .doc = "packages/zigeffect/docs/human-agent-feedback-loop.md",
        .evidence = "Workbench selection bounded query before/after comparison regression cluster guarded handoff and NenDB history handoff records are delivered.",
        .completion_boundary = "Does not execute queries apply remediation write durable history or grant mutation authority.",
        .agent_guidance = "Use as a record-only self-improvement loop; applied state stays false.",
    },
    .{
        .id = "rollout-automation-guardrails",
        .status = "delivered",
        .schema = "zigeffect.causal.rollout-automation-guardrails.v1",
        .command = "zig build causal-rollout-automation-guardrails -- --format json",
        .doc = "packages/zigeffect/docs/rollout-automation-guardrails.md",
        .evidence = "Canary evidence progression gates circuit-breaker decisions rollback readiness and negative automation fixtures are delivered.",
        .completion_boundary = "Does not shift traffic mutate feature flags deploy rollback send alerts or page humans.",
        .agent_guidance = "Use guardrails as review evidence only.",
    },
    .{
        .id = "wall-clock-benchmark-baselines",
        .status = "delivered",
        .schema = "zigeffect.causal.wall-clock-benchmark-baselines.v1",
        .command = "zig build causal-wall-clock-benchmark-baselines -- --format json",
        .doc = "packages/zigeffect/docs/wall-clock-benchmark-baselines.md",
        .evidence = "Local and CI timing scenario families baseline fields environment metadata calibration policy and advisory gates are delivered.",
        .completion_boundary = "Does not collect timings fail CI run load tests size production capacity or grant authority.",
        .agent_guidance = "Keep wall-clock evidence advisory until reviewed.",
    },
    .{
        .id = "production-capacity-planning",
        .status = "delivered",
        .schema = "zigeffect.causal.production-capacity-planning.v1",
        .command = "zig build causal-production-capacity-planning -- --format json",
        .doc = "packages/zigeffect/docs/production-capacity-planning.md",
        .evidence = "Source contracts capacity domains storage assumptions load-test fixture plan concurrency assumptions readiness gates and negative capacity fixtures are delivered.",
        .completion_boundary = "Planning-only; does not ingest telemetry run load tests size production capacity or provision infrastructure.",
        .agent_guidance = "Use to seed the local load-test observation harness and block weak claims.",
    },
};

const boundary_checks: []const BoundaryCheck = &.{
    .{ .id = "record-only-authority", .decision = "passed", .evidence = "All production-hardening tools are reports, policies, fixtures, or audits.", .blocked_claim = "contract reports are production runtime behavior", .agent_guidance = "Treat reports as evidence records only." },
    .{ .id = "mutation-authority-none", .decision = "passed", .evidence = "Backlog and delivered reports keep mutation authority none.", .blocked_claim = "completion audit grants source config app registry deployment rollout or production mutation", .agent_guidance = "Require a future reviewed authority branch before mutation." },
    .{ .id = "nendb-only-durable-direction", .decision = "passed", .evidence = "Durable retention and capacity planning name NenDB adapter only.", .blocked_claim = "Cockroach D1 R2 or another durable adapter is approved by this audit", .agent_guidance = "Keep durable history work on the NenDB adapter path." },
    .{ .id = "solidjs-webui-workbench-direction", .decision = "passed", .evidence = "Operations backlog and workbench docs keep SolidJS inside webui-dev/zig-webui.", .blocked_claim = "React Vue or another renderer is approved by this audit", .agent_guidance = "Keep the workbench path SolidJS plus zig-webui unless a later adapter proves need." },
    .{ .id = "capacity-planning-non-claim", .decision = "passed", .evidence = "Production capacity planning is planning-only and contains negative capacity fixtures.", .blocked_claim = "capacity planning proves production throughput autoscaling or cost", .agent_guidance = "Use capacity planning only for fixture planning and missing evidence gates." },
    .{ .id = "wall-clock-advisory-only", .decision = "passed", .evidence = "Wall-clock baseline report defines advisory review gates and no automatic CI failure.", .blocked_claim = "wall-clock baselines are deterministic release blockers", .agent_guidance = "Require compatible reviewed observations before timing claims." },
    .{ .id = "alerting-and-rollout-preview-only", .decision = "passed", .evidence = "Alerting and rollout reports are preview and guardrail records.", .blocked_claim = "alerts were sent or traffic was shifted", .agent_guidance = "Separate previews and guardrails from live integrations." },
    .{ .id = "access-control-policy-only", .decision = "passed", .evidence = "Artifact access control defines policy, denied fixtures, and audit fields.", .blocked_claim = "live RBAC enforcement exists", .agent_guidance = "Keep RBAC enforcement as a future evidence gap." },
    .{ .id = "encryption-policy-only", .decision = "passed", .evidence = "Encryption-at-rest policy defines key and encrypted fixture metadata only.", .blocked_claim = "retained bytes are encrypted by this milestone", .agent_guidance = "Do not claim encrypted storage until bytes and keys are implemented." },
    .{ .id = "agent-query-bounded-read-only", .decision = "passed", .evidence = "Agent query interface exposes bounded read-only graph slices.", .blocked_claim = "agents can mutate traces or run unbounded searches", .agent_guidance = "Prefer bounded query families and cite limitations." },
    .{ .id = "production-telemetry-absent", .decision = "passed", .evidence = "No production-hardening report ingests live production telemetry.", .blocked_claim = "this audit proves production runtime state", .agent_guidance = "Recommend future telemetry design separately from completion audit." },
};

const remaining_evidence_gaps: []const RemainingEvidenceGap = &.{
    .{ .id = "load-test-observation-harness", .status = "recommended-next", .reason = "Capacity planning has fixture families and readiness gates but no observation records.", .recommended_branch = "codex/zigeffect-causal-load-test-observation-harness", .blocked_until = "completion audit is delivered and reviewed" },
    .{ .id = "production-telemetry-capture-design", .status = "future", .reason = "No live production telemetry ingestion contract exists.", .recommended_branch = "future production telemetry capture branch", .blocked_until = "local observation harness and privacy review exist" },
    .{ .id = "reviewed-production-capacity-sizing", .status = "future", .reason = "Capacity plan is formula-only and lacks reviewed observations.", .recommended_branch = "future production capacity sizing review", .blocked_until = "observed load and production telemetry evidence exist" },
    .{ .id = "live-alert-delivery", .status = "future", .reason = "Alerting integrations are preview-only records.", .recommended_branch = "future live alert delivery branch", .blocked_until = "secrets routing human approval and network policy are reviewed" },
    .{ .id = "live-rollout-automation", .status = "future", .reason = "Rollout automation guardrails do not execute rollout actions.", .recommended_branch = "future live rollout automation branch", .blocked_until = "deployment authority and rollback controls are reviewed" },
    .{ .id = "live-rbac-enforcement", .status = "future", .reason = "Artifact access control defines policy records only.", .recommended_branch = "future artifact RBAC enforcement branch", .blocked_until = "identity provider and production host design exist" },
    .{ .id = "encryption-implementation", .status = "future", .reason = "Encryption-at-rest policy does not encrypt bytes.", .recommended_branch = "future encryption implementation branch", .blocked_until = "key management and durable adapter integration are reviewed" },
    .{ .id = "production-dashboard-hosting", .status = "future", .reason = "Workbench and dashboard stream are local bounded viewers.", .recommended_branch = "future production dashboard hosting branch", .blocked_until = "access control production telemetry and hosting policy exist" },
    .{ .id = "agent-query-cross-run-comparison", .status = "future", .reason = "Agent query interface leaves compare_runs future.", .recommended_branch = "future agent query cross-run comparison branch", .blocked_until = "stable multi-run artifact pairing exists" },
    .{ .id = "nendb-durable-history-hardening", .status = "future", .reason = "Feedback-loop durable history is a future NenDB handoff only.", .recommended_branch = "future NenDB durable history hardening branch", .blocked_until = "NenDB retention and query-history invariants are reviewed" },
};

const negative_audit_fixtures: []const NegativeAuditFixture = &.{
    .{ .id = "contract-reports-as-production-ready", .attempted_claim = "all production hardening is production-ready because all contract reports exist", .decision = "reject", .reason = "contracts close the evidence sweep but do not deploy production runtime behavior" },
    .{ .id = "capacity-plan-as-capacity-claim", .attempted_claim = "production capacity is proven by the capacity planning report", .decision = "reject", .reason = "capacity planning is formula-only and planning-only until observations exist" },
    .{ .id = "cockroach-or-non-nendb-adapter", .attempted_claim = "completion audit authorizes Cockroach or another durable adapter", .decision = "reject", .reason = "durable direction remains NenDB adapter only" },
    .{ .id = "react-or-alternate-renderer", .attempted_claim = "completion audit authorizes React or alternate workbench renderer work", .decision = "reject", .reason = "workbench direction remains SolidJS inside webui-dev/zig-webui" },
    .{ .id = "alert-preview-as-sent-alert", .attempted_claim = "alert preview fixtures prove alerts were sent", .decision = "reject", .reason = "alert integrations are record-only previews with no network sends" },
    .{ .id = "rollout-guardrail-as-traffic-shift", .attempted_claim = "rollout guardrail records prove traffic was shifted", .decision = "reject", .reason = "rollout records are evidence gates and do not mutate traffic" },
    .{ .id = "access-policy-as-live-rbac", .attempted_claim = "access-control policy proves live RBAC enforcement", .decision = "reject", .reason = "access control is policy and fixture evidence only" },
    .{ .id = "encryption-policy-as-encrypted-bytes", .attempted_claim = "encryption policy proves retained bytes are encrypted", .decision = "reject", .reason = "encryption implementation remains future work" },
    .{ .id = "wall-clock-baseline-as-ci-gate", .attempted_claim = "wall-clock baselines can fail CI automatically", .decision = "reject", .reason = "wall-clock evidence is advisory until reviewed" },
    .{ .id = "completion-audit-as-mutation-authority", .attempted_claim = "completion audit grants authority to mutate source config deployment rollout app registry or production state", .decision = "reject", .reason = "mutation authority remains none" },
};

const agent_guidance: []const AgentGuidance = &.{
    .{ .id = "close-contract-sweep-only", .guidance = "Use this audit to close the production-hardening contract sweep, not to declare production runtime readiness." },
    .{ .id = "cite-milestone-evidence", .guidance = "When summarizing completion, cite milestone id schema command doc and completion boundary." },
    .{ .id = "preserve-boundaries", .guidance = "Keep record-only mutation-authority-none NenDB-only and SolidJS webui constraints visible in every follow-up." },
    .{ .id = "start-local-observations", .guidance = "Use the recommended next branch to design a local load-test observation harness from capacity-planning fixtures." },
    .{ .id = "do-not-overclaim", .guidance = "Negative fixtures should block production-ready capacity live alert rollout RBAC encryption and mutation claims." },
};

const non_goals: []const []const u8 = &.{
    "live production telemetry ingestion",
    "load-test execution",
    "production capacity sizing or cost estimates",
    "autoscaling or infrastructure provisioning",
    "live alert delivery ticket creation SIEM forwarding or paging",
    "live rollout deployment traffic or feature-flag mutation",
    "live RBAC enforcement",
    "encryption implementation key generation KMS calls encryption or decryption",
    "production dashboard hosting",
    "source config app registry deployment rollout alert ticket page durable-store or production mutation",
    "non-NenDB durable adapter work",
    "Cockroach adapter work",
    "alternate frontend renderer work",
    "whole-roadmap completion claim",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig test tools/causal_production_hardening_completion_audit.zig",
    "zig build causal-production-hardening-completion-audit",
    "zig build causal-production-hardening-completion-audit -- --format json",
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

fn milestoneChecks() []const MilestoneCheck {
    return milestone_checks;
}

fn boundaryChecks() []const BoundaryCheck {
    return boundary_checks;
}

fn remainingEvidenceGaps() []const RemainingEvidenceGap {
    return remaining_evidence_gaps;
}

fn negativeAuditFixtures() []const NegativeAuditFixture {
    return negative_audit_fixtures;
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

fn formatProductionHardeningCompletionAuditText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal production hardening completion audit\n");
    try output.print(allocator, "schema: {s}\n", .{production_hardening_completion_audit_schema});
    try output.print(allocator, "schema_version: {d}\n", .{production_hardening_completion_audit_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "mode: {s}\n", .{mode});
    try output.appendSlice(allocator, "applied: false\n");
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch: {s}\n\n", .{next_branch});

    try output.appendSlice(allocator, "audit boundary:\n");
    try output.appendSlice(allocator, "- record-only local completion evidence\n");
    try output.appendSlice(allocator, "- closes the production-hardening contract sweep only\n");
    try output.appendSlice(allocator, "- not production runtime readiness and not production capacity evidence\n");
    try output.appendSlice(allocator, "- durable direction remains NenDB adapter only\n");
    try output.appendSlice(allocator, "- workbench direction remains SolidJS inside webui-dev/zig-webui\n\n");

    try output.appendSlice(allocator, "milestone checks:\n");
    for (milestoneChecks()) |check| {
        try output.print(allocator, "- {s}: {s}\n", .{ check.id, check.status });
        try output.print(allocator, "  schema: {s}\n", .{check.schema});
        try output.print(allocator, "  command: {s}\n", .{check.command});
        try output.print(allocator, "  doc: {s}\n", .{check.doc});
        try output.print(allocator, "  evidence: {s}\n", .{check.evidence});
        try output.print(allocator, "  completion boundary: {s}\n", .{check.completion_boundary});
        try output.print(allocator, "  agent guidance: {s}\n", .{check.agent_guidance});
    }

    try output.appendSlice(allocator, "\nboundary checks:\n");
    for (boundaryChecks()) |check| {
        try output.print(allocator, "- {s}: {s}\n", .{ check.id, check.decision });
        try output.print(allocator, "  evidence: {s}\n", .{check.evidence});
        try output.print(allocator, "  blocked claim: {s}\n", .{check.blocked_claim});
        try output.print(allocator, "  agent guidance: {s}\n", .{check.agent_guidance});
    }

    try output.appendSlice(allocator, "\nremaining evidence gaps:\n");
    for (remainingEvidenceGaps()) |gap| {
        try output.print(allocator, "- {s}: {s}\n", .{ gap.id, gap.status });
        try output.print(allocator, "  reason: {s}\n", .{gap.reason});
        try output.print(allocator, "  recommended branch: {s}\n", .{gap.recommended_branch});
        try output.print(allocator, "  blocked until: {s}\n", .{gap.blocked_until});
    }

    try output.appendSlice(allocator, "\nnegative audit fixtures:\n");
    for (negativeAuditFixtures()) |fixture| {
        try output.print(allocator, "- {s}: {s}\n", .{ fixture.id, fixture.decision });
        try output.print(allocator, "  attempted claim: {s}\n", .{fixture.attempted_claim});
        try output.print(allocator, "  reason: {s}\n", .{fixture.reason});
    }

    try output.appendSlice(allocator, "\nagent guidance:\n");
    for (agentGuidance()) |guidance| {
        try output.print(allocator, "- {s}: {s}\n", .{ guidance.id, guidance.guidance });
    }

    try output.appendSlice(allocator, "\nnon-goals:\n");
    for (nonGoals()) |item| try output.print(allocator, "- {s}\n", .{item});

    try output.appendSlice(allocator, "\nverification commands:\n");
    for (verificationCommands()) |command| try output.print(allocator, "- {s}\n", .{command});

    return output.toOwnedSlice(allocator);
}

fn formatProductionHardeningCompletionAuditJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringProperty(allocator, &output, "schema", production_hardening_completion_audit_schema, true, 2);
    try output.print(allocator, "  \"schema_version\": {d},\n", .{production_hardening_completion_audit_schema_version});
    try appendJsonStringProperty(allocator, &output, "producer", generated_by, true, 2);
    try appendJsonStringProperty(allocator, &output, "mode", mode, true, 2);
    try output.appendSlice(allocator, "  \"applied\": false,\n");
    try appendJsonStringProperty(allocator, &output, "mutation_authority", mutation_authority, true, 2);
    try appendJsonStringProperty(allocator, &output, "source_branch", source_branch, true, 2);
    try appendJsonStringProperty(allocator, &output, "status", "current", true, 2);
    try appendJsonStringProperty(allocator, &output, "recommendation", recommendation, true, 2);
    try appendJsonStringProperty(allocator, &output, "next_branch", next_branch, true, 2);

    try output.appendSlice(allocator, "  \"milestone_checks\": [\n");
    for (milestoneChecks(), 0..) |check, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", check.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "status", check.status, true, 6);
        try appendJsonStringProperty(allocator, &output, "schema", check.schema, true, 6);
        try appendJsonStringProperty(allocator, &output, "command", check.command, true, 6);
        try appendJsonStringProperty(allocator, &output, "doc", check.doc, true, 6);
        try appendJsonStringProperty(allocator, &output, "evidence", check.evidence, true, 6);
        try appendJsonStringProperty(allocator, &output, "completion_boundary", check.completion_boundary, true, 6);
        try appendJsonStringProperty(allocator, &output, "agent_guidance", check.agent_guidance, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < milestoneChecks().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"boundary_checks\": [\n");
    for (boundaryChecks(), 0..) |check, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", check.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "decision", check.decision, true, 6);
        try appendJsonStringProperty(allocator, &output, "evidence", check.evidence, true, 6);
        try appendJsonStringProperty(allocator, &output, "blocked_claim", check.blocked_claim, true, 6);
        try appendJsonStringProperty(allocator, &output, "agent_guidance", check.agent_guidance, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < boundaryChecks().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"remaining_evidence_gaps\": [\n");
    for (remainingEvidenceGaps(), 0..) |gap, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", gap.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "status", gap.status, true, 6);
        try appendJsonStringProperty(allocator, &output, "reason", gap.reason, true, 6);
        try appendJsonStringProperty(allocator, &output, "recommended_branch", gap.recommended_branch, true, 6);
        try appendJsonStringProperty(allocator, &output, "blocked_until", gap.blocked_until, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < remainingEvidenceGaps().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"negative_audit_fixtures\": [\n");
    for (negativeAuditFixtures(), 0..) |fixture, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", fixture.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "attempted_claim", fixture.attempted_claim, true, 6);
        try appendJsonStringProperty(allocator, &output, "decision", fixture.decision, true, 6);
        try appendJsonStringProperty(allocator, &output, "reason", fixture.reason, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < negativeAuditFixtures().len) try output.append(allocator, ',');
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
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatProductionHardeningCompletionAuditText(init.gpa),
        .json => try formatProductionHardeningCompletionAuditJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-hardening-completion-audit error: {s}\n{s}", .{ @errorName(err), usage() });
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

fn hasMilestone(id: []const u8) bool {
    for (milestoneChecks()) |check| {
        if (std.mem.eql(u8, check.id, id)) return true;
    }
    return false;
}

fn hasMilestoneStatus(id: []const u8, status: []const u8) bool {
    for (milestoneChecks()) |check| {
        if (std.mem.eql(u8, check.id, id) and std.mem.eql(u8, check.status, status)) return true;
    }
    return false;
}

fn hasBoundary(id: []const u8) bool {
    for (boundaryChecks()) |check| {
        if (std.mem.eql(u8, check.id, id)) return true;
    }
    return false;
}

fn hasRemainingGap(id: []const u8, status: []const u8) bool {
    for (remainingEvidenceGaps()) |gap| {
        if (std.mem.eql(u8, gap.id, id) and std.mem.eql(u8, gap.status, status)) return true;
    }
    return false;
}

fn hasNegativeFixture(id: []const u8) bool {
    for (negativeAuditFixtures()) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

test "production hardening completion audit usage names command and formats" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-production-hardening-completion-audit") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--format text|json") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.production-hardening-completion-audit.v1", production_hardening_completion_audit_schema);
    try std.testing.expectEqualStrings("start-load-test-observation-harness", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-load-test-observation-harness", next_branch);
}

test "production hardening completion audit parses format options" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-production-hardening-completion-audit"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-production-hardening-completion-audit", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-production-hardening-completion-audit", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-production-hardening-completion-audit", "--format", "yaml" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-production-hardening-completion-audit", "--json" }));
}

test "production hardening completion audit covers current backlog dependency milestones" {
    try std.testing.expectEqual(@as(usize, 16), milestoneChecks().len);
    try std.testing.expect(hasMilestone("production-artifact-aggregation"));
    try std.testing.expect(hasMilestone("durable-production-retention"));
    try std.testing.expect(hasMilestone("production-deployment-runbooks"));
    try std.testing.expect(hasMilestone("artifact-access-control"));
    try std.testing.expect(hasMilestone("unified-causal-spine-contract"));
    try std.testing.expect(hasMilestone("deep-runtime-internals"));
    try std.testing.expect(hasMilestone("app-semantic-trace-api"));
    try std.testing.expect(hasMilestoneStatus("agent-query-interface", "partial"));
    try std.testing.expect(hasMilestone("encryption-at-rest-policy"));
    try std.testing.expect(hasMilestone("alerting-integrations"));
    try std.testing.expect(hasMilestone("live-dashboard-streaming-workbench"));
    try std.testing.expect(hasMilestone("workbench-graph-visual-debugging"));
    try std.testing.expect(hasMilestone("human-agent-feedback-loop"));
    try std.testing.expect(hasMilestone("rollout-automation-guardrails"));
    try std.testing.expect(hasMilestone("wall-clock-benchmark-baselines"));
    try std.testing.expect(hasMilestone("production-capacity-planning"));
}

test "production hardening completion audit covers authority and direction boundaries" {
    try std.testing.expect(hasBoundary("record-only-authority"));
    try std.testing.expect(hasBoundary("mutation-authority-none"));
    try std.testing.expect(hasBoundary("nendb-only-durable-direction"));
    try std.testing.expect(hasBoundary("solidjs-webui-workbench-direction"));
    try std.testing.expect(hasBoundary("capacity-planning-non-claim"));
    try std.testing.expect(hasBoundary("wall-clock-advisory-only"));
    try std.testing.expect(hasBoundary("alerting-and-rollout-preview-only"));
    try std.testing.expect(hasBoundary("access-control-policy-only"));
    try std.testing.expect(hasBoundary("encryption-policy-only"));
    try std.testing.expect(hasBoundary("agent-query-bounded-read-only"));
    try std.testing.expect(hasBoundary("production-telemetry-absent"));
}

test "production hardening completion audit identifies remaining evidence gaps" {
    try std.testing.expect(hasRemainingGap("load-test-observation-harness", "recommended-next"));
    try std.testing.expect(hasRemainingGap("production-telemetry-capture-design", "future"));
    try std.testing.expect(hasRemainingGap("reviewed-production-capacity-sizing", "future"));
    try std.testing.expect(hasRemainingGap("live-alert-delivery", "future"));
    try std.testing.expect(hasRemainingGap("live-rollout-automation", "future"));
    try std.testing.expect(hasRemainingGap("live-rbac-enforcement", "future"));
    try std.testing.expect(hasRemainingGap("encryption-implementation", "future"));
    try std.testing.expect(hasRemainingGap("production-dashboard-hosting", "future"));
    try std.testing.expect(hasRemainingGap("agent-query-cross-run-comparison", "future"));
    try std.testing.expect(hasRemainingGap("nendb-durable-history-hardening", "future"));
}

test "production hardening completion audit negative fixtures block over-claiming" {
    try std.testing.expect(hasNegativeFixture("contract-reports-as-production-ready"));
    try std.testing.expect(hasNegativeFixture("capacity-plan-as-capacity-claim"));
    try std.testing.expect(hasNegativeFixture("cockroach-or-non-nendb-adapter"));
    try std.testing.expect(hasNegativeFixture("react-or-alternate-renderer"));
    try std.testing.expect(hasNegativeFixture("alert-preview-as-sent-alert"));
    try std.testing.expect(hasNegativeFixture("rollout-guardrail-as-traffic-shift"));
    try std.testing.expect(hasNegativeFixture("access-policy-as-live-rbac"));
    try std.testing.expect(hasNegativeFixture("encryption-policy-as-encrypted-bytes"));
    try std.testing.expect(hasNegativeFixture("wall-clock-baseline-as-ci-gate"));
    try std.testing.expect(hasNegativeFixture("completion-audit-as-mutation-authority"));
}

test "production hardening completion audit text report explains handoff boundary" {
    const report = try formatProductionHardeningCompletionAuditText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "production hardening completion audit") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "record-only") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation authority: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, recommendation) != null);
    try std.testing.expect(std.mem.indexOf(u8, report, next_branch) != null);
}

test "production hardening completion audit json report is machine readable" {
    const report = try formatProductionHardeningCompletionAuditJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-hardening-completion-audit.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"milestone_checks\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"boundary_checks\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"remaining_evidence_gaps\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"next_branch\": \"codex/zigeffect-causal-load-test-observation-harness\"") != null);
}
