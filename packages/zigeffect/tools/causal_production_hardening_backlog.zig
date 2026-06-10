const std = @import("std");

pub const production_hardening_backlog_schema = "zigeffect.causal.production-hardening-backlog.v1";
pub const production_hardening_backlog_schema_version: u32 = 1;
pub const recommendation = "start-human-agent-feedback-loop";
pub const recommended_next_branch = "codex/zigeffect-causal-human-agent-feedback-loop";

const OutputFormat = enum { text, json };

const generated_by = "causal-production-hardening-backlog";

const BacklogItem = struct {
    id: []const u8,
    title: []const u8,
    gap_id: []const u8,
    priority: []const u8,
    status: []const u8,
    summary: []const u8,
    depends_on: []const []const u8,
    deliverables: []const []const u8,
    evidence_sources: []const []const u8,
    branch: []const u8,
    agent_guidance: []const u8,
};

const global_constraints: []const []const u8 = &.{
    "durable storage direction: NenDB adapter only",
    "workbench direction: SolidJS inside webui-dev/zig-webui",
    "visual graph adapter starts with @dschz/solid-g6 over @antv/g6; solid-flow remains optional editor research",
    "human workbench and agent query interface share one causal truth model but expose separate ergonomics",
    "mutation authority remains none until a reviewed authority branch grants it",
    "report is deterministic and must not inspect live systems, clocks, networks, or generated artifacts",
};

const non_goals: []const []const u8 = &.{
    "Cockroach adapter work",
    "React workbench support",
    "production mutation authority",
    "live production telemetry ingestion",
    "deployment or rollout automation",
    "RBAC enforcement",
    "encryption implementation",
};

const backlog_items: []const BacklogItem = &.{
    .{
        .id = "production-artifact-aggregation",
        .title = "Production Artifact Aggregation Contract",
        .gap_id = "distributed-artifact-aggregation",
        .priority = "P0",
        .status = "delivered",
        .summary = "Defines artifact bundle, source provenance, privacy review, and aggregation contracts before durable stores or dashboards consume production evidence.",
        .depends_on = &.{"m9-completion-audit"},
        .deliverables = &.{
            "aggregation bundle schema",
            "source provenance fields",
            "privacy and redaction review gate",
            "local fixture for multi-source artifact bundles",
        },
        .evidence_sources = &.{
            "packages/zigeffect/docs/m9-completion-audit.md",
            "packages/zigeffect/docs/operations.md",
        },
        .branch = "codex/zigeffect-causal-production-artifact-aggregation",
        .agent_guidance = "Use causal-production-artifact-aggregation before durable retention; do not write production stores or grant mutation authority.",
    },
    .{
        .id = "durable-production-retention",
        .title = "Durable Production Retention",
        .gap_id = "durable-production-retention",
        .priority = "P1",
        .status = "delivered",
        .summary = "Defines NenDB-backed durable retention policy, TTL, compaction, backup, recovery, and verification fixture contracts for aggregated causal artifacts.",
        .depends_on = &.{"production-artifact-aggregation"},
        .deliverables = &.{
            "NenDB adapter retention contract",
            "TTL and compaction policy",
            "backup and recovery expectations",
            "durable retention verification fixture",
        },
        .evidence_sources = &.{
            "packages/zigeffect/docs/agent-observable-runtime.md",
            "packages/zigeffect/src/services/causal_nendb_storage_backend.zig",
            "packages/zigeffect/docs/m9-completion-audit.md",
        },
        .branch = "codex/zigeffect-causal-durable-production-retention",
        .agent_guidance = "Use causal-durable-production-retention before deployment runbooks; durable writes remain NenDB adapter work only.",
    },
    .{
        .id = "production-deployment-runbooks",
        .title = "Production Deployment Runbooks",
        .gap_id = "production-deployment-runbooks",
        .priority = "P1",
        .status = "delivered",
        .summary = "Creates reviewed deploy, rollback, verification, and incident-response runbook contracts for causal-instrumented production services.",
        .depends_on = &.{ "production-artifact-aggregation", "durable-production-retention" },
        .deliverables = &.{
            "deployment checklist",
            "rollback checklist",
            "causal verification gate list",
            "incident response template",
        },
        .evidence_sources = &.{
            "packages/zigeffect/tools/causal_production_deployment_runbooks.zig",
            "packages/zigeffect/docs/production-deployment-runbooks.md",
            "packages/zigeffect/docs/operations.md",
            "packages/zigeffect/docs/durable-production-retention.md",
        },
        .branch = "codex/zigeffect-causal-production-deployment-runbooks",
        .agent_guidance = "Document manual gates first; do not automate deployment or rollback mutation.",
    },
    .{
        .id = "artifact-access-control",
        .title = "Artifact Access Control",
        .gap_id = "rbac-access-control",
        .priority = "P2",
        .status = "delivered",
        .summary = "Defines record-only access-control rules, visibility classes, permissions, audit records, and denied-view fixtures for artifact bundles and workbench views before production sharing.",
        .depends_on = &.{ "production-artifact-aggregation", "durable-production-retention", "production-deployment-runbooks" },
        .deliverables = &.{
            "artifact visibility model",
            "role and permission matrix",
            "access audit record schema",
            "negative tests for denied artifact views",
        },
        .evidence_sources = &.{
            "packages/zigeffect/tools/causal_artifact_access_control.zig",
            "packages/zigeffect/docs/artifact-access-control.md",
            "packages/zigeffect/docs/operations.md",
            "packages/zigeffect/docs/production-deployment-runbooks.md",
        },
        .branch = "codex/zigeffect-causal-artifact-access-control",
        .agent_guidance = "Keep this as policy and tests until a reviewed production host exists.",
    },
    .{
        .id = "unified-causal-spine-contract",
        .title = "Unified Causal Spine Contract",
        .gap_id = "dual-interface-causal-spine",
        .priority = "P2",
        .status = "delivered",
        .summary = "Define one stable causal truth model for runtime internals, app semantic events, human workbench views, agent queries, and durable NenDB graph records.",
        .depends_on = &.{ "production-artifact-aggregation", "durable-production-retention", "artifact-access-control" },
        .deliverables = &.{
            "canonical runtime id fields",
            "canonical app semantic id fields",
            "relationship taxonomy",
            "redaction sampling retention projection boundary",
            "derived index contract",
        },
        .evidence_sources = &.{
            "packages/zigeffect/tools/causal_unified_spine_contract.zig",
            "packages/zigeffect/docs/unified-spine-contract.md",
            "packages/zigeffect/docs/agent-observable-runtime.md",
            "packages/zigeffect/docs/schema-governance.md",
            "packages/zigeffect/docs/production-hardening-backlog.md",
        },
        .branch = "codex/zigeffect-causal-unified-spine-contract",
        .agent_guidance = "Make CausalStore append-only and keep policy plus derived indexes between the store and every human, agent, backend, or UI projection.",
    },
    .{
        .id = "deep-runtime-internals",
        .title = "Deep Runtime Internals",
        .gap_id = "runtime-internal-causal-depth",
        .priority = "P2",
        .status = "delivered",
        .summary = "Emit deeper zigeffect runtime facts for layers, services, scopes, fibers, resources, finalizers, retries, defects, interruptions, and cause chains.",
        .depends_on = &.{"unified-causal-spine-contract"},
        .deliverables = &.{
            "layer and service graph events",
            "scope and finalizer lifecycle events",
            "fiber fork join interrupt lifecycle events",
            "resource ownership events",
            "runtime topology fixture",
        },
        .evidence_sources = &.{
            "packages/zigeffect/src/runtime",
            "packages/zigeffect/src/core/scope.zig",
            "packages/zigeffect/src/core/fiber.zig",
            "packages/zigeffect/docs/agent-observable-runtime.md",
        },
        .branch = "codex/zigeffect-causal-deep-runtime-internals",
        .agent_guidance = "Prefer typed runtime facts and stable ids over verbose event labels; do not record raw payloads or secrets.",
    },
    .{
        .id = "app-semantic-trace-api",
        .title = "App Semantic Trace API",
        .gap_id = "app-semantic-lineage",
        .priority = "P2",
        .status = "delivered",
        .summary = "Expose an app-facing semantic trace API for data movement, service calls, domain actions, policy decisions, artifacts, and responses.",
        .depends_on = &.{"unified-causal-spine-contract"},
        .deliverables = &.{
            "data_read data_transformed data_written events",
            "function_boundary and service_call events",
            "domain_action policy_decision artifact_emitted response_sent events",
            "data_subject_ref and schema_ref guidance",
            "Worker request and background job fixtures",
        },
        .evidence_sources = &.{
            "packages/zigeffect/docs/agent-observable-runtime.md",
            "packages/zigeffect/docs/operations.md",
            "packages/zigeffect/docs/agent-guide.md",
        },
        .branch = "codex/zigeffect-causal-app-semantic-trace-api",
        .agent_guidance = "Record semantic references and lineage, not raw request bodies, headers, prompts, credentials, or PII.",
    },
    .{
        .id = "agent-query-interface",
        .title = "Agent Query Interface",
        .gap_id = "machine-native-causal-queries",
        .priority = "P2",
        .status = "partial",
        .summary = "Expose compact bounded agent queries over the unified spine while preserving evidence ids, redaction state, truncation state, confidence, and next-query hints. Runtime query JSON and app semantic trace_data are delivered; cross-run comparison remains future work.",
        .depends_on = &.{ "unified-causal-spine-contract", "deep-runtime-internals", "app-semantic-trace-api" },
        .deliverables = &.{
            "runtime summarize_run query",
            "runtime find_failures query",
            "runtime explain_event query",
            "runtime trace_cause query",
            "runtime list_findings and next_queries queries",
            "bounded runtime response schema",
            "app trace_data query",
            "future compare_runs query",
        },
        .evidence_sources = &.{
            "packages/zigeffect/tools/causal_query.zig",
            "packages/zigeffect/docs/agent-observable-runtime.md",
            "packages/zigeffect/docs/schema-governance.md",
        },
        .branch = "codex/zigeffect-causal-agent-query-interface",
        .agent_guidance = "Agents need concise schema-stable evidence slices, not human-oriented visual graphs.",
    },
    .{
        .id = "encryption-at-rest-policy",
        .title = "Encryption At Rest Policy",
        .gap_id = "encryption-at-rest-policy",
        .priority = "P2",
        .status = "delivered",
        .summary = "Defines record-only encryption-at-rest policy, key ownership, rotation evidence, encrypted artifact fixture metadata, and redaction ordering for retained causal artifacts.",
        .depends_on = &.{"durable-production-retention"},
        .deliverables = &.{
            "encryption policy document",
            "key ownership and rotation model",
            "encrypted artifact fixture contract",
            "redaction interaction review",
        },
        .evidence_sources = &.{
            "packages/zigeffect/tools/causal_encryption_at_rest_policy.zig",
            "packages/zigeffect/docs/encryption-at-rest-policy.md",
            "packages/zigeffect/docs/schema-governance.md",
        },
        .branch = "codex/zigeffect-causal-encryption-at-rest-policy",
        .agent_guidance = "Define policy and tests before implementing encrypted durable writes.",
    },
    .{
        .id = "alerting-integrations",
        .title = "Alerting And Integrations",
        .gap_id = "alerting-paging-integrations",
        .priority = "P3",
        .status = "delivered",
        .summary = "Defines record-only alerting and external integration event contracts, severity routing, escalation gates, preview fixtures, and negative fixtures for Slack, Linear, Jira, SIEM, and paging handoff.",
        .depends_on = &.{ "production-artifact-aggregation", "production-deployment-runbooks" },
        .deliverables = &.{
            "integration event contract",
            "record-only Slack Linear Jira SIEM and paging fixtures",
            "SIEM forwarding contract",
            "alert escalation policy",
        },
        .evidence_sources = &.{
            "packages/zigeffect/tools/causal_alerting_integrations.zig",
            "packages/zigeffect/docs/alerting-integrations.md",
            "packages/zigeffect/docs/schema-governance.md",
        },
        .branch = "codex/zigeffect-causal-alerting-integrations",
        .agent_guidance = "Use causal-alerting-integrations before live dashboard work; previews only and no messages tickets SIEM events or pages are sent.",
    },
    .{
        .id = "live-dashboard-streaming-workbench",
        .title = "Live Dashboard And Streaming Workbench",
        .gap_id = "live-dashboards-streaming-workbench",
        .priority = "P3",
        .status = "delivered",
        .summary = "Adds a record-only live dashboard stream contract, bounded local stream fixture, read-only SolidJS workbench dashboard, and first Solid G6 visual graph adapter boundary.",
        .depends_on = &.{ "production-artifact-aggregation", "durable-production-retention", "artifact-access-control", "unified-causal-spine-contract" },
        .deliverables = &.{
            "streaming artifact protocol",
            "read-only dashboard view",
            "bounded live-update fixture",
            "Solid G6 graph adapter boundary",
            "Visual Graph tab backed by the causal graph model",
            "dagre force and radial layout fixture",
            "SolidJS workbench verification",
        },
        .evidence_sources = &.{
            "packages/zigeffect/tools/causal_live_dashboard_streaming_workbench.zig",
            "packages/zigeffect/docs/live-dashboard-streaming-workbench.md",
            "packages/zigeffect/workbench/src/App.tsx",
            "packages/zigeffect/workbench/src/causalArtifact.ts",
            "packages/zigeffect/workbench/src/visualGraphAdapter.tsx",
            "packages/zigeffect/docs/operations.md",
            "packages/zigeffect/docs/performance-budget.md",
        },
        .branch = "codex/zigeffect-causal-live-dashboard-streaming-workbench",
        .agent_guidance = "Use the delivered stream contract and Live or Visual Graph tabs for bounded local evidence; next deepen graph layouts and browser/canvas verification.",
    },
    .{
        .id = "workbench-graph-visual-debugging",
        .title = "Workbench Graph Visual Debugging",
        .gap_id = "solid-workbench-graph-visual-debugging",
        .priority = "P3",
        .status = "delivered",
        .summary = "Deepens the read-only graph visualization layer with cause, topology, ownership, and lineage perspectives for causal traces, runtime internals, resource ownership, and app semantic refs.",
        .depends_on = &.{ "live-dashboard-streaming-workbench", "deep-runtime-internals", "app-semantic-trace-api" },
        .deliverables = &.{
            "graph visualization dependency decision record",
            "SolidJS G6 adapter boundary",
            "dagre or hierarchical cause-chain layout",
            "force runtime topology layout",
            "radial scope fiber and resource ownership layout",
            "cause, topology, ownership, and data-lineage perspectives",
            "visual graph debugging fixture selected by ?sample=visual-graph",
            "graph timeline and finding selection sync",
            "browser screenshot and canvas-render verification",
            "solid-flow applicability decision for later editable remediation planning",
        },
        .evidence_sources = &.{
            "packages/zigeffect/workbench/src/App.tsx",
            "packages/zigeffect/workbench/src/causalArtifact.ts",
            "packages/zigeffect/workbench/src/visualGraphAdapter.tsx",
            "packages/zigeffect/workbench/src/causalArtifact.test.ts",
            "packages/zigeffect/workbench/src/visualGraphAdapter.test.ts",
            "packages/zigeffect/workbench/src/visualGraphUi.test.ts",
            "packages/zigeffect/workbench/public/sample-visual-graph-debugging.json",
            "packages/zigeffect/workbench/src/styles.css",
            "package.json",
        },
        .branch = "codex/zigeffect-causal-workbench-graph-visual-debugging",
        .agent_guidance = "Use delivered Visual Graph cause topology ownership and lineage perspectives for read-only debugging; next connect human selections and agent queries in the feedback-loop branch while mutation authority remains none.",
    },
    .{
        .id = "human-agent-feedback-loop",
        .title = "Human And Agent Feedback Loop",
        .gap_id = "causal-self-improving-feedback-loop",
        .priority = "P3",
        .status = "planned",
        .summary = "Connect the human workbench and agent query interface into a self-improving development loop for zigeffect and apps built on it.",
        .depends_on = &.{ "agent-query-interface", "workbench-graph-visual-debugging", "durable-production-retention" },
        .deliverables = &.{
            "failure to query workflow",
            "before after trace comparison workflow",
            "regression clustering records",
            "guarded remediation proposal handoff",
            "durable history learning handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md",
            "packages/zigeffect/docs/agent-observable-runtime.md",
            "packages/zigeffect/docs/operations.md",
        },
        .branch = "codex/zigeffect-causal-human-agent-feedback-loop",
        .agent_guidance = "Close the loop with evidence and guarded proposals; do not grant autonomous mutation authority.",
    },
    .{
        .id = "rollout-automation-guardrails",
        .title = "Rollout Automation Guardrails",
        .gap_id = "gradual-rollout-automation",
        .priority = "P4",
        .status = "planned",
        .summary = "Define canary, gradual rollout, circuit-breaker, and rollback evidence records without granting automated mutation authority.",
        .depends_on = &.{ "production-deployment-runbooks", "alerting-integrations" },
        .deliverables = &.{
            "canary evidence record schema",
            "circuit-breaker decision artifact",
            "rollback readiness gate",
            "negative tests for unreviewed automation",
        },
        .evidence_sources = &.{
            "packages/zigeffect/docs/m9-completion-audit.md",
            "packages/zigeffect/tools/causal_app_application.zig",
        },
        .branch = "codex/zigeffect-causal-rollout-automation-guardrails",
        .agent_guidance = "Record rollout advice only; leave source, config, and deploy mutation authority at none.",
    },
    .{
        .id = "wall-clock-benchmark-baselines",
        .title = "Wall Clock Benchmark Baselines",
        .gap_id = "wall-clock-benchmark-gates",
        .priority = "P4",
        .status = "planned",
        .summary = "Add local and CI wall-clock benchmark baselines to complement the deterministic performance budget report.",
        .depends_on = &.{ "production-artifact-aggregation", "durable-production-retention" },
        .deliverables = &.{
            "benchmark harness",
            "request and background-job fixtures",
            "baseline artifact schema",
            "regression review gate",
        },
        .evidence_sources = &.{
            "packages/zigeffect/docs/performance-budget.md",
            "docs/roachgraph/performance-baseline.md",
        },
        .branch = "codex/zigeffect-causal-wall-clock-benchmark-baselines",
        .agent_guidance = "Keep wall-clock gates separate from deterministic budget constants.",
    },
    .{
        .id = "production-capacity-planning",
        .title = "Production Capacity Planning",
        .gap_id = "production-capacity-planning",
        .priority = "P5",
        .status = "planned",
        .summary = "Build capacity planning from real aggregation, retention, benchmark, dashboard, graph visualization, and integration evidence.",
        .depends_on = &.{ "production-artifact-aggregation", "durable-production-retention", "wall-clock-benchmark-baselines", "live-dashboard-streaming-workbench", "workbench-graph-visual-debugging", "agent-query-interface", "human-agent-feedback-loop" },
        .deliverables = &.{
            "capacity model",
            "load-test fixture plan",
            "storage growth assumptions",
            "workbench dashboard and graph concurrency assumptions",
        },
        .evidence_sources = &.{
            "packages/zigeffect/docs/m9-completion-audit.md",
            "packages/zigeffect/docs/performance-budget.md",
        },
        .branch = "codex/zigeffect-causal-production-capacity-planning",
        .agent_guidance = "Do not estimate capacity before real retention and benchmark evidence exists.",
    },
};

const dependency_order: []const []const u8 = &.{
    "production-artifact-aggregation",
    "durable-production-retention",
    "production-deployment-runbooks",
    "artifact-access-control",
    "unified-causal-spine-contract",
    "deep-runtime-internals",
    "app-semantic-trace-api",
    "agent-query-interface",
    "encryption-at-rest-policy",
    "alerting-integrations",
    "live-dashboard-streaming-workbench",
    "workbench-graph-visual-debugging",
    "human-agent-feedback-loop",
    "rollout-automation-guardrails",
    "wall-clock-benchmark-baselines",
    "production-capacity-planning",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig build causal-artifact-access-control",
    "zig build causal-artifact-access-control -- --format json",
    "zig build causal-encryption-at-rest-policy",
    "zig build causal-encryption-at-rest-policy -- --format json",
    "zig build causal-alerting-integrations",
    "zig build causal-alerting-integrations -- --format json",
    "zig build causal-live-dashboard-streaming-workbench",
    "zig build causal-live-dashboard-streaming-workbench -- --format json",
    "zig build causal-unified-spine-contract",
    "zig build causal-unified-spine-contract -- --format json",
    "zig build causal-production-deployment-runbooks",
    "zig build causal-production-deployment-runbooks -- --format json",
    "zig build causal-durable-production-retention",
    "zig build causal-durable-production-retention -- --format json",
    "zig build causal-production-artifact-aggregation",
    "zig build causal-production-artifact-aggregation -- --format json",
    "zig build causal-production-hardening-backlog",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build causal-schema-governance",
    "zig build causal-m9-completion-audit",
    "zig build examples",
    "zig build test",
    "cd ../..",
    "bun run check",
    "bun run zig:test",
    "git diff --check",
};

fn usage() []const u8 {
    return
    \\usage:
    \\  zig build causal-production-hardening-backlog
    \\  zig build causal-production-hardening-backlog -- --format text
    \\  zig build causal-production-hardening-backlog -- --format json
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

fn backlogItems() []const BacklogItem {
    return backlog_items;
}

fn globalConstraints() []const []const u8 {
    return global_constraints;
}

fn nonGoals() []const []const u8 {
    return non_goals;
}

fn dependencyOrder() []const []const u8 {
    return dependency_order;
}

fn verificationCommands() []const []const u8 {
    return verification_commands;
}

fn formatProductionHardeningBacklogText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal production hardening backlog\n");
    try output.print(allocator, "schema: {s}\n", .{production_hardening_backlog_schema});
    try output.print(allocator, "schema_version: {d}\n", .{production_hardening_backlog_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "recommended next branch: {s}\n\n", .{recommended_next_branch});

    try output.appendSlice(allocator, "global constraints:\n");
    for (globalConstraints()) |constraint| {
        try output.print(allocator, "- {s}\n", .{constraint});
    }

    try output.appendSlice(allocator, "\nnon-goals:\n");
    for (nonGoals()) |item| {
        try output.print(allocator, "- {s}\n", .{item});
    }

    try output.appendSlice(allocator, "\nbacklog items:\n");
    for (backlogItems()) |item| {
        try output.print(allocator, "- {s}: {s}\n", .{ item.id, item.title });
        try output.print(allocator, "  gap: {s}\n", .{item.gap_id});
        try output.print(allocator, "  priority: {s}\n", .{item.priority});
        try output.print(allocator, "  status: {s}\n", .{item.status});
        try output.print(allocator, "  branch: {s}\n", .{item.branch});
        try output.print(allocator, "  summary: {s}\n", .{item.summary});
        try output.appendSlice(allocator, "  depends on:");
        for (item.depends_on) |dependency| try output.print(allocator, " {s}", .{dependency});
        try output.append(allocator, '\n');
        try output.appendSlice(allocator, "  deliverables:");
        for (item.deliverables) |deliverable| try output.print(allocator, " {s};", .{deliverable});
        try output.append(allocator, '\n');
        try output.appendSlice(allocator, "  evidence sources:");
        for (item.evidence_sources) |source| try output.print(allocator, " {s};", .{source});
        try output.append(allocator, '\n');
        try output.print(allocator, "  agent guidance: {s}\n", .{item.agent_guidance});
    }

    try output.appendSlice(allocator, "\ndependency order:\n");
    for (dependencyOrder(), 0..) |id, index| {
        try output.print(allocator, "{d}. {s}\n", .{ index + 1, id });
    }

    try output.appendSlice(allocator, "\nverification commands:\n");
    for (verificationCommands()) |command| {
        try output.print(allocator, "- {s}\n", .{command});
    }

    return output.toOwnedSlice(allocator);
}

fn formatProductionHardeningBacklogJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, production_hardening_backlog_schema);
    try output.appendSlice(allocator, ",\n");
    try output.print(allocator, "  \"schema_version\": {d},\n", .{production_hardening_backlog_schema_version});
    try output.appendSlice(allocator, "  \"status\": \"current\",\n");
    try output.appendSlice(allocator, "  \"generated_by\": ");
    try appendJsonString(allocator, &output, generated_by);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"recommended_next_branch\": ");
    try appendJsonString(allocator, &output, recommended_next_branch);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"global_constraints\": ");
    try appendStringArray(allocator, &output, globalConstraints());
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"non_goals\": ");
    try appendStringArray(allocator, &output, nonGoals());
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"backlog_items\": [\n");
    for (backlogItems(), 0..) |item, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonProperty(allocator, &output, "id", item.id, true);
        try appendJsonProperty(allocator, &output, "title", item.title, true);
        try appendJsonProperty(allocator, &output, "gap_id", item.gap_id, true);
        try appendJsonProperty(allocator, &output, "priority", item.priority, true);
        try appendJsonProperty(allocator, &output, "status", item.status, true);
        try appendJsonProperty(allocator, &output, "summary", item.summary, true);
        try output.appendSlice(allocator, "      \"depends_on\": ");
        try appendStringArray(allocator, &output, item.depends_on);
        try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "      \"deliverables\": ");
        try appendStringArray(allocator, &output, item.deliverables);
        try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "      \"evidence_sources\": ");
        try appendStringArray(allocator, &output, item.evidence_sources);
        try output.appendSlice(allocator, ",\n");
        try appendJsonProperty(allocator, &output, "branch", item.branch, true);
        try appendJsonProperty(allocator, &output, "agent_guidance", item.agent_guidance, false);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < backlogItems().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");
    try output.appendSlice(allocator, "  \"dependency_order\": ");
    try appendStringArray(allocator, &output, dependencyOrder());
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
        .text => try formatProductionHardeningBacklogText(init.gpa),
        .json => try formatProductionHardeningBacklogJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-hardening-backlog error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn appendJsonProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: []const u8,
    comma: bool,
) !void {
    try output.appendSlice(allocator, "      ");
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

fn expectBacklogItem(id: []const u8) !void {
    for (backlogItems()) |item| {
        if (std.mem.eql(u8, item.id, id)) return;
    }
    return error.MissingBacklogItem;
}

fn expectBacklogItemStatus(id: []const u8, status: []const u8) !void {
    for (backlogItems()) |item| {
        if (std.mem.eql(u8, item.id, id)) {
            try std.testing.expectEqualStrings(status, item.status);
            return;
        }
    }
    return error.MissingBacklogItem;
}

fn expectConstraint(value: []const u8) !void {
    for (globalConstraints()) |constraint| {
        if (std.mem.eql(u8, constraint, value)) return;
    }
    return error.MissingConstraint;
}

fn expectNonGoal(value: []const u8) !void {
    for (nonGoals()) |item| {
        if (std.mem.eql(u8, item, value)) return;
    }
    return error.MissingNonGoal;
}

test "production hardening backlog constants preserve the branch boundary" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.production-hardening-backlog.v1",
        production_hardening_backlog_schema,
    );
    try std.testing.expectEqualStrings(
        "start-human-agent-feedback-loop",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-human-agent-feedback-loop",
        recommended_next_branch,
    );
}

test "production hardening backlog exposes branch-ready items" {
    try expectBacklogItem("production-artifact-aggregation");
    try expectBacklogItem("durable-production-retention");
    try expectBacklogItem("production-deployment-runbooks");
    try expectBacklogItem("artifact-access-control");
    try expectBacklogItem("unified-causal-spine-contract");
    try expectBacklogItem("deep-runtime-internals");
    try expectBacklogItem("app-semantic-trace-api");
    try expectBacklogItem("agent-query-interface");
    try expectBacklogItem("encryption-at-rest-policy");
    try expectBacklogItem("alerting-integrations");
    try expectBacklogItemStatus("alerting-integrations", "delivered");
    try expectBacklogItem("live-dashboard-streaming-workbench");
    try expectBacklogItemStatus("live-dashboard-streaming-workbench", "delivered");
    try expectBacklogItem("workbench-graph-visual-debugging");
    try expectBacklogItemStatus("workbench-graph-visual-debugging", "delivered");
    try expectBacklogItem("human-agent-feedback-loop");
    try expectBacklogItem("production-capacity-planning");
}

test "production hardening backlog preserves user constraints" {
    try expectConstraint("durable storage direction: NenDB adapter only");
    try expectConstraint("workbench direction: SolidJS inside webui-dev/zig-webui");
    try expectConstraint("visual graph adapter starts with @dschz/solid-g6 over @antv/g6; solid-flow remains optional editor research");
    try expectConstraint("human workbench and agent query interface share one causal truth model but expose separate ergonomics");
    try expectNonGoal("Cockroach adapter work");
    try expectNonGoal("React workbench support");
    try expectNonGoal("production mutation authority");
}

test "production hardening backlog text mentions dependency order and next branch" {
    const allocator = std.testing.allocator;
    const report = try formatProductionHardeningBacklogText(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.production-hardening-backlog.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "recommended next branch: codex/zigeffect-causal-human-agent-feedback-loop") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "dependency order:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-artifact-aggregation") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-deployment-runbooks") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "artifact-access-control") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "unified-causal-spine-contract") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "agent-query-interface") != null);
}

test "production hardening backlog JSON is agent-readable" {
    const allocator = std.testing.allocator;
    const report = try formatProductionHardeningBacklogJson(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-hardening-backlog.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"recommended_next_branch\": \"codex/zigeffect-causal-human-agent-feedback-loop\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"global_constraints\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"backlog_items\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"human-agent-feedback-loop\"") != null);
}

test "production hardening backlog parses supported formats" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-production-hardening-backlog"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--json" }));
}
