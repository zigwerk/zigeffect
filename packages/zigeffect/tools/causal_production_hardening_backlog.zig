const std = @import("std");

pub const production_hardening_backlog_schema = "zigeffect.causal.production-hardening-backlog.v1";
pub const production_hardening_backlog_schema_version: u32 = 1;
pub const recommendation = "start-app-facing-thirteen-level-application-boundary";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-thirteen-level-application-boundary";

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
    "non-NenDB durable adapter work",
    "alternate frontend renderer support",
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
        .status = "delivered",
        .summary = "Expose compact bounded agent queries over the unified spine while preserving evidence ids, redaction state, truncation state, confidence, and next-query hints. Runtime query JSON, app semantic trace_data, and bounded compare_runs are delivered.",
        .depends_on = &.{ "unified-causal-spine-contract", "deep-runtime-internals", "app-semantic-trace-api" },
        .deliverables = &.{
            "runtime summarize_run query",
            "runtime find_failures query",
            "runtime explain_event query",
            "runtime trace_cause query",
            "runtime list_findings and next_queries queries",
            "bounded runtime response schema",
            "app trace_data query",
            "bounded compare_runs query",
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
        .status = "delivered",
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
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-human-agent-feedback-loop-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-human-agent-feedback-loop-implementation.md",
            "packages/zigeffect/tools/causal_human_agent_feedback_loop.zig",
            "packages/zigeffect/docs/human-agent-feedback-loop.md",
            "packages/zigeffect/docs/agent-observable-runtime.md",
            "packages/zigeffect/docs/operations.md",
        },
        .branch = "codex/zigeffect-causal-human-agent-feedback-loop",
        .agent_guidance = "Use the delivered record-only loop to connect workbench selections, bounded queries, before/after comparisons, local regression clusters, guarded proposal handoffs, and future NenDB history handoff while mutation authority remains none.",
    },
    .{
        .id = "rollout-automation-guardrails",
        .title = "Rollout Automation Guardrails",
        .gap_id = "gradual-rollout-automation",
        .priority = "P4",
        .status = "delivered",
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
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-rollout-automation-guardrails-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-rollout-automation-guardrails-implementation.md",
            "packages/zigeffect/tools/causal_rollout_automation_guardrails.zig",
            "packages/zigeffect/docs/rollout-automation-guardrails.md",
            "packages/zigeffect/tools/causal_production_deployment_runbooks.zig",
            "packages/zigeffect/tools/causal_alerting_integrations.zig",
            "packages/zigeffect/tools/causal_human_agent_feedback_loop.zig",
            "packages/zigeffect/tools/causal_app_application_readiness.zig",
            "packages/zigeffect/tools/causal_app_apply.zig",
        },
        .branch = "codex/zigeffect-causal-rollout-automation-guardrails",
        .agent_guidance = "Use the delivered rollout guardrails report for canary evidence, progression gates, circuit-breaker decisions, rollback readiness, and negative automation fixtures; rollout execution remains external and mutation authority remains none.",
    },
    .{
        .id = "wall-clock-benchmark-baselines",
        .title = "Wall Clock Benchmark Baselines",
        .gap_id = "wall-clock-benchmark-gates",
        .priority = "P4",
        .status = "delivered",
        .summary = "Defines record-only local and CI wall-clock benchmark baseline contracts, environment metadata, calibration policy, advisory review gates, and agent guidance to complement deterministic performance budget constants.",
        .depends_on = &.{ "production-artifact-aggregation", "durable-production-retention" },
        .deliverables = &.{
            "benchmark scenario catalog",
            "request and background-job baseline families",
            "baseline artifact schema",
            "environment metadata contract",
            "calibration and noise policy",
            "advisory regression review gate",
            "capacity planning handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-wall-clock-benchmark-baselines-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-wall-clock-benchmark-baselines-implementation.md",
            "packages/zigeffect/tools/causal_wall_clock_benchmark_baselines.zig",
            "packages/zigeffect/docs/wall-clock-benchmark-baselines.md",
            "packages/zigeffect/docs/performance-budget.md",
            "docs/roachgraph/performance-baseline.md",
        },
        .branch = "codex/zigeffect-causal-wall-clock-benchmark-baselines",
        .agent_guidance = "Use causal-wall-clock-benchmark-baselines to compare only compatible local or CI timing evidence; keep all wall-clock deltas advisory until human review.",
    },
    .{
        .id = "production-capacity-planning",
        .title = "Production Capacity Planning",
        .gap_id = "production-capacity-planning",
        .priority = "P5",
        .status = "delivered",
        .summary = "Defines a record-only production capacity planning contract from aggregation, NenDB retention, wall-clock benchmark, dashboard stream, visual graph, agent query, feedback-loop, alerting, and rollout evidence without claiming measured production capacity.",
        .depends_on = &.{ "production-artifact-aggregation", "durable-production-retention", "wall-clock-benchmark-baselines", "live-dashboard-streaming-workbench", "workbench-graph-visual-debugging", "agent-query-interface", "human-agent-feedback-loop" },
        .deliverables = &.{
            "capacity model contract",
            "load-test fixture plan",
            "storage growth assumptions",
            "workbench dashboard and graph concurrency assumptions",
            "agent feedback alert and rollout handoff assumptions",
            "negative capacity fixtures",
            "completion-audit handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-capacity-planning-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-capacity-planning-implementation.md",
            "packages/zigeffect/tools/causal_production_capacity_planning.zig",
            "packages/zigeffect/docs/production-capacity-planning.md",
            "packages/zigeffect/docs/wall-clock-benchmark-baselines.md",
            "packages/zigeffect/docs/durable-production-retention.md",
            "packages/zigeffect/docs/production-hardening-backlog.md",
        },
        .branch = "codex/zigeffect-causal-production-capacity-planning",
        .agent_guidance = "Use causal-production-capacity-planning for formula-only capacity domains, storage assumptions, load-test fixture planning, concurrency assumptions, readiness gates, and negative capacity fixtures; do not claim production capacity or grant mutation authority.",
    },
    .{
        .id = "production-hardening-completion-audit",
        .title = "Production Hardening Completion Audit",
        .gap_id = "production-hardening-completion-audit",
        .priority = "P5",
        .status = "delivered",
        .summary = "Audits the delivered production-hardening report sequence, preserves record-only/NenDB/SolidJS boundaries, records remaining evidence gaps, and hands off to a local load-test observation harness.",
        .depends_on = &.{ "production-capacity-planning", "wall-clock-benchmark-baselines", "rollout-automation-guardrails", "human-agent-feedback-loop" },
        .deliverables = &.{
            "milestone completion checks",
            "authority and direction boundary checks",
            "remaining evidence gap inventory",
            "negative over-claim audit fixtures",
            "load-test observation harness handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-hardening-completion-audit-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-hardening-completion-audit-implementation.md",
            "packages/zigeffect/tools/causal_production_hardening_completion_audit.zig",
            "packages/zigeffect/docs/production-hardening-completion-audit.md",
            "packages/zigeffect/docs/production-capacity-planning.md",
            "packages/zigeffect/docs/production-hardening-backlog.md",
        },
        .branch = "codex/zigeffect-causal-production-hardening-completion-audit",
        .agent_guidance = "Use causal-production-hardening-completion-audit to close the static hardening sweep, cite remaining gaps explicitly, and start local observation work without claiming production capacity or mutation authority.",
    },
    .{
        .id = "load-test-observation-harness",
        .title = "Load-Test Observation Harness",
        .gap_id = "local-load-test-observation-harness",
        .priority = "P5",
        .status = "delivered",
        .summary = "Defines a schema-governed, record-only local observation harness that catalogs approved scenario families and can run bounded local observations without production load, live telemetry, capacity claims, shell execution, or mutation authority.",
        .depends_on = &.{ "production-hardening-completion-audit", "production-capacity-planning", "wall-clock-benchmark-baselines" },
        .deliverables = &.{
            "scenario catalog for app request background job artifact query comparison dev loop workbench and CI families",
            "bounded observe subcommand with curated argv arrays",
            "observation record schema with median p95 snippets and review gates",
            "negative fixtures for production load capacity telemetry arbitrary command CI gate environment adapter renderer and mutation over-claims",
            "production telemetry capture design handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-load-test-observation-harness-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-load-test-observation-harness-implementation.md",
            "packages/zigeffect/tools/causal_load_test_observation_harness.zig",
            "packages/zigeffect/docs/load-test-observation-harness.md",
            "packages/zigeffect/docs/production-hardening-completion-audit.md",
        },
        .branch = "codex/zigeffect-causal-load-test-observation-harness",
        .agent_guidance = "Use causal-load-test-observation-harness for local advisory observations only; keep production telemetry, load generation, capacity sizing, mutation authority, non-NenDB adapters, and alternate renderers out of scope.",
    },
    .{
        .id = "production-telemetry-capture-design",
        .title = "Production Telemetry Capture Design",
        .gap_id = "production-telemetry-capture-design",
        .priority = "P5",
        .status = "delivered",
        .summary = "Defines a schema-governed, design-only production telemetry capture contract with capture surfaces, field contracts, redaction, sampling, retention, access, encryption, OTel bridge gates, negative fixtures, and fixture handoff.",
        .depends_on = &.{ "load-test-observation-harness", "production-artifact-aggregation", "artifact-access-control", "encryption-at-rest-policy", "production-capacity-planning" },
        .deliverables = &.{
            "production telemetry capture surface catalog",
            "future telemetry field contract",
            "redaction sampling retention access encryption and OTel bridge readiness gates",
            "negative fixtures for live exporter raw payload capacity storage renderer CI and mutation over-claims",
            "production telemetry capture fixtures handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-capture-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-capture-design-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_capture_design.zig",
            "packages/zigeffect/docs/production-telemetry-capture-design.md",
            "packages/zigeffect/docs/load-test-observation-harness.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-capture-design",
        .agent_guidance = "Use causal-production-telemetry-capture-design to classify future telemetry fixture work; do not infer live ingestion, exporter enablement, durable production writes, capacity evidence, CI gates, non-NenDB adapters, alternate renderers, or mutation authority.",
    },
    .{
        .id = "production-telemetry-capture-fixtures",
        .title = "Production Telemetry Capture Fixtures",
        .gap_id = "production-telemetry-capture-fixtures",
        .priority = "P5",
        .status = "delivered",
        .summary = "Defines deterministic production telemetry capture fixture records, selected fixture output, validation checks, positive surface coverage, and negative over-claim fixtures without enabling live ingestion.",
        .depends_on = &.{ "production-telemetry-capture-design", "load-test-observation-harness", "artifact-access-control", "encryption-at-rest-policy" },
        .deliverables = &.{
            "positive fixtures for runtime trace app semantic backend export redaction access local observation and sampling boundaries",
            "negative fixtures for live exporter collector raw payload credential cardinality sampled-out capacity storage renderer CI and mutation over-claims",
            "selected fixture text and JSON output",
            "deterministic validation report for fixture field coverage and authority boundaries",
            "production telemetry readiness review handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-capture-fixtures-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-capture-fixtures-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_capture_fixtures.zig",
            "packages/zigeffect/docs/production-telemetry-capture-fixtures.md",
            "packages/zigeffect/docs/production-telemetry-capture-design.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-capture-fixtures",
        .agent_guidance = "Use causal-production-telemetry-capture-fixtures for safe example records and validation evidence; do not infer live telemetry, durable writes, CI gates, capacity evidence, non-NenDB adapters, alternate renderers, or mutation authority.",
    },
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
    .{
        .id = "production-telemetry-implementation-proposal",
        .title = "Production Telemetry Implementation Proposal",
        .gap_id = "production-telemetry-implementation-proposal",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes a ready telemetry readiness-review artifact and emits a proposal-only implementation sequence before exporter-boundary work.",
        .depends_on = &.{ "production-telemetry-readiness-review", "production-telemetry-capture-fixtures", "production-telemetry-capture-design" },
        .deliverables = &.{
            "readiness JSON proposal review",
            "approved and blocked proposal artifacts",
            "implementation phase plan",
            "exporter boundary handoff",
            "non-live authority checks",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-implementation-proposal-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-implementation-proposal-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_implementation_proposal.zig",
            "packages/zigeffect/docs/production-telemetry-implementation-proposal.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-implementation-proposal",
        .agent_guidance = "Use approved proposal artifacts to start the exporter-boundary branch only; do not infer live telemetry, durable writes, CI gates, non-NenDB adapters, alternate renderers, or mutation authority.",
    },
    .{
        .id = "production-telemetry-exporter-boundary",
        .title = "Production Telemetry Exporter Boundary",
        .gap_id = "production-telemetry-exporter-boundary",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes an approved production telemetry implementation proposal and emits a no-network exporter-boundary artifact before local pipeline fixtures.",
        .depends_on = &.{ "production-telemetry-implementation-proposal", "production-telemetry-readiness-review", "production-telemetry-capture-fixtures" },
        .deliverables = &.{
            "approved and blocked exporter boundary artifacts",
            "no-network exporter boundary contract",
            "local envelope fixture names",
            "proposal evidence checks",
            "local pipeline fixtures handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-exporter-boundary-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-exporter-boundary-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_exporter_boundary.zig",
            "packages/zigeffect/docs/production-telemetry-exporter-boundary.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-exporter-boundary",
        .agent_guidance = "Use approved exporter boundary artifacts to start local pipeline fixtures only; do not infer live telemetry, network send, collector configuration, OTLP serialization, durable writes, CI gates, non-NenDB adapters, alternate renderers, or mutation authority.",
    },
    .{
        .id = "production-telemetry-local-pipeline-fixtures",
        .title = "Production Telemetry Local Pipeline Fixtures",
        .gap_id = "production-telemetry-local-pipeline-fixtures",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes an approved exporter-boundary artifact and emits fixture-only local envelope redaction sampling and correlation evidence before NenDB retention fixtures.",
        .depends_on = &.{ "production-telemetry-exporter-boundary", "production-telemetry-implementation-proposal", "production-telemetry-readiness-review" },
        .deliverables = &.{
            "approved and blocked local pipeline fixture artifacts",
            "local envelope fixture catalog",
            "redaction and access fixture checks",
            "sampling fixture checks",
            "NenDB retention fixtures handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-local-pipeline-fixtures-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-local-pipeline-fixtures-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_local_pipeline_fixtures.zig",
            "packages/zigeffect/docs/production-telemetry-local-pipeline-fixtures.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures",
        .agent_guidance = "Use approved local pipeline fixture artifacts to start NenDB retention fixtures only; do not infer runtime telemetry ingestion, network send, collector configuration, OTLP serialization, durable writes, CI gates, non-NenDB adapters, alternate renderers, or mutation authority.",
    },
    .{
        .id = "production-telemetry-nendb-retention-fixtures",
        .title = "Production Telemetry NenDB Retention Fixtures",
        .gap_id = "production-telemetry-nendb-retention-fixtures",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes an approved local pipeline fixture artifact and emits fixture-only NenDB node edge retention compaction and backup recovery mapping evidence before the read-only workbench preview.",
        .depends_on = &.{ "production-telemetry-local-pipeline-fixtures", "durable-production-retention", "production-telemetry-exporter-boundary" },
        .deliverables = &.{
            "approved and blocked NenDB retention fixture artifacts",
            "NenDB node and edge mapping fixtures",
            "retention policy constant checks",
            "compaction and backup recovery markers",
            "workbench read-only preview handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-nendb-retention-fixtures-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-nendb-retention-fixtures-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_nendb_retention_fixtures.zig",
            "packages/zigeffect/docs/production-telemetry-nendb-retention-fixtures.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures",
        .agent_guidance = "Use approved NenDB retention fixture artifacts to start the read-only SolidJS/webui workbench preview only; do not infer runtime ingestion, network transport, OTLP serialization, NenDB writes, durable writes, non-NenDB adapters, alternate renderers, CI gates, or mutation authority.",
    },
    .{
        .id = "production-telemetry-workbench-readonly-preview",
        .title = "Production Telemetry Workbench Read-Only Preview",
        .gap_id = "production-telemetry-workbench-readonly-preview",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes ready NenDB retention fixture evidence, adds a read-only SolidJS/webui Telemetry tab and sample artifact, and emits a record-only workbench preview artifact before CI artifact preview work.",
        .depends_on = &.{ "production-telemetry-nendb-retention-fixtures", "workbench-graph-visual-debugging", "live-dashboard-streaming-workbench" },
        .deliverables = &.{
            "production telemetry workbench parser model",
            "development sample artifact for ?sample=production-telemetry",
            "read-only Telemetry tab with source authority checks mapping fixtures and verification evidence",
            "approved and blocked workbench preview artifacts",
            "CI artifact preview handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-workbench-readonly-preview-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-workbench-readonly-preview-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_workbench_readonly_preview.zig",
            "packages/zigeffect/docs/production-telemetry-workbench-readonly-preview.md",
            "packages/zigeffect/workbench/src/App.tsx",
            "packages/zigeffect/workbench/src/causalArtifact.ts",
            "packages/zigeffect/workbench/public/sample-production-telemetry-nendb-retention-fixtures.json",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-workbench-readonly-preview",
        .agent_guidance = "Use approved workbench preview artifacts to start CI artifact preview only; do not infer runtime ingestion, network transport, OTLP serialization, NenDB writes, durable writes, CI gates, hosted dashboard readiness, alternate renderers, or mutation authority.",
    },
    .{
        .id = "production-telemetry-ci-artifact-preview",
        .title = "Production Telemetry CI Artifact Preview",
        .gap_id = "production-telemetry-ci-artifact-preview",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes ready workbench preview artifacts and emits record-only CI archive candidate and upload policy preview evidence before any CI harness or gate work.",
        .depends_on = &.{ "production-telemetry-workbench-readonly-preview", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "approved and blocked CI artifact preview artifacts",
            "failure-only archive candidate catalog",
            "preview-only upload retention policy",
            "CI harness boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-artifact-preview-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-artifact-preview-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_artifact_preview.zig",
            "packages/zigeffect/docs/production-telemetry-ci-artifact-preview.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-artifact-preview",
        .agent_guidance = "Use approved CI artifact preview artifacts to start CI harness boundary work only; do not infer artifact upload execution, CI gates, runtime ingestion, network transport, OTLP serialization, NenDB writes, durable writes, hosted dashboard readiness, alternate renderers, or mutation authority.",
    },
    .{
        .id = "production-telemetry-ci-harness-boundary",
        .title = "Production Telemetry CI Harness Boundary",
        .gap_id = "production-telemetry-ci-harness-boundary",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes ready CI artifact preview evidence, inspects the existing causal GitHub Actions workflow, records clustering release-gate assumptions, and emits a record-only CI harness boundary before workflow mutation or gate work.",
        .depends_on = &.{ "production-telemetry-ci-artifact-preview", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "approved and blocked CI harness boundary artifacts",
            "existing causal workflow required-feature checks",
            "workflow prohibited-feature checks",
            "cluster release-gate assumptions",
            "archive application handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-harness-boundary-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-harness-boundary-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_harness_boundary.zig",
            "packages/zigeffect/docs/production-telemetry-ci-harness-boundary.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-harness-boundary",
        .agent_guidance = "Use approved CI harness boundary artifacts to start CI archive application work only; do not infer workflow mutation, artifact upload execution, CI gates, runtime ingestion, network transport, OTLP serialization, NenDB writes, durable writes, hosted dashboard readiness, alternate renderers, production cluster readiness, or mutation authority.",
    },
    .{
        .id = "production-telemetry-ci-archive-application",
        .title = "Production Telemetry CI Archive Application",
        .gap_id = "production-telemetry-ci-archive-application",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes ready CI harness boundary evidence and emits a guarded plan or record-applied archive application artifact that only sets applied=true with reviewed workflow-change before/after verification evidence.",
        .depends_on = &.{ "production-telemetry-ci-harness-boundary", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "planned and blocked CI archive application artifacts",
            "record-applied evidence gate",
            "before and after workflow evidence contract",
            "archive evidence policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-archive-application-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-archive-application-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_archive_application.zig",
            "packages/zigeffect/docs/production-telemetry-ci-archive-application.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-archive-application",
        .agent_guidance = "Use planned archive application artifacts to prepare reviewed workflow/archive patches only; use record-applied artifacts only when workflow changes before evidence after evidence and post-verification commands are present; do not infer CI gates live telemetry runtime ingestion durable writes NenDB writes hosted dashboard readiness production cluster readiness or mutation authority.",
    },
    .{
        .id = "production-telemetry-ci-archive-evidence-policy",
        .title = "Production Telemetry CI Archive Evidence Policy",
        .gap_id = "production-telemetry-ci-archive-evidence-policy",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes CI archive application evidence and defines allowed archive evidence classes, metadata requirements, interpretation rules, and negative fixtures before CI gate readiness work.",
        .depends_on = &.{ "production-telemetry-ci-archive-application", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "ready and blocked CI archive evidence policy artifacts",
            "archive evidence class catalog",
            "required provenance metadata contract",
            "interpretation and denied-claim rules",
            "CI gate readiness handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-archive-evidence-policy-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-archive-evidence-policy-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_archive_evidence_policy.zig",
            "packages/zigeffect/docs/production-telemetry-ci-archive-evidence-policy.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-archive-evidence-policy",
        .agent_guidance = "Use ready archive evidence policy artifacts to start CI gate readiness design only; archived CI evidence can support diagnosis and comparison but not production health capacity live telemetry coverage deployment success CI gates durable writes NenDB writes hosted dashboard readiness or mutation authority.",
    },
    .{
        .id = "production-telemetry-ci-gate-readiness",
        .title = "Production Telemetry CI Gate Readiness",
        .gap_id = "production-telemetry-ci-gate-readiness",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes ready CI archive evidence policy artifacts and records advisory gate readiness dimensions, candidate gate signals, gate semantics, and negative fixtures before any gate application boundary.",
        .depends_on = &.{ "production-telemetry-ci-archive-evidence-policy", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "ready and blocked CI gate readiness artifacts",
            "readiness dimension catalog",
            "advisory candidate gate signal catalog",
            "release-gate verification contract",
            "CI gate application boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-readiness-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-readiness-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_readiness.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-readiness.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-readiness",
        .agent_guidance = "Use ready CI gate readiness artifacts to start gate application boundary design only; candidate gate signals remain advisory and enforcement required checks workflow mutation live telemetry durable writes NenDB writes production cluster claims and mutation authority remain disabled.",
    },
    .{
        .id = "production-telemetry-ci-gate-application-boundary",
        .title = "Production Telemetry CI Gate Application Boundary",
        .gap_id = "production-telemetry-ci-gate-application-boundary",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes ready CI gate readiness artifacts and records planned, applied, or blocked CI gate application boundary evidence without enabling gate enforcement.",
        .depends_on = &.{ "production-telemetry-ci-gate-readiness", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "planned and blocked CI gate application boundary artifacts",
            "record-applied evidence gate",
            "after-workflow safety checks",
            "denied application claim catalog",
            "CI gate dry-run policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_application_boundary.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary",
        .agent_guidance = "Use planned gate application boundary artifacts to prepare CI gate dry-run policy work only; record-applied requires external reviewed workflow evidence plus before after and post-verification proof, and enforcement required checks workflow mutation live telemetry durable writes NenDB writes production cluster claims and mutation authority remain disabled.",
    },
    .{
        .id = "production-telemetry-ci-gate-dry-run-policy",
        .title = "Production Telemetry CI Gate Dry-Run Policy",
        .gap_id = "production-telemetry-ci-gate-dry-run-policy",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes reviewed CI gate application boundary artifacts and records advisory dry-run policy rules, candidate signal policies, evidence requirements, and negative fixtures before any evaluator work.",
        .depends_on = &.{ "production-telemetry-ci-gate-application-boundary", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "ready and blocked CI gate dry-run policy artifacts",
            "advisory candidate signal policy catalog",
            "bounded evidence requirement catalog",
            "negative dry-run policy fixtures",
            "CI gate dry-run evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-dry-run-policy-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-dry-run-policy-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_dry_run_policy.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-dry-run-policy.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-policy",
        .agent_guidance = "Use ready dry-run policy artifacts to start the evaluator branch only; evaluator findings remain advisory and enforcement required checks workflow mutation live telemetry durable writes NenDB writes production cluster claims and mutation authority remain disabled.",
    },
    .{
        .id = "production-telemetry-ci-gate-dry-run-evaluator",
        .title = "Production Telemetry CI Gate Dry-Run Evaluator",
        .gap_id = "production-telemetry-ci-gate-dry-run-evaluator",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes ready CI gate dry-run policy artifacts plus explicit bounded local or CI evidence files and records ready, advisory, or blocked evaluator findings before any CI report work.",
        .depends_on = &.{ "production-telemetry-ci-gate-dry-run-policy", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "ready advisory evaluator artifacts",
            "bounded explicit evidence classifier",
            "source dry-run policy validator",
            "advisory signal evaluation catalog",
            "denied evidence fixtures",
            "CI gate advisory CI report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-dry-run-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator",
        .agent_guidance = "Use ready or advisory dry-run evaluator artifacts to prepare advisory CI report work only; findings remain reviewer guidance and enforcement required checks workflow mutation live telemetry durable writes NenDB writes production cluster claims and mutation authority remain disabled.",
    },
    .{
        .id = "production-telemetry-ci-gate-advisory-ci-report",
        .title = "Production Telemetry CI Gate Advisory CI Report",
        .gap_id = "production-telemetry-ci-gate-advisory-ci-report",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes ready or advisory CI gate dry-run evaluator artifacts and renders local JSON/text reviewer guidance reports without publishing CI summaries, PR comments, uploads, or required checks.",
        .depends_on = &.{ "production-telemetry-ci-gate-dry-run-evaluator", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "ready advisory and blocked CI report artifacts",
            "record-only publication channel catalog",
            "source evaluator validation checks",
            "reviewer-facing signal and finding summaries",
            "CI report application boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-advisory-ci-report.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report",
        .agent_guidance = "Use local advisory CI report artifacts as reviewer guidance only; required checks workflow mutation step summary writes PR comments CI uploads live telemetry durable writes NenDB writes production cluster claims and mutation authority remain disabled until the report application boundary is explicitly reviewed.",
    },
    .{
        .id = "production-telemetry-ci-gate-advisory-ci-report-application-boundary",
        .title = "Production Telemetry CI Gate Advisory CI Report Application Boundary",
        .gap_id = "production-telemetry-ci-gate-advisory-ci-report-application-boundary",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes ready or advisory CI gate advisory report artifacts and records planned, applied, or blocked report publication boundary evidence without publishing reports, uploading artifacts, writing GitHub summaries, posting comments, or creating required checks.",
        .depends_on = &.{ "production-telemetry-ci-gate-advisory-ci-report", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "planned applied and blocked report application boundary artifacts",
            "reviewed publication change evidence gates",
            "before and after evidence gates",
            "safe report-after content checks",
            "CI report publication policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-advisory-ci-report-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary",
        .agent_guidance = "Use applied advisory CI report application boundary artifacts to prepare publication policy work only; report publication by the tool, required checks, workflow mutation, PR comments, step summary writes, CI uploads, live telemetry, durable writes, NenDB writes, production cluster claims, and mutation authority remain disabled.",
    },
    .{
        .id = "production-telemetry-ci-gate-advisory-ci-report-publication-policy",
        .title = "Production Telemetry CI Gate Advisory CI Report Publication Policy",
        .gap_id = "production-telemetry-ci-gate-advisory-ci-report-publication-policy",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes applied advisory CI report application-boundary artifacts and defines record-only interpretation policy for externally published advisory reports without creating required checks or enforcement.",
        .depends_on = &.{ "production-telemetry-ci-gate-advisory-ci-report-application-boundary", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "ready and blocked advisory CI report publication policy artifacts",
            "allowed interpretation rules",
            "denied inference rules",
            "publication surface policy",
            "required-status-check readiness handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-advisory-ci-report-publication-policy.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy",
        .agent_guidance = "Use ready advisory CI report publication policy artifacts to prepare required-status-check readiness work only; advisory reports remain non-blocking and report publication by the tool, enforcement, workflow mutation, PR comments, step summary writes, CI uploads, live telemetry, durable writes, NenDB writes, production cluster claims, and mutation authority remain disabled.",
    },
    .{
        .id = "production-telemetry-ci-gate-required-status-check-readiness",
        .title = "Production Telemetry CI Gate Required Status Check Readiness",
        .gap_id = "production-telemetry-ci-gate-required-status-check-readiness",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes ready advisory CI report publication-policy artifacts and defines record-only readiness for future required status check application-boundary work without enabling required checks, branch protection, workflow mutation, GitHub API mutation, or enforcement.",
        .depends_on = &.{ "production-telemetry-ci-gate-advisory-ci-report-publication-policy", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "ready and blocked required-status-check readiness artifacts",
            "candidate required-check profiles with activation disabled",
            "activation guardrails",
            "denied required-check and branch-protection inferences",
            "required-status-check application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_readiness.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-readiness.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness",
        .agent_guidance = "Use ready required-status-check readiness artifacts to prepare the application-boundary branch only; required checks, merge blocking, branch protection mutation, GitHub API mutation, workflow mutation, live telemetry, durable writes, NenDB writes, production cluster claims, and mutation authority remain disabled.",
    },
    .{
        .id = "production-telemetry-ci-gate-required-status-check-application-boundary",
        .title = "Production Telemetry CI Gate Required Status Check Application Boundary",
        .gap_id = "production-telemetry-ci-gate-required-status-check-application-boundary",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes ready required-status-check readiness artifacts and records planned or externally applied required-status-check application-boundary evidence without mutating GitHub branch protection, workflows, check runs, CI uploads, telemetry, storage, or runtime state.",
        .depends_on = &.{ "production-telemetry-ci-gate-required-status-check-readiness", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "planned and blocked required-status-check application-boundary artifacts",
            "record-applied evidence gate",
            "branch-protection before after evidence checks",
            "workflow or check-run evidence checks",
            "required-status-check policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary",
        .agent_guidance = "Use planned artifacts to prepare policy work only; use applied artifacts only when external reviewed branch-protection or check-run evidence plus before after verification exists; do not infer GitHub mutation by the tool, workflow mutation by the tool, CI upload execution by the tool, live telemetry, durable writes, NenDB writes, production cluster claims, or mutation authority.",
    },
    .{
        .id = "production-telemetry-ci-gate-required-status-check-policy",
        .title = "Production Telemetry CI Gate Required Status Check Policy",
        .gap_id = "production-telemetry-ci-gate-required-status-check-policy",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes planned or externally applied required-status-check application-boundary artifacts and defines record-only interpretation policy without mutating GitHub branch protection, workflows, check runs, CI uploads, telemetry, storage, or runtime state.",
        .depends_on = &.{ "production-telemetry-ci-gate-required-status-check-application-boundary", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "ready and blocked required-status-check policy artifacts",
            "planned versus applied source interpretation",
            "required-check surface policy",
            "denied merge-blocking and GitHub mutation inferences",
            "required-status-check enforcement-readiness handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-policy.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy",
        .agent_guidance = "Use ready required-status-check policy artifacts to prepare enforcement-readiness work only; policy readiness does not prove active merge blocking, GitHub mutation by the tool, workflow mutation by the tool, CI upload execution by the tool, live telemetry, durable writes, NenDB writes, production cluster claims, or mutation authority.",
    },
    .{
        .id = "production-telemetry-ci-gate-required-status-check-enforcement-readiness",
        .title = "Production Telemetry CI Gate Required Status Check Enforcement Readiness",
        .gap_id = "production-telemetry-ci-gate-required-status-check-enforcement-readiness",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes required-status-check policy artifacts and records whether externally applied policy evidence plus explicit enforcement evidence is ready for a future guarded enforcement application-boundary branch without mutating GitHub, workflows, branch protection, CI uploads, telemetry, storage, or runtime state.",
        .depends_on = &.{ "production-telemetry-ci-gate-required-status-check-policy", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "ready and blocked required-status-check enforcement-readiness artifacts",
            "applied-source-required readiness gate",
            "required check name and branch-protection evidence gates",
            "workflow or check-run evidence gates",
            "failure-mode owner-approval and rollback evidence gates",
            "denied active-enforcement and merge-blocking inferences",
            "required-status-check enforcement application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-readiness.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness",
        .agent_guidance = "Use ready required-status-check enforcement-readiness artifacts to prepare the enforcement application-boundary branch only; readiness does not prove active required checks, merge blocking, GitHub mutation by the tool, workflow mutation by the tool, CI upload execution by the tool, live telemetry, durable writes, NenDB writes, production cluster claims, or mutation authority.",
    },
    .{
        .id = "production-telemetry-ci-gate-required-status-check-enforcement-application-boundary",
        .title = "Production Telemetry CI Gate Required Status Check Enforcement Application Boundary",
        .gap_id = "production-telemetry-ci-gate-required-status-check-enforcement-application-boundary",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes ready required-status-check enforcement-readiness artifacts and records planned or externally applied active required-status-check enforcement evidence; applied=true only with reviewed branch-protection before after evidence, workflow or check-run evidence, failure-mode evidence, owner approval, rollback evidence, merge-blocking evidence when claimed, and verification.",
        .depends_on = &.{ "production-telemetry-ci-gate-required-status-check-enforcement-readiness", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "planned applied and blocked enforcement application-boundary artifacts",
            "applied external active required-check evidence gate",
            "merge-blocking evidence gate",
            "branch-protection before after evidence",
            "workflow or check-run evidence",
            "denied mutation-by-tool inferences",
            "required-status-check enforcement policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary",
        .agent_guidance = "Use ready applied artifacts to prepare enforcement policy work only; external enforcement evidence does not prove GitHub mutation by the tool, branch-protection mutation by the tool, workflow mutation by the tool, check-run creation by the tool, CI upload execution by the tool, live telemetry, durable writes, NenDB writes, production cluster claims, or mutation authority.",
    },
    .{
        .id = "production-telemetry-ci-gate-required-status-check-enforcement-policy",
        .title = "Production Telemetry CI Gate Required Status Check Enforcement Policy",
        .gap_id = "production-telemetry-ci-gate-required-status-check-enforcement-policy",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes planned or externally applied required-status-check enforcement application-boundary artifacts and defines record-only interpretation policy for active enforcement and merge-blocking evidence while denying tool mutation, live telemetry, production health, durable writes, NenDB writes, non-NenDB durable adapter work, and alternate renderer claims.",
        .depends_on = &.{ "production-telemetry-ci-gate-required-status-check-enforcement-application-boundary", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "ready or blocked enforcement policy artifacts",
            "planned enforcement interpretation policy",
            "externally applied active-enforcement interpretation policy",
            "merge-blocking evidence interpretation policy",
            "denied mutation and production inference fixtures",
            "required-status-check enforcement evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-policy.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy",
        .agent_guidance = "Use ready enforcement-policy artifacts to start the enforcement evaluator only; active enforcement and merge-blocker claims must cite source evidence and do not prove GitHub mutation by the tool, workflow mutation by the tool, check-run creation by the tool, CI upload execution by the tool, live telemetry, production health, durable writes, NenDB writes, non-NenDB durable adapters, alternate renderers, production cluster claims, or mutation authority.",
    },
    .{
        .id = "production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
        .title = "Production Telemetry CI Gate Required Status Check Enforcement Evaluator",
        .gap_id = "production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes ready required-status-check enforcement policy artifacts plus explicit bounded evidence files and emits ready, advisory, or blocked evaluator artifacts for active-enforcement and merge-blocking observations while preserving record-only authority.",
        .depends_on = &.{ "production-telemetry-ci-gate-required-status-check-enforcement-policy", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "ready advisory or blocked evaluator artifacts",
            "bounded explicit evidence classifier",
            "active enforcement evidence evaluation",
            "merge-blocking evidence evaluation",
            "denied mutation production storage and renderer fixtures",
            "required-status-check enforcement report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
        .agent_guidance = "Use ready or advisory evaluator artifacts to start the enforcement report only; do not infer tool mutation, production health, live telemetry, durable writes, NenDB writes, non-NenDB adapters, alternate renderers, production cluster readiness, or mutation authority.",
    },
    .{
        .id = "production-telemetry-ci-gate-required-status-check-enforcement-report",
        .title = "Production Telemetry CI Gate Required Status Check Enforcement Report",
        .gap_id = "production-telemetry-ci-gate-required-status-check-enforcement-report",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes required-status-check enforcement evaluator artifacts and emits local JSON/text reviewer reports that preserve ready, advisory, and blocked evaluator findings while keeping publication and required-status-check mutation disabled.",
        .depends_on = &.{ "production-telemetry-ci-gate-required-status-check-enforcement-evaluator", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "local JSON and text enforcement report artifacts",
            "ready advisory and blocked source summaries",
            "blocked finding preservation",
            "local-only publication channel catalog",
            "required-status-check enforcement report application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report",
        .agent_guidance = "Use report artifacts only for report application-boundary review; do not infer GitHub mutation, required status check creation, branch-protection mutation, workflow mutation, check-run creation, CI upload execution, step-summary writes, pull-request comments, live telemetry, durable writes, NenDB writes, non-NenDB adapters, alternate renderers, production cluster readiness, production health, or mutation authority.",
    },
    .{
        .id = "production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
        .title = "Production Telemetry CI Gate Required Status Check Enforcement Report Application Boundary",
        .gap_id = "production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes required-status-check enforcement report artifacts and emits guarded plan or record-applied application-boundary artifacts that only set applied=true with reviewed before/after evidence and verification commands.",
        .depends_on = &.{ "production-telemetry-ci-gate-required-status-check-enforcement-report", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "plan and record-applied application-boundary artifacts",
            "source report readiness and authority checks",
            "local after-report safety checks",
            "before and after evidence gate",
            "required-status-check enforcement report policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_application_boundary.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
        .agent_guidance = "Use applied report application-boundary artifacts only to start report policy work; applied=true requires external reviewed application change evidence, before evidence, after evidence, report-after content, and verification commands, and it still does not prove mutation by this tool, live telemetry, durable writes, NenDB writes, non-NenDB adapters, alternate renderers, production cluster readiness, production health, or mutation authority.",
    },
    .{
        .id = "production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
        .title = "Production Telemetry CI Gate Required Status Check Enforcement Report Policy",
        .gap_id = "production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
        .priority = "P5",
        .status = "delivered",
        .summary = "Consumes required-status-check enforcement report application-boundary artifacts and emits record-only interpretation policy artifacts for planned or externally applied report evidence.",
        .depends_on = &.{ "production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary", "artifact-access-control", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "planned and applied source interpretation policy",
            "published report policy readiness signal",
            "denied publication and mutation inference catalog",
            "local JSON and text policy artifacts",
            "production hardening backlog refresh handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy-implementation.md",
            "packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy.zig",
            "packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-report-policy.md",
        },
        .branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
        .agent_guidance = "Use report policy artifacts as interpretation evidence only. Planned sources can be policy-ready without published report readiness; applied sources can record published report policy readiness but still do not prove GitHub mutation by the tool, branch-protection mutation by the tool, workflow mutation by the tool, check-run creation by the tool, CI upload execution by the tool, step-summary writes, pull-request comments, live telemetry, durable writes, NenDB writes, non-NenDB adapters, alternate renderers, production cluster readiness, production health, or mutation authority.",
    },
    .{
        .id = "production-hardening-backlog-refresh",
        .title = "Production Hardening Backlog Refresh",
        .gap_id = "production-hardening-backlog-refresh",
        .priority = "P5",
        .status = "delivered",
        .summary = "Closes the delivered production-hardening queue, records unresolved candidates, and selects NenDB durable-history hardening as the next branch.",
        .depends_on = &.{"production-telemetry-ci-gate-required-status-check-enforcement-report-policy"},
        .deliverables = &.{
            "refresh artifact schema",
            "unresolved candidate catalog",
            "NenDB durable-history handoff",
            "denied production and mutation claims",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-production-hardening-backlog-refresh-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-production-hardening-backlog-refresh-implementation.md",
            "packages/zigeffect/tools/causal_production_hardening_backlog_refresh.zig",
            "packages/zigeffect/docs/production-hardening-backlog-refresh.md",
        },
        .branch = "codex/zigeffect-causal-production-hardening-backlog-refresh",
        .agent_guidance = "Use this refresh as a handoff artifact only. The selected next branch is NenDB durable-history hardening; do not infer production health, production cluster readiness, live telemetry, durable writes, NenDB writes, Cockroach scope, or mutation authority.",
    },
    .{
        .id = "nendb-durable-history-hardening",
        .title = "NenDB Durable History Hardening",
        .gap_id = "nendb-durable-history-hardening",
        .priority = "P0",
        .status = "delivered",
        .summary = "Hardens the NenDB causal storage adapter with runtime durable-history posture, deterministic local fixture evidence, and agent-readable schema governance.",
        .depends_on = &.{ "production-hardening-backlog-refresh", "causal-nendb-storage-backend", "production-telemetry-nendb-retention-fixtures" },
        .deliverables = &.{
            "runtime durable-history report",
            "local fixture tool",
            "query evidence checks",
            "redaction evidence checks",
            "NenDB-only authority boundary",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-10-zigeffect-causal-nendb-durable-history-hardening-design.md",
            "docs/superpowers/plans/2026-06-10-zigeffect-causal-nendb-durable-history-hardening-implementation.md",
            "packages/zigeffect/src/services/causal_nendb_storage_backend.zig",
            "packages/zigeffect/tools/causal_nendb_durable_history_hardening.zig",
            "packages/zigeffect/docs/nendb-durable-history-hardening.md",
        },
        .branch = "codex/zigeffect-causal-nendb-durable-history-hardening",
        .agent_guidance = "Use this as the durable-history evidence substrate for cross-run comparison. Do not infer production health, live telemetry, Cockroach scope, durable production writes, NenDB production write authority, or mutation authority.",
    },
    .{
        .id = "agent-query-cross-run-comparison",
        .title = "Agent Query Cross-Run Comparison",
        .gap_id = "agent-query-cross-run-comparison",
        .priority = "P0",
        .status = "delivered",
        .summary = "Adds bounded compare_runs support to causal-query --agent for same-artifact and cross-artifact run comparison inside zigeffect.causal.agent-query.v1.",
        .depends_on = &.{ "agent-query-interface", "nendb-durable-history-hardening" },
        .deliverables = &.{
            "same-artifact compare_runs query",
            "cross-artifact --compare-file query",
            "per-side event and finding deltas",
            "left/right artifact warnings and limitations",
            "cross-run next query hints",
            "audit-chain snapshot comparison handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-agent-query-compare-runs-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-agent-query-compare-runs-implementation.md",
            "packages/zigeffect/tools/causal_query.zig",
            "packages/zigeffect/docs/agent-observable-runtime.md",
            "packages/zigeffect/docs/schema-governance.md",
        },
        .branch = "codex/zigeffect-causal-agent-query-compare-runs",
        .agent_guidance = "Use compare_runs to inspect before/after run evidence and regression signatures. Do not infer remediation, source edits, registry updates, production writes, live telemetry, or mutation authority.",
    },
    .{
        .id = "audit-chain-snapshot-compare",
        .title = "Audit-Chain Snapshot Comparison",
        .gap_id = "audit-chain-snapshot-compare",
        .priority = "P0",
        .status = "delivered",
        .summary = "Adds read-only comparison for two named snapshot manifests whose retained artifacts are zigeffect.causal.audit-chain.v1 governance JSON.",
        .depends_on = &.{ "agent-query-cross-run-comparison", "nendb-durable-history-hardening" },
        .deliverables = &.{
            "audit-chain snapshot compare schema",
            "text and JSON formatters",
            "applied=true blocking guardrail",
            "snapshot manifest reference resolution",
            "agent next-query hints that avoid event-run query misuse",
            "app-facing production fixture handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-audit-chain-snapshot-compare-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-audit-chain-snapshot-compare-implementation.md",
            "packages/zigeffect/tools/causal_snapshot.zig",
            "packages/zigeffect/docs/agent-observable-runtime.md",
            "packages/zigeffect/docs/schema-governance.md",
        },
        .branch = "codex/zigeffect-causal-audit-chain-snapshot-compare",
        .agent_guidance = "Use audit-chain-compare to review retained before/after governance evidence. Do not feed audit-chain governance JSON to event-run query commands, and do not infer source edits, registry writes, app mutation, production writes, live telemetry, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-fixtures",
        .title = "App-Facing Production Integration Fixtures",
        .gap_id = "app-facing-production-integration-fixtures",
        .priority = "P1",
        .status = "delivered",
        .summary = "Adds deterministic fixture-only app production integration evidence across app runtime traces, agent queries, audit-chain comparison, app remediation governance, production telemetry fixture boundaries, and NenDB durable-history handoff.",
        .depends_on = &.{ "app-semantic-trace-api", "agent-query-interface", "agent-query-cross-run-comparison", "audit-chain-snapshot-compare", "nendb-durable-history-hardening", "production-telemetry-capture-fixtures" },
        .deliverables = &.{
            "app-facing production integration fixture schema",
            "source contract catalog",
            "request job agent-query audit remediation telemetry and NenDB positive fixtures",
            "negative fixture blocked claims",
            "validation report",
            "readiness-review handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-fixtures-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-fixtures-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_fixtures.zig",
            "packages/zigeffect/docs/app-facing-production-integration-fixtures.md",
            "packages/zigeffect/docs/agent-observable-runtime.md",
            "packages/zigeffect/docs/schema-governance.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-fixtures",
        .agent_guidance = "Use fixture ids source contracts validation checks and blocked claims when reasoning about app production evidence. Do not infer live telemetry, durable production writes, Cockroach scope, raw app payload capture, app mutation, CI gates, or alternate renderer work; route implementation authority through the readiness-review branch.",
    },
    .{
        .id = "app-facing-production-integration-readiness-review",
        .title = "App-Facing Production Integration Readiness Review",
        .gap_id = "app-facing-production-integration-readiness-review",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes app-facing production integration fixture JSON and emits ready or blocked readiness-review artifacts before any implementation-proposal work.",
        .depends_on = &.{ "app-facing-production-integration-fixtures", "agent-query-interface", "audit-chain-snapshot-compare", "nendb-durable-history-hardening", "production-telemetry-capture-fixtures" },
        .deliverables = &.{
            "fixture JSON readiness review",
            "reviewer decision and reason recording",
            "app mutation telemetry durable CI and renderer boundary checks",
            "NenDB-only durable direction checks",
            "implementation proposal handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-readiness-review-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-readiness-review-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_readiness_review.zig",
            "packages/zigeffect/docs/app-facing-production-integration-readiness-review.md",
            "packages/zigeffect/docs/app-facing-production-integration-fixtures.md",
            "packages/zigeffect/docs/schema-governance.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-readiness-review",
        .agent_guidance = "Use ready readiness-review artifacts to start an app-facing implementation-proposal branch only. Do not infer app mutation, live telemetry, durable production writes, Cockroach scope, CI gates, alternate renderer work, or applied=true from readiness evidence.",
    },
    .{
        .id = "app-facing-production-integration-implementation-proposal",
        .title = "App-Facing Production Integration Implementation Proposal",
        .gap_id = "app-facing-production-integration-implementation-proposal",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes a ready app-facing production integration readiness-review artifact and emits a proposal-only implementation sequence before guarded boundary work.",
        .depends_on = &.{ "app-facing-production-integration-readiness-review", "app-facing-production-integration-fixtures", "agent-query-interface", "audit-chain-snapshot-compare", "nendb-durable-history-hardening", "production-telemetry-capture-fixtures" },
        .deliverables = &.{
            "ready readiness-review artifact consumption",
            "proposal decision and reason recording",
            "app runtime and bounded agent-query phase plan",
            "NenDB-only durable handoff guardrails",
            "app mutation telemetry durable CI Cockroach and renderer blocked claims",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-implementation-proposal-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-implementation-proposal-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_implementation_proposal.zig",
            "packages/zigeffect/docs/app-facing-production-integration-implementation-proposal.md",
            "packages/zigeffect/docs/app-facing-production-integration-readiness-review.md",
            "packages/zigeffect/docs/schema-governance.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-implementation-proposal",
        .agent_guidance = "Use approved implementation proposal artifacts to start the guarded app-facing production integration boundary only. Do not infer app mutation, live telemetry, durable production writes, Cockroach scope, CI gates, alternate renderer work, raw payload capture, or applied=true from proposal evidence.",
    },
    .{
        .id = "app-facing-production-integration-boundary",
        .title = "App-Facing Production Integration Boundary",
        .gap_id = "app-facing-production-integration-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes an approved app-facing implementation-proposal artifact and emits a guarded boundary for app runtime refs, bounded agent-query projection, NenDB handoff, and SolidJS workbench direction without production mutation authority.",
        .depends_on = &.{ "app-facing-production-integration-implementation-proposal", "app-facing-production-integration-readiness-review", "app-facing-production-integration-fixtures", "agent-query-interface", "audit-chain-snapshot-compare", "nendb-durable-history-hardening" },
        .deliverables = &.{
            "approved implementation-proposal artifact consumption",
            "guarded app runtime reference-only boundary",
            "bounded agent-query projection boundary",
            "NenDB-only handoff without production writes",
            "audit remediation evidence-only bridge",
            "SolidJS webui read-only preview handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-boundary-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_boundary.zig",
            "packages/zigeffect/docs/app-facing-production-integration-boundary.md",
            "packages/zigeffect/docs/app-facing-production-integration-implementation-proposal.md",
            "packages/zigeffect/docs/schema-governance.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-boundary",
        .agent_guidance = "Use approved boundary artifacts to start local app-facing integration fixtures only. Do not infer app mutation, live telemetry, durable production writes, Cockroach scope, CI gates, alternate renderer work, raw payload capture, NenDB production writes, deployment mutation, or applied=true from boundary evidence.",
    },
    .{
        .id = "app-facing-production-integration-local-fixtures",
        .title = "App-Facing Production Integration Local Fixtures",
        .gap_id = "app-facing-production-integration-local-fixtures",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes an approved app-facing integration boundary and emits local fixture artifacts for app runtime refs, bounded agent-query projections, NenDB handoff refs, audit/remediation review links, SolidJS read-only preview handoff, and advisory CI artifact previews without production mutation authority.",
        .depends_on = &.{ "app-facing-production-integration-boundary", "app-facing-production-integration-implementation-proposal", "app-facing-production-integration-readiness-review", "app-facing-production-integration-fixtures", "agent-query-interface", "audit-chain-snapshot-compare", "nendb-durable-history-hardening" },
        .deliverables = &.{
            "worker request runtime ref fixture",
            "background job runtime ref fixture",
            "bounded agent query projection fixture",
            "NenDB history handoff ref fixture without writes",
            "audit/remediation review link fixture",
            "SolidJS webui read-only preview fixture",
            "advisory CI artifact preview fixture",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-local-fixtures-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-local-fixtures-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_local_fixtures.zig",
            "packages/zigeffect/docs/app-facing-production-integration-local-fixtures.md",
            "packages/zigeffect/docs/app-facing-production-integration-boundary.md",
            "packages/zigeffect/docs/schema-governance.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-local-fixtures",
        .agent_guidance = "Use ready local-fixtures artifacts to start app-facing NenDB handoff fixtures only. Do not infer app runtime integration, live agent projection, raw payload capture, app mutation, NenDB production writes, Cockroach scope, CI enforcement, alternate renderer work, deployment mutation, or applied=true from local fixture evidence.",
    },
    .{
        .id = "app-facing-production-integration-nendb-handoff-fixtures",
        .title = "App-Facing Production Integration NenDB Handoff Fixtures",
        .gap_id = "app-facing-production-integration-nendb-handoff-fixtures",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready app-facing local-fixtures evidence and emits record-only NenDB node and edge handoff fixtures for app runtime refs, bounded agent queries, audit/remediation review links, SolidJS read-only preview refs, and advisory CI artifact refs without production writes.",
        .depends_on = &.{ "app-facing-production-integration-local-fixtures", "app-facing-production-integration-boundary", "agent-query-interface", "audit-chain-snapshot-compare", "nendb-durable-history-hardening" },
        .deliverables = &.{
            "NenDB node handoff fixture catalog",
            "NenDB edge handoff fixture catalog",
            "source local-fixtures validation",
            "no-write adapter execution guardrails",
            "audit/remediation bridge handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig",
            "packages/zigeffect/docs/app-facing-production-integration-nendb-handoff-fixtures.md",
            "packages/zigeffect/docs/schema-governance.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures",
        .agent_guidance = "Use ready NenDB handoff fixture artifacts to start the app-facing audit/remediation bridge only. Do not infer NenDB adapter execution, NenDB production writes, app runtime integration, live agent projection, raw payload capture, app mutation, Cockroach scope, CI enforcement, deployment mutation, or applied=true.",
    },
    .{
        .id = "app-facing-production-integration-audit-remediation-bridge",
        .title = "App-Facing Production Integration Audit Remediation Bridge",
        .gap_id = "app-facing-production-integration-audit-remediation-bridge",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready app-facing NenDB handoff fixtures and emits a record-only audit/remediation bridge linking audit-chain comparison refs, remediation review refs, runtime evidence refs, agent-query next-query refs, SolidJS read-only preview refs, and advisory CI refs without app writes or auto-apply authority.",
        .depends_on = &.{ "app-facing-production-integration-nendb-handoff-fixtures", "app-facing-production-integration-local-fixtures", "audit-chain-snapshot-compare", "agent-query-interface", "nendb-durable-history-hardening" },
        .deliverables = &.{
            "audit-chain comparison review bridge",
            "remediation review policy gate bridge",
            "runtime-to-remediation evidence bridge",
            "agent-query-to-remediation next-query bridge",
            "SolidJS review preview bridge",
            "CI advisory remediation report bridge",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-audit-remediation-bridge-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-audit-remediation-bridge-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_audit_remediation_bridge.zig",
            "packages/zigeffect/docs/app-facing-production-integration-audit-remediation-bridge.md",
            "packages/zigeffect/docs/schema-governance.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge",
        .agent_guidance = "Use ready audit/remediation bridge artifacts to start the app-facing SolidJS read-only preview only. Do not infer app runtime integration, live agent projection, raw payload capture, app mutation, NenDB production writes, NenDB adapter execution, Cockroach scope, CI enforcement, deployment mutation, production health, mutation proof, auto-apply, or applied=true.",
    },
    .{
        .id = "app-facing-production-integration-solid-webui-readonly-preview",
        .title = "App-Facing Production Integration SolidJS Read-Only Preview",
        .gap_id = "app-facing-production-integration-solid-webui-readonly-preview",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready app-facing audit/remediation bridge artifacts and emits a read-only SolidJS preview model for the local webui-dev/zig-webui workbench, exposing authority boundaries, bridge records, preview sections, checks, blocked claims, and verification commands without app writes, live dashboard hosting, CI enforcement, NenDB writes, or adapter execution.",
        .depends_on = &.{ "app-facing-production-integration-audit-remediation-bridge", "app-facing-production-integration-nendb-handoff-fixtures", "agent-query-interface", "audit-chain-snapshot-compare" },
        .deliverables = &.{
            "SolidJS read-only preview schema",
            "preview producer and approved/rejected artifacts",
            "workbench app-preview tab",
            "webui-dev/zig-webui sample artifact",
            "authority and renderer guardrails",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig",
            "packages/zigeffect/docs/app-facing-production-integration-solid-webui-readonly-preview.md",
            "packages/zigeffect/workbench/src/causalArtifact.ts",
            "packages/zigeffect/workbench/src/App.tsx",
            "packages/zigeffect/workbench/public/sample-app-facing-solid-webui-readonly-preview.json",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview",
        .agent_guidance = "Use ready app-facing SolidJS read-only preview artifacts to start the CI advisory remediation report branch only. Do not infer app runtime integration, live agent projection, raw payload capture, app mutation, NenDB production writes, NenDB adapter execution, Cockroach scope, CI enforcement, deployment mutation, production health, mutation proof, auto-apply, hosted live dashboard, React renderer, alternate renderer, or applied=true.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report",
        .title = "App-Facing Production Integration CI Advisory Remediation Report",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready app-facing SolidJS read-only preview artifacts and emits a CI-readable advisory remediation report for agents and reviewers, preserving bridge records, advisory findings, blocked CI claims, verification commands, and next-branch guidance without required status checks, workflow mutation, GitHub API mutation, app writes, NenDB writes, or adapter execution.",
        .depends_on = &.{ "app-facing-production-integration-solid-webui-readonly-preview", "app-facing-production-integration-audit-remediation-bridge", "agent-query-interface", "audit-chain-snapshot-compare" },
        .deliverables = &.{
            "CI advisory remediation report schema",
            "report producer and approved/rejected artifacts",
            "advisory-only CI bridge checks",
            "workbench app-facing parser and sample route",
            "no-enforcement no-GitHub-mutation guardrails",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report.md",
            "packages/zigeffect/workbench/src/causalArtifact.ts",
            "packages/zigeffect/workbench/public/sample-app-facing-ci-advisory-remediation-report.json",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report",
        .agent_guidance = "Use ready app-facing CI advisory remediation report artifacts to start a reviewed application-boundary branch only. Do not infer CI enforcement, required status checks, workflow mutation, GitHub API mutation, app runtime integration, app mutation, NenDB production writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, mutation proof, auto-apply, or applied=true.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-application-boundary",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Application Boundary",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready app-facing CI advisory remediation report artifacts and emits planned/applied/blocked application-boundary evidence for reviewed local publication records, requiring source readiness, before/after evidence, safe after-report content, bridge records, and full verification before applied=true is recorded as record-only.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report", "app-facing-production-integration-solid-webui-readonly-preview", "app-facing-production-integration-audit-remediation-bridge" },
        .deliverables = &.{
            "application-boundary schema",
            "plan and record-applied producer",
            "blocked negative evidence fixture",
            "before/after and after-report safety checks",
            "no-publication no-GitHub-mutation no-app-mutation guardrails",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary",
        .agent_guidance = "Use applied app-facing advisory remediation report application-boundary records to start publication-policy work only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, mutation proof, auto-apply, or live dashboard authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-publication-policy",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Publication Policy",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-publication-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied record-only app-facing advisory remediation report application-boundary artifacts and emits a guarded interpretation policy for reviewer triage, agent read-only context, non-blocking CI advisory context, SolidJS webui read-only context, and future consumption-readiness work without granting mutation, enforcement, storage, deployment, or runtime authority.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-application-boundary", "app-facing-production-integration-ci-advisory-remediation-report", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "publication-policy schema",
            "approve/reject producer",
            "interpretation rules",
            "publication surface boundaries",
            "denied inference and negative fixture checks",
            "consumption-readiness handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-publication-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy",
        .agent_guidance = "Use ready app-facing advisory remediation report publication-policy artifacts to start consumption-readiness work only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, mutation proof, or auto-apply.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Readiness",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready app-facing advisory remediation report publication-policy artifacts and emits guarded read-only consumption readiness for reviewers, agents, non-blocking CI advisory readers, the SolidJS webui workbench, and the future consumption-boundary tool without granting mutation, enforcement, storage, deployment, or runtime authority.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-publication-policy", "app-facing-production-integration-ci-advisory-remediation-report-application-boundary", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-readiness schema",
            "approve/reject producer",
            "read-only consumer profiles",
            "readiness dimensions",
            "consumption guardrails",
            "denied inference and negative fixture checks",
            "consumption-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
        .agent_guidance = "Use ready app-facing advisory remediation report consumption-readiness artifacts to start consumption-boundary work only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, mutation proof, auto-apply, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Boundary",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready app-facing advisory remediation report consumption-readiness artifacts and emits planned/applied/blocked record-only boundary evidence for reviewed read-only consumption by reviewers, agents, CI advisory readers, and the SolidJS webui workbench without granting mutation, enforcement, storage, deployment, or runtime authority.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness", "app-facing-production-integration-ci-advisory-remediation-report-publication-policy", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-boundary schema",
            "plan and record-applied producer",
            "blocked negative evidence fixture",
            "consumer-after safety checks",
            "before after and verification evidence gates",
            "consumption-policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary",
        .agent_guidance = "Use applied app-facing advisory remediation report consumption-boundary artifacts to start consumption-policy work only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, auto-apply, or mutation authority beyond record-only artifact evidence.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-policy",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Policy",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied app-facing advisory remediation report consumption-boundary artifacts and emits guarded approve/reject interpretation-policy evidence for reviewers, agents, non-blocking CI advisory readers, and the SolidJS webui workbench without granting mutation, enforcement, storage, deployment, runtime, or adapter authority.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary", "app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-policy schema",
            "approve and reject producer",
            "interpretation rules",
            "read-only consumption scopes",
            "denied inference and negative fixture checks",
            "consumption-evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy",
        .agent_guidance = "Use ready app-facing advisory remediation report consumption-policy artifacts to start read-only consumption-evaluator work only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, auto-apply, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Evaluator",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready app-facing advisory remediation report consumption-policy artifacts plus explicit request and evidence files, then emits ready, advisory, or blocked read-only evaluator artifacts for agents, reviewers, non-blocking CI advisory readers, and the SolidJS webui workbench without granting mutation, enforcement, storage, deployment, runtime, or adapter authority.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-policy", "app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-evaluator schema",
            "evaluate producer",
            "request and evidence classifier",
            "ready advisory and blocked artifacts",
            "denied content checks",
            "redaction posture and next-query guidance",
            "consumption-report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator",
        .agent_guidance = "Use ready or advisory app-facing advisory remediation report consumption-evaluator artifacts to start consumption-report work only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory app-facing advisory remediation report consumption-evaluator artifacts and emits local human/agent JSON and text consumption reports without granting mutation, enforcement, storage, deployment, runtime, public upload, or adapter authority.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator", "app-facing-production-integration-ci-advisory-remediation-report-consumption-policy", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report schema",
            "summarize producer",
            "ready advisory and blocked report artifacts",
            "source evaluator contract checks",
            "local-only publication channels",
            "authority drift blocking",
            "application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report",
        .agent_guidance = "Use ready or advisory app-facing advisory remediation report consumption-report artifacts to start application-boundary work only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Application Boundary",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory app-facing advisory remediation report consumption-report artifacts and emits guarded planned/applied/blocked record-only application-boundary evidence for local agents, reviewers, non-blocking CI advisory readers, and the SolidJS webui without granting mutation, enforcement, storage, deployment, runtime, public upload, or adapter authority.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report", "app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report application-boundary schema",
            "plan and record-applied producer",
            "source consumption-report contract checks",
            "report application change evidence gate",
            "before and after evidence gates",
            "after-report safety checks",
            "authority drift blocking",
            "verification command evidence",
            "report-policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary",
        .agent_guidance = "Use applied app-facing advisory remediation report consumption-report application-boundary artifacts to start report-policy work only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, auto-apply, public artifact upload, or mutation authority beyond record-only artifact evidence.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Policy",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied app-facing advisory remediation report consumption-report application-boundary artifacts and emits approve/reject record-only policy evidence for local agents, reviewers, non-blocking CI advisory readers, and the SolidJS webui without granting mutation, enforcement, storage, deployment, runtime, public upload, or adapter authority.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report policy schema",
            "approve and reject producer",
            "applied application-boundary source checks",
            "source application evidence gates",
            "interpretation rules and consumption scopes",
            "denied inference rules and negative fixtures",
            "verification command evidence",
            "report-evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_policy.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy",
        .agent_guidance = "Use ready app-facing advisory remediation report consumption-report policy artifacts to start report-evaluator work only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluator",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready app-facing advisory remediation report consumption-report policy artifacts plus explicit bounded local request and support evidence files, then emits ready/advisory/blocked read-only evaluator evidence for agents, reviewers, non-blocking CI advisory readers, and the SolidJS webui without granting mutation, enforcement, storage, deployment, runtime, public upload, auto-apply, or adapter authority.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluator schema",
            "ready/advisory/blocked evaluator producer",
            "ready consumption-report policy source checks",
            "source application evidence checks",
            "bounded request and evidence classifier",
            "denied content and redaction posture tests",
            "verification command evidence",
            "evaluation-report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluator.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator",
        .agent_guidance = "Use ready or advisory app-facing advisory remediation report consumption-report evaluator artifacts to start evaluation-report work only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready, advisory, or blocked app-facing advisory remediation report consumption-report evaluator artifacts and emits a local read-only evaluation report for agents, reviewers, non-blocking CI advisory readers, and the SolidJS webui without granting mutation, enforcement, runtime, deployment, storage, public upload, hosted dashboard, auto-apply, or adapter authority.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report schema",
            "ready/advisory/blocked report producer",
            "source consumption-report evaluator checks",
            "source report application evidence checks",
            "local publication-only report channels",
            "authority drift tests",
            "verification command evidence",
            "evaluation-report application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report",
        .agent_guidance = "Use ready or advisory app-facing advisory remediation report consumption-report evaluation reports to start the guarded application-boundary branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Application Boundary",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory app-facing advisory remediation report consumption-report evaluation-report artifacts and emits guarded plan or record-applied application-boundary evidence, only setting applied=true when reviewed local application changes, before/after evidence, safe after-report content, and verification commands are present.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report application-boundary schema",
            "plan and record-applied producer",
            "ready/advisory/blocked source evaluation-report checks",
            "reviewed application-change before after and safe after-report gates",
            "authority drift tests",
            "verification command evidence",
            "evaluation-report policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary",
        .agent_guidance = "Use applied consumption-report evaluation-report application-boundary evidence to start evaluation-report policy work only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Policy",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied app-facing advisory remediation report consumption-report evaluation-report application-boundary artifacts and emits record-only approve or reject interpretation policy evidence for agents, reviewers, non-blocking CI advisory readers, and the SolidJS webui.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report policy schema",
            "approve and reject producer",
            "applied evaluation-report application-boundary source checks",
            "interpretation rules",
            "consumption scopes",
            "denied inference rules",
            "negative fixtures",
            "verification command evidence",
            "evaluation-report evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy",
        .agent_guidance = "Use ready consumption-report evaluation-report policy evidence to start the evaluation-report evaluator branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluator",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready app-facing advisory remediation report consumption-report evaluation-report policy artifacts plus explicit local request and evidence files, classifies evaluation-report consumption evidence as ready advisory or blocked, and emits read-only evaluator evidence for agents reviewers non-blocking CI advisory readers and the SolidJS webui.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluator schema",
            "ready advisory and blocked evaluator producer",
            "approved evaluation-report policy source checks",
            "evaluation-report application evidence carryover",
            "request and evidence classifier",
            "denied content and redaction posture checks",
            "authority drift tests",
            "evaluation-report evaluation-report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator",
        .agent_guidance = "Use ready consumption-report evaluation-report evaluator evidence to start the evaluation-report evaluation-report branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory app-facing advisory remediation report consumption-report evaluation-report evaluator artifacts and emits local report evidence for agents reviewers non-blocking CI advisory readers and the SolidJS webui.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluation-report schema",
            "ready advisory and blocked report producer",
            "ready evaluation-report evaluator source checks",
            "source evaluation-report application evidence carryover",
            "inherited report application evidence carryover",
            "local publication-only channels",
            "authority drift tests",
            "evaluation-report evaluation-report application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report",
        .agent_guidance = "Use ready or advisory consumption-report evaluation-report evaluation-report evidence to start the guarded application-boundary branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Application Boundary",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory app-facing advisory remediation report consumption-report evaluation-report evaluation-report artifacts and records planned or reviewed local application-boundary evidence while keeping application runtime, CI, GitHub, storage, adapter, publication, deployment, and auto-apply authority disabled.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluation-report application-boundary schema",
            "plan and record-applied producer modes",
            "reviewed before and after evidence gates",
            "safe after-report content gate",
            "source evaluation-report evaluation-report checks",
            "inherited evaluation-report and report application evidence carryover",
            "authority drift tests",
            "evaluation-report evaluation-report policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary",
        .agent_guidance = "Use applied consumption-report evaluation-report evaluation-report application-boundary evidence to start the policy branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Policy",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied app-facing advisory remediation report consumption-report evaluation-report evaluation-report application-boundary artifacts and emits record-only approve or reject policy evidence for the next evaluator branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluation-report policy schema",
            "approve and reject policy producer",
            "applied evaluation-report evaluation-report application-boundary source checks",
            "interpretation rules and consumption scopes",
            "denied inference catalog",
            "negative fixtures",
            "required verification command gates",
            "evaluation-report evaluation-report evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy",
        .agent_guidance = "Use ready consumption-report evaluation-report evaluation-report policy evidence to start the evaluator branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluator",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready app-facing advisory remediation report consumption-report evaluation-report evaluation-report policy artifacts plus explicit local request and evidence files, classifies evaluation-report evaluation-report consumption evidence as ready advisory or blocked, and emits read-only evaluator evidence for agents reviewers non-blocking CI advisory readers and the SolidJS webui.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluation-report evaluator schema",
            "ready advisory and blocked evaluator producer",
            "approved evaluation-report evaluation-report policy source checks",
            "evaluation-report evaluation-report application evidence carryover",
            "inherited evaluation-report and report application evidence carryover",
            "request and evidence classifier",
            "denied content and redaction posture checks",
            "authority drift tests",
            "evaluation-report evaluation-report evaluation-report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator",
        .agent_guidance = "Use ready or advisory consumption-report evaluation-report evaluation-report evaluator evidence to start the evaluation-report evaluation-report evaluation-report branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory app-facing advisory remediation report consumption-report evaluation-report evaluation-report evaluator artifacts, emits a compact local evaluation-report evaluation-report evaluation-report for agents reviewers non-blocking CI advisory readers and the SolidJS webui, and preserves no mutation authority.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluation-report evaluation-report schema",
            "ready advisory and blocked report producer",
            "source evaluation-report evaluation-report evaluator checks",
            "source policy and application evidence carryover",
            "request evidence signal and finding summaries",
            "denied claim and local publication posture carryover",
            "authority drift tests",
            "evaluation-report evaluation-report evaluation-report application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report",
        .agent_guidance = "Use ready or advisory consumption-report evaluation-report evaluation-report evaluation-report evidence to start the application-boundary branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Application Boundary",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory app-facing advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report artifacts, records planned or reviewed local application evidence, and only marks applied after before/after evidence, safe after-report content, and required verification commands are present.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluation-report evaluation-report application-boundary schema",
            "plan and record-applied producer",
            "ready advisory and blocked source report checks",
            "source policy application and evaluator evidence carryover",
            "reviewed before and after application evidence checks",
            "safe after-report content checks",
            "local publication and denied authority carryover",
            "verification command evidence",
            "evaluation-report evaluation-report evaluation-report policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .agent_guidance = "Use applied consumption-report evaluation-report evaluation-report evaluation-report application-boundary evidence to start the evaluation-report evaluation-report evaluation-report policy branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Policy",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied app-facing advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report application-boundary artifacts, emits record-only interpretation policy evidence, and keeps mutation authority disabled while preparing the evaluator branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluation-report evaluation-report policy schema",
            "approve and reject policy producer",
            "applied application-boundary source checks",
            "interpretation rules and consumption scopes",
            "denied inference rules",
            "negative fixture catalog",
            "verification command evidence",
            "evaluation-report evaluation-report evaluation-report evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .agent_guidance = "Use ready consumption-report evaluation-report evaluation-report evaluation-report policy evidence to start the evaluator branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluator",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready app-facing advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report policy artifacts plus bounded local request and support evidence, emits ready advisory or blocked evaluator findings, and keeps mutation authority disabled while preparing the next report branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluation-report evaluation-report evaluator schema",
            "policy source parser",
            "bounded request and support evidence analysis",
            "ready advisory and blocked evaluator findings",
            "redaction posture checks",
            "denied authority checks",
            "verification command evidence",
            "evaluation-report evaluation-report evaluation-report evaluation-report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .agent_guidance = "Use ready consumption-report evaluation-report evaluation-report evaluation-report evaluator evidence to start the evaluation-report evaluation-report evaluation-report evaluation-report branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory app-facing advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluator artifacts, emits a compact local evaluation-report evaluation-report evaluation-report evaluation-report for agents reviewers non-blocking CI advisory readers and the SolidJS webui, preserves inherited evaluation-report evidence, and keeps mutation authority disabled while preparing the application-boundary branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluation-report evaluation-report evaluation-report schema",
            "ready advisory and blocked report producer",
            "source evaluation-report evaluation-report evaluation-report evaluator checks",
            "source policy and application evidence carryover",
            "inherited evaluation-report evaluation-report evidence carryover",
            "request evidence signal and finding summaries",
            "denied claim and local publication posture carryover",
            "authority drift tests",
            "evaluation-report evaluation-report evaluation-report evaluation-report application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .agent_guidance = "Use ready or advisory consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evidence to start the application-boundary branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Application Boundary",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory app-facing advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report artifacts, records planned or reviewed local application evidence, and only marks applied after reviewed local changes, before/after evidence, safe after-report content, and required verification commands are present.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluation-report evaluation-report evaluation-report application-boundary schema",
            "plan and record-applied producer",
            "ready advisory and blocked source report checks",
            "current and inherited source lineage carryover",
            "reviewed before and after application evidence checks",
            "safe after-report content checks",
            "local publication and denied authority carryover",
            "verification command evidence",
            "evaluation-report evaluation-report evaluation-report evaluation-report policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .agent_guidance = "Use applied consumption-report evaluation-report evaluation-report evaluation-report evaluation-report application-boundary evidence to start the evaluation-report evaluation-report evaluation-report evaluation-report policy branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Policy",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied app-facing advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report application-boundary artifacts and emits approve/reject record-only interpretation policy evidence for agents, reviewers, non-blocking CI advisory readers, and the SolidJS webui without granting mutation, enforcement, storage, deployment, runtime, public upload, or adapter authority.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluation-report evaluation-report evaluation-report policy schema",
            "approve and reject producer",
            "applied application-boundary source checks",
            "current and inherited source lineage carryover",
            "interpretation rules for maintainers agents CI advisory readers and SolidJS webui",
            "local consumption scopes",
            "denied inference rules",
            "negative fixtures",
            "verification command evidence",
            "evaluation-report evaluation-report evaluation-report evaluation-report evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .agent_guidance = "Use ready consumption-report evaluation-report evaluation-report evaluation-report evaluation-report policy evidence to start the evaluation-report evaluation-report evaluation-report evaluation-report evaluator branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluator",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready app-facing advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report policy artifacts plus bounded local request and support evidence, emits ready advisory or blocked evaluator findings, and keeps mutation authority disabled while preparing the five-level evaluation-report branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator schema",
            "four-level policy source parser",
            "bounded request and support evidence analysis",
            "ready advisory and blocked evaluator findings",
            "redaction posture checks",
            "denied authority checks",
            "verification command evidence",
            "evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .agent_guidance = "Use ready or advisory consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator evidence to start the evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory app-facing advisory remediation report consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator artifacts, emits a compact local five-level evaluation-report for agents reviewers non-blocking CI advisory readers and the SolidJS webui, preserves inherited evaluation-report evidence, and keeps mutation authority disabled while preparing the application-boundary branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report schema",
            "ready advisory and blocked report producer",
            "source evaluation-report evaluation-report evaluation-report evaluation-report evaluator checks",
            "source policy and application evidence carryover",
            "inherited evaluation-report evaluation-report evaluation-report evidence carryover",
            "request evidence signal and finding summaries",
            "denied claim and local publication posture carryover",
            "authority drift tests",
            "evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .agent_guidance = "Use ready or advisory consumption-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evidence to start the application-boundary branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Application Boundary",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory five-level evaluation-report artifacts and records planned or reviewed local application-boundary evidence while requiring reviewed changes before evidence after evidence safe after-report content and complete verification commands before applied=true.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "five-level application-boundary schema",
            "plan and record-applied modes",
            "reviewed application change evidence gate",
            "before and after evidence gate",
            "safe after-report content gate",
            "post-application verification command gate",
            "ready applied and blocked boundary artifacts",
            "evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .agent_guidance = "Use applied five-level application-boundary artifacts to start the matching policy branch only. Planned artifacts remain intent-only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Policy",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied five-level application-boundary evidence, records approve or reject policy interpretation for agents reviewers non-blocking CI advisory readers and the SolidJS webui, preserves no-mutation authority, and prepares the matching evaluator branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "five-level policy schema",
            "applied source application-boundary checks",
            "approve and reject decision records",
            "interpretation and consumption scope rules",
            "negative fixture coverage",
            "denied inference rules",
            "verification command evidence gate",
            "evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .agent_guidance = "Use ready five-level policy artifacts to start the matching evaluator branch only. Rejected policy artifacts remain review evidence, not permission to mutate. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluator",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready five-level policy artifacts plus bounded local request and support evidence, emits ready advisory or blocked evaluator findings, and keeps mutation authority disabled while preparing the six-level evaluation-report branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "five-level evaluator schema",
            "five-level policy source parser",
            "bounded request and support evidence analysis",
            "ready advisory and blocked evaluator findings",
            "redaction posture checks",
            "denied authority checks",
            "verification command evidence",
            "evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .agent_guidance = "Use ready or advisory five-level evaluator evidence to start the six-level evaluation-report branch only. Blocked evaluator artifacts are stop signs. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory five-level evaluator artifacts, emits a compact local six-level evaluation-report for agents reviewers non-blocking CI advisory readers and the SolidJS webui, preserves inherited evaluation-report evidence, and keeps mutation authority disabled while preparing the six-level application-boundary branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "six-level report schema",
            "ready advisory and blocked report producer",
            "source five-level evaluator checks",
            "source five-level policy and application evidence carryover",
            "inherited lower-level evaluation-report evidence carryover",
            "request evidence signal and finding summaries",
            "denied claim and local publication posture carryover",
            "authority drift tests",
            "six-level application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .agent_guidance = "Use ready or advisory six-level report evidence to start the application-boundary branch only. Blocked report artifacts are stop signs. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Application Boundary",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory six-level evaluation-report artifacts and records planned or reviewed local application-boundary evidence while requiring reviewed changes before evidence after evidence safe after-report content and complete verification commands before applied=true.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "six-level application-boundary schema",
            "plan and record-applied modes",
            "reviewed application change evidence gate",
            "before and after evidence gate",
            "safe after-report content gate",
            "post-application verification command gate",
            "ready applied and blocked boundary artifacts",
            "six-level policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-six-level-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .agent_guidance = "Use applied six-level application-boundary artifacts to start the matching policy branch only. Planned artifacts remain intent-only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Policy",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied six-level application-boundary evidence, records approve or reject policy interpretation for agents reviewers non-blocking CI advisory readers and the SolidJS webui, preserves no-mutation authority, and prepares the matching evaluator branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "six-level policy schema",
            "applied source application-boundary checks",
            "approve and reject decision records",
            "interpretation and consumption scope rules",
            "negative fixture coverage",
            "denied inference rules",
            "verification command evidence gate",
            "evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-six-level-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .agent_guidance = "Use ready six-level policy artifacts to start the matching evaluator branch only. Rejected policy artifacts remain review evidence, not permission to mutate. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluator",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready six-level policy artifacts plus bounded local request and support evidence, emits ready advisory or blocked evaluator evidence, preserves no-mutation authority, and prepares the seven-level report branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "six-level evaluator schema",
            "ready advisory and blocked evaluator producer",
            "source six-level policy checks",
            "bounded request and support evidence classifier",
            "redaction posture checks",
            "denied authority checks",
            "verification command evidence",
            "evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-six-level-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .agent_guidance = "Use ready or advisory six-level evaluator evidence to start the seven-level evaluation-report branch only. Blocked evaluator artifacts are stop signs. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory six-level evaluator artifacts, emits a compact local seven-level evaluation-report for agents reviewers non-blocking CI advisory readers and the SolidJS webui, preserves inherited evaluation-report evidence, and keeps mutation authority disabled while preparing the seven-level application-boundary branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "seven-level report schema",
            "ready advisory and blocked report producer",
            "source six-level evaluator checks",
            "source six-level policy and application evidence carryover",
            "inherited evaluation-report evidence carryover",
            "request evidence signal and finding summaries",
            "denied claim and local publication posture carryover",
            "authority drift tests",
            "seven-level application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-seven-level-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .agent_guidance = "Use ready or advisory seven-level report evidence to start the application-boundary branch only. Blocked report artifacts are stop signs. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Application Boundary",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory seven-level report artifacts, records planned or reviewed local application evidence, and only marks applied after before/after evidence, safe after-report content, and required verification commands are present.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "seven-level application-boundary schema",
            "plan and record-applied producer",
            "ready advisory and blocked source report checks",
            "source policy application evaluator and report evidence carryover",
            "reviewed before and after application evidence checks",
            "safe after-report content checks",
            "local publication and denied authority carryover",
            "verification command evidence",
            "seven-level policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-seven-level-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-seven-level-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
        .agent_guidance = "Use applied seven-level application-boundary evidence to start the seven-level policy branch only. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Policy",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied seven-level application-boundary evidence, records approve or reject policy interpretation for agents reviewers non-blocking CI advisory readers and the SolidJS webui, preserves no-mutation authority, and prepares the seven-level evaluator branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "seven-level policy schema",
            "applied source application-boundary checks",
            "approve and reject decision records",
            "interpretation and consumption scope rules",
            "negative fixture coverage",
            "denied inference rules",
            "verification command evidence gate",
            "seven-level evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-seven-level-policy-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-seven-level-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        .agent_guidance = "Use ready seven-level policy evidence to start the seven-level evaluator branch only. Rejected or blocked policy artifacts remain review evidence, not permission to mutate. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluator",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready seven-level policy artifacts plus bounded local request and support evidence, emits ready advisory or blocked evaluator evidence, preserves no-mutation authority, and prepares the eight-level report branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "seven-level evaluator schema",
            "ready advisory and blocked evaluator producer",
            "source seven-level policy checks",
            "bounded request and support evidence classifier",
            "redaction posture checks",
            "denied authority checks",
            "verification command evidence",
            "eight-level report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-seven-level-evaluator-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-seven-level-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
        .agent_guidance = "Use ready or advisory seven-level evaluator evidence to start the eight-level report branch only. Blocked evaluator artifacts are stop signs. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .title = "App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report",
        .gap_id = "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory seven-level evaluator artifacts, emits a compact local eight-level evaluation-report for agents reviewers non-blocking CI advisory readers and the SolidJS webui, preserves source findings and no-mutation authority, and prepares the eight-level application-boundary branch.",
        .depends_on = &.{ "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "app-facing-production-integration-solid-webui-readonly-preview" },
        .deliverables = &.{
            "eight-level report schema",
            "ready advisory and blocked report producer",
            "source seven-level evaluator checks",
            "source seven-level policy and application evidence carryover",
            "inherited report evidence carryover",
            "request support and finding summaries",
            "local-only publication channels",
            "denied authority checks",
            "verification command evidence",
            "eight-level application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-eight-level-report-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-eight-level-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig",
            "packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        .agent_guidance = "Use ready or advisory eight-level report evidence to start the eight-level application-boundary branch only. Blocked report artifacts are stop signs. Do not infer required status checks, CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, NenDB writes, NenDB adapter execution, non-NenDB durable scope, deployment mutation, production health, hosted dashboards, auto-apply, public artifact upload, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-eight-level-application-boundary",
        .title = "App-Facing Eight-Level Application Boundary",
        .gap_id = "app-facing-eight-level-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory eight-level report artifacts, records planned or reviewed local application-boundary evidence, preserves full schema lineage while using short physical aliases, and prepares the eight-level policy branch.",
        .depends_on = &.{"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report"},
        .deliverables = &.{
            "eight-level application-boundary schema",
            "short alias build step",
            "ready planned and applied boundary producer",
            "blocked source and authority drift checks",
            "safe after-report checks",
            "local-only publication evidence",
            "schema governance registration",
            "eight-level policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-eight-level-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-eight-level-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_eight_level_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-eight-level-application-boundary.md",
            "packages/zigeffect/test/fixtures/app-facing-eight-level-application-boundary-after-safe.txt",
        },
        .branch = "codex/zigeffect-causal-app-facing-eight-level-application-boundary",
        .agent_guidance = "Use applied eight-level application-boundary evidence to start the eight-level policy branch only. Planned evidence is preparatory; blocked evidence is a stop sign. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-eight-level-policy",
        .title = "App-Facing Eight-Level Policy",
        .gap_id = "app-facing-eight-level-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied eight-level application-boundary evidence, records a local approve or reject interpretation policy, preserves no-mutation authority, and prepares the eight-level evaluator branch.",
        .depends_on = &.{"app-facing-eight-level-application-boundary"},
        .deliverables = &.{
            "eight-level policy schema",
            "short alias build step",
            "approve and reject policy evidence",
            "source application-boundary checks",
            "interpretation rules and consumption scopes",
            "denied inference rules",
            "schema governance registration",
            "eight-level evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-eight-level-policy-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-eight-level-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_eight_level_policy.zig",
            "packages/zigeffect/docs/app-facing-eight-level-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-eight-level-policy",
        .agent_guidance = "Use approved eight-level policy evidence to start the eight-level evaluator branch only. Rejected or blocked policy artifacts remain review evidence, not permission to mutate. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-eight-level-evaluator",
        .title = "App-Facing Eight-Level Evaluator",
        .gap_id = "app-facing-eight-level-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes approved eight-level policy evidence plus bounded local request and support evidence, emits ready advisory or blocked evaluator findings, preserves no-mutation authority, and prepares the nine-level report branch.",
        .depends_on = &.{"app-facing-eight-level-policy"},
        .deliverables = &.{
            "eight-level evaluator schema",
            "short alias build step",
            "ready advisory and blocked evaluator evidence",
            "source eight-level policy checks",
            "bounded request and support evidence classification",
            "redaction posture checks",
            "schema governance registration",
            "nine-level report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-eight-level-evaluator-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-eight-level-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_eight_level_evaluator.zig",
            "packages/zigeffect/docs/app-facing-eight-level-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-eight-level-evaluator",
        .agent_guidance = "Use ready or advisory eight-level evaluator evidence to start the nine-level report branch only. Blocked evaluator artifacts are stop signs. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-nine-level-report",
        .title = "App-Facing Nine-Level Report",
        .gap_id = "app-facing-nine-level-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory eight-level evaluator evidence, emits a local nine-level report, preserves no-mutation authority, and prepares the nine-level application-boundary branch.",
        .depends_on = &.{"app-facing-eight-level-evaluator"},
        .deliverables = &.{
            "nine-level report schema",
            "short alias build step",
            "ready advisory and blocked report evidence",
            "source eight-level evaluator checks",
            "source eight-level policy and application evidence carryover",
            "local publication posture checks",
            "schema governance registration",
            "nine-level application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-nine-level-report-design.md",
            "docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-nine-level-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_nine_level_report.zig",
            "packages/zigeffect/docs/app-facing-nine-level-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-nine-level-report",
        .agent_guidance = "Use ready or advisory nine-level report evidence to start the nine-level application-boundary branch only. Blocked report artifacts are stop signs. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-nine-level-application-boundary",
        .title = "App-Facing Nine-Level Application Boundary",
        .gap_id = "app-facing-nine-level-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory nine-level report artifacts, records planned or reviewed local application-boundary evidence, preserves no-mutation authority, and prepares the nine-level policy branch.",
        .depends_on = &.{"app-facing-nine-level-report"},
        .deliverables = &.{
            "nine-level application-boundary schema",
            "short alias build step",
            "plan and record-applied modes",
            "guarded before after and after-report evidence",
            "ready planned applied and blocked artifact evidence",
            "source nine-level report checks",
            "local publication posture checks",
            "schema governance registration",
            "nine-level policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-nine-level-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-nine-level-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_nine_level_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-nine-level-application-boundary.md",
            "packages/zigeffect/test/fixtures/app-facing-nine-level-application-boundary-after-safe.txt",
        },
        .branch = "codex/zigeffect-causal-app-facing-nine-level-application-boundary",
        .agent_guidance = "Use applied nine-level application-boundary evidence to start the nine-level policy branch only. Planned evidence is preparatory; blocked evidence is a stop sign. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-nine-level-policy",
        .title = "App-Facing Nine-Level Policy",
        .gap_id = "app-facing-nine-level-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied nine-level application-boundary evidence, records a reviewed approve or reject policy decision, preserves no-mutation authority, and prepares the nine-level evaluator branch.",
        .depends_on = &.{"app-facing-nine-level-application-boundary"},
        .deliverables = &.{
            "nine-level policy schema",
            "short alias build step",
            "approve and reject decisions",
            "applied nine-level application-boundary gates",
            "nine-level report and inherited eight-level policy lineage checks",
            "read-only interpretation and consumption scopes",
            "denied inference and negative fixture catalogs",
            "schema governance registration",
            "nine-level evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-nine-level-policy-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-nine-level-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_nine_level_policy.zig",
            "packages/zigeffect/docs/app-facing-nine-level-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-nine-level-policy",
        .agent_guidance = "Use approved nine-level policy evidence to start the nine-level evaluator branch only. Rejected or blocked policy evidence is review material. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-nine-level-evaluator",
        .title = "App-Facing Nine-Level Evaluator",
        .gap_id = "app-facing-nine-level-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes approved nine-level policy evidence plus bounded local request and support evidence, emits ready advisory or blocked evaluator findings, preserves no-mutation authority, and prepares the ten-level report branch.",
        .depends_on = &.{"app-facing-nine-level-policy"},
        .deliverables = &.{
            "nine-level evaluator schema",
            "short alias build step",
            "ready advisory and blocked evaluations",
            "source nine-level policy gates",
            "bounded request and support evidence classification",
            "redaction posture checks",
            "denied authority and negative fixture carryover",
            "schema governance registration",
            "ten-level report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-nine-level-evaluator-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-nine-level-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_nine_level_evaluator.zig",
            "packages/zigeffect/docs/app-facing-nine-level-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-nine-level-evaluator",
        .agent_guidance = "Use ready or advisory nine-level evaluator evidence to start the ten-level report branch only. Blocked evaluator artifacts are stop signs. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-ten-level-report",
        .title = "App-Facing Ten-Level Report",
        .gap_id = "app-facing-ten-level-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory nine-level evaluator evidence, emits a local ten-level report, preserves no-mutation authority, and prepares the ten-level application-boundary branch.",
        .depends_on = &.{"app-facing-nine-level-evaluator"},
        .deliverables = &.{
            "ten-level report schema",
            "short alias build step",
            "ready advisory and blocked reports",
            "source nine-level evaluator gates",
            "source nine-level policy application and report evidence carryover",
            "inherited eight-level evidence carryover",
            "local publication channel checks",
            "schema governance registration",
            "ten-level application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-ten-level-report-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-ten-level-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_ten_level_report.zig",
            "packages/zigeffect/docs/app-facing-ten-level-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-ten-level-report",
        .agent_guidance = "Use ready or advisory ten-level report evidence to start the ten-level application-boundary branch only. Blocked report artifacts are stop signs. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-ten-level-application-boundary",
        .title = "App-Facing Ten-Level Application Boundary",
        .gap_id = "app-facing-ten-level-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory ten-level report artifacts, records planned or reviewed local application-boundary evidence, preserves no-mutation authority, carries source nine-level lineage, and prepares the ten-level policy branch.",
        .depends_on = &.{"app-facing-ten-level-report"},
        .deliverables = &.{
            "ten-level application-boundary schema",
            "short alias build step",
            "plan applied and blocked artifacts",
            "source ten-level report checks",
            "source nine-level policy application and report lineage carryover",
            "safe after-report gates",
            "record-applied before after and verification gates",
            "schema governance registration",
            "ten-level policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-ten-level-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-ten-level-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_ten_level_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-ten-level-application-boundary.md",
            "packages/zigeffect/test/fixtures/app-facing-ten-level-application-boundary-after-safe.txt",
        },
        .branch = "codex/zigeffect-causal-app-facing-ten-level-application-boundary",
        .agent_guidance = "Use applied ten-level application-boundary evidence to start the ten-level policy branch only. Planned evidence is preparatory; blocked evidence is a stop sign. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-ten-level-policy",
        .title = "App-Facing Ten-Level Policy",
        .gap_id = "app-facing-ten-level-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied ten-level application-boundary evidence, records a reviewed approve or reject policy decision, preserves no-mutation authority, carries source ten-level report and nine-level lineage, and prepares the ten-level evaluator branch.",
        .depends_on = &.{"app-facing-ten-level-application-boundary"},
        .deliverables = &.{
            "ten-level policy schema",
            "short alias build step",
            "approve reject policy artifacts",
            "source ten-level application-boundary checks",
            "source ten-level report evidence carryover",
            "source nine-level policy application and report lineage carryover",
            "interpretation and denied inference rules",
            "schema governance registration",
            "ten-level evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-ten-level-policy-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-ten-level-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_ten_level_policy.zig",
            "packages/zigeffect/docs/app-facing-ten-level-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-ten-level-policy",
        .agent_guidance = "Use approved ten-level policy evidence to start the ten-level evaluator branch only. Rejected or blocked policy evidence is a stop sign. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live agent projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-ten-level-evaluator",
        .title = "App-Facing Ten-Level Evaluator",
        .gap_id = "app-facing-ten-level-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes approved ten-level policy evidence plus bounded local request and support evidence, emits ready advisory or blocked evaluator evidence, preserves no-mutation authority, carries ten-level and nine-level lineage, and prepares the eleven-level report branch.",
        .depends_on = &.{"app-facing-ten-level-policy"},
        .deliverables = &.{
            "ten-level evaluator schema",
            "short alias build step",
            "ready advisory and blocked evaluator artifacts",
            "source ten-level policy checks",
            "source ten-level report evidence carryover",
            "source nine-level policy application and report lineage carryover",
            "bounded request and support evidence classifier",
            "redaction posture checks",
            "schema governance registration",
            "eleven-level report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-ten-level-evaluator-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-ten-level-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_ten_level_evaluator.zig",
            "packages/zigeffect/docs/app-facing-ten-level-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-ten-level-evaluator",
        .agent_guidance = "Use ready or advisory ten-level evaluator evidence to start the eleven-level report branch only. Blocked evaluator evidence is a stop sign. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live agent projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-eleven-level-report",
        .title = "App-Facing Eleven-Level Report",
        .gap_id = "app-facing-eleven-level-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory ten-level evaluator evidence, emits a local eleven-level report, preserves no-mutation authority, carries ten-level and nine-level lineage, and prepares the eleven-level application-boundary branch.",
        .depends_on = &.{"app-facing-ten-level-evaluator"},
        .deliverables = &.{
            "eleven-level report schema",
            "short alias build step",
            "ready advisory and blocked report artifacts",
            "source ten-level evaluator gates",
            "source ten-level policy application and report evidence carryover",
            "source nine-level lineage carryover",
            "local publication channel checks",
            "schema governance registration",
            "eleven-level application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-eleven-level-report-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-eleven-level-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_eleven_level_report.zig",
            "packages/zigeffect/docs/app-facing-eleven-level-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-eleven-level-report",
        .agent_guidance = "Use ready or advisory eleven-level report evidence to start the eleven-level application-boundary branch only. Blocked report artifacts are stop signs. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live agent projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-eleven-level-application-boundary",
        .title = "App-Facing Eleven-Level Application Boundary",
        .gap_id = "app-facing-eleven-level-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory eleven-level report evidence, records planned or reviewed local application-boundary evidence, preserves direct ten-level and inherited nine-level lineage, and prepares the eleven-level policy branch without mutation authority.",
        .depends_on = &.{"app-facing-eleven-level-report"},
        .deliverables = &.{
            "eleven-level application-boundary schema",
            "short alias build step",
            "plan applied and blocked source artifacts",
            "source eleven-level report gates",
            "source ten-level lineage carryover",
            "source nine-level lineage carryover",
            "reviewed before after and safe after-report evidence gates",
            "schema governance registration",
            "eleven-level policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-eleven-level-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-eleven-level-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_eleven_level_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-eleven-level-application-boundary.md",
            "packages/zigeffect/test/fixtures/app-facing-eleven-level-application-boundary-after-safe.txt",
        },
        .branch = "codex/zigeffect-causal-app-facing-eleven-level-application-boundary",
        .agent_guidance = "Use applied eleven-level application-boundary evidence to start the eleven-level policy branch only. Planned artifacts are preparatory and blocked artifacts are stop signs. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live agent projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-eleven-level-policy",
        .title = "App-Facing Eleven-Level Policy",
        .gap_id = "app-facing-eleven-level-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied eleven-level application-boundary evidence, records a local approve or reject policy decision, preserves eleven-level report plus ten-level and nine-level lineage, and prepares the eleven-level evaluator branch without mutation authority.",
        .depends_on = &.{"app-facing-eleven-level-application-boundary"},
        .deliverables = &.{
            "eleven-level policy schema",
            "short alias build step",
            "approve reject and blocked source artifacts",
            "source eleven-level application-boundary gates",
            "source eleven-level report carryover",
            "source ten-level lineage carryover",
            "source nine-level lineage carryover",
            "verification command gate",
            "schema governance registration",
            "eleven-level evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-eleven-level-policy-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-eleven-level-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_eleven_level_policy.zig",
            "packages/zigeffect/docs/app-facing-eleven-level-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-eleven-level-policy",
        .agent_guidance = "Use approved eleven-level policy evidence to start the eleven-level evaluator branch only. Rejected or blocked artifacts are review material. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live agent projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-eleven-level-evaluator",
        .title = "App-Facing Eleven-Level Evaluator",
        .gap_id = "app-facing-eleven-level-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes approved eleven-level policy evidence plus bounded request and support evidence, emits ready advisory or blocked evaluator findings, preserves eleven-level, ten-level, and nine-level lineage, and prepares the twelve-level report branch without mutation authority.",
        .depends_on = &.{"app-facing-eleven-level-policy"},
        .deliverables = &.{
            "eleven-level evaluator schema",
            "short alias build step",
            "ready advisory and blocked evaluator artifacts",
            "source eleven-level policy gates",
            "bounded request evidence classification",
            "support evidence advisory behavior",
            "source eleven-level lineage carryover",
            "source ten-level lineage carryover",
            "source nine-level lineage carryover",
            "schema governance registration",
            "twelve-level report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-eleven-level-evaluator-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-eleven-level-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_eleven_level_evaluator.zig",
            "packages/zigeffect/docs/app-facing-eleven-level-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-eleven-level-evaluator",
        .agent_guidance = "Use ready or advisory eleven-level evaluator evidence to start the twelve-level report branch only. Blocked artifacts are stop signs. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live agent projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-twelve-level-report",
        .title = "App-Facing Twelve-Level Report",
        .gap_id = "app-facing-twelve-level-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory eleven-level evaluator evidence, emits local twelve-level report artifacts, preserves eleven-level, ten-level, and nine-level lineage, and prepares the twelve-level application-boundary branch without mutation authority.",
        .depends_on = &.{"app-facing-eleven-level-evaluator"},
        .deliverables = &.{
            "twelve-level report schema",
            "short alias build step",
            "ready advisory and blocked report artifacts",
            "source eleven-level evaluator gates",
            "source eleven-level policy application and report carryover",
            "source ten-level lineage carryover",
            "source nine-level lineage carryover",
            "request and support summary carryover",
            "schema governance registration",
            "twelve-level application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-twelve-level-report-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-twelve-level-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_twelve_level_report.zig",
            "packages/zigeffect/docs/app-facing-twelve-level-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-twelve-level-report",
        .agent_guidance = "Use ready or advisory twelve-level report evidence to start the twelve-level application-boundary branch only. Blocked artifacts are stop signs. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live agent projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-twelve-level-application-boundary",
        .title = "App-Facing Twelve-Level Application Boundary",
        .gap_id = "app-facing-twelve-level-application-boundary",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory twelve-level report evidence, records planned or reviewed local application-boundary evidence, preserves twelve-level report plus eleven-level, ten-level, and nine-level lineage, and prepares the twelve-level policy branch without mutation authority.",
        .depends_on = &.{"app-facing-twelve-level-report"},
        .deliverables = &.{
            "twelve-level application-boundary schema",
            "short alias build step",
            "plan applied and blocked application-boundary artifacts",
            "source twelve-level report gates",
            "source eleven-level lineage carryover",
            "source ten-level lineage carryover",
            "source nine-level lineage carryover",
            "reviewed before after and verification evidence gates",
            "safe after-report fixture",
            "schema governance registration",
            "twelve-level policy handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-twelve-level-application-boundary-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-twelve-level-application-boundary-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_twelve_level_application_boundary.zig",
            "packages/zigeffect/docs/app-facing-twelve-level-application-boundary.md",
            "packages/zigeffect/test/fixtures/app-facing-twelve-level-application-boundary-after-safe.txt",
        },
        .branch = "codex/zigeffect-causal-app-facing-twelve-level-application-boundary",
        .agent_guidance = "Use applied twelve-level application-boundary evidence to start the twelve-level policy branch only. Planned artifacts are preparatory and blocked artifacts are stop signs. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live agent projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-twelve-level-policy",
        .title = "App-Facing Twelve-Level Policy",
        .gap_id = "app-facing-twelve-level-policy",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes applied twelve-level application-boundary evidence, records approve or reject policy evidence, preserves twelve-level report plus eleven-level, ten-level, and nine-level lineage, and prepares the twelve-level evaluator branch without mutation authority.",
        .depends_on = &.{"app-facing-twelve-level-application-boundary"},
        .deliverables = &.{
            "twelve-level policy schema",
            "short alias build step",
            "approve reject policy artifacts",
            "source twelve-level application-boundary gates",
            "source twelve-level report evidence carryover",
            "source eleven-level lineage carryover",
            "source ten-level lineage carryover",
            "source nine-level lineage carryover",
            "interpretation rule and consumption scope catalogs",
            "denied inference and negative fixture catalogs",
            "schema governance registration",
            "twelve-level evaluator handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-twelve-level-policy-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-twelve-level-policy-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_twelve_level_policy.zig",
            "packages/zigeffect/docs/app-facing-twelve-level-policy.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-twelve-level-policy",
        .agent_guidance = "Use approved twelve-level policy evidence to start the twelve-level evaluator branch only. Rejected or blocked artifacts are stop signs. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live agent projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-twelve-level-evaluator",
        .title = "App-Facing Twelve-Level Evaluator",
        .gap_id = "app-facing-twelve-level-evaluator",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes approved twelve-level policy evidence plus bounded request and support evidence, emits ready advisory or blocked evaluator findings, preserves twelve-level policy application and report evidence plus eleven-level, ten-level, and nine-level lineage, and prepares the thirteen-level report branch without mutation authority.",
        .depends_on = &.{"app-facing-twelve-level-policy"},
        .deliverables = &.{
            "twelve-level evaluator schema",
            "short alias build step",
            "ready advisory and blocked evaluator artifacts",
            "source twelve-level policy gates",
            "source twelve-level application-boundary and report carryover",
            "source eleven-level lineage carryover",
            "source ten-level lineage carryover",
            "source nine-level lineage carryover",
            "bounded request classification",
            "support evidence advisory signal",
            "redaction and denied-input guards",
            "schema governance registration",
            "thirteen-level report handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-twelve-level-evaluator-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-twelve-level-evaluator-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_twelve_level_evaluator.zig",
            "packages/zigeffect/docs/app-facing-twelve-level-evaluator.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-twelve-level-evaluator",
        .agent_guidance = "Use ready or advisory twelve-level evaluator evidence to start the thirteen-level report branch only. Blocked artifacts are stop signs. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live agent projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
    },
    .{
        .id = "app-facing-thirteen-level-report",
        .title = "App-Facing Thirteen-Level Report",
        .gap_id = "app-facing-thirteen-level-report",
        .priority = "P1",
        .status = "delivered",
        .summary = "Consumes ready or advisory twelve-level evaluator evidence, emits local thirteen-level report artifacts, preserves twelve-level policy application and report evidence plus eleven-level, ten-level, and nine-level lineage, and prepares the thirteen-level application-boundary branch without mutation authority.",
        .depends_on = &.{"app-facing-twelve-level-evaluator"},
        .deliverables = &.{
            "thirteen-level report schema",
            "short alias build step",
            "ready advisory and blocked report artifacts",
            "source twelve-level evaluator gates",
            "source twelve-level policy application and report carryover",
            "source eleven-level lineage carryover",
            "source ten-level lineage carryover",
            "source nine-level lineage carryover",
            "request and support summary carryover",
            "schema governance registration",
            "thirteen-level application-boundary handoff",
        },
        .evidence_sources = &.{
            "docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-thirteen-level-report-design.md",
            "docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-thirteen-level-report-implementation.md",
            "packages/zigeffect/tools/causal_app_facing_thirteen_level_report.zig",
            "packages/zigeffect/docs/app-facing-thirteen-level-report.md",
        },
        .branch = "codex/zigeffect-causal-app-facing-thirteen-level-report",
        .agent_guidance = "Use ready or advisory thirteen-level report evidence to start the thirteen-level application-boundary branch only. Blocked artifacts are stop signs. Do not infer CI enforcement, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live agent projection, raw payload capture, NenDB writes, NenDB adapter execution, Cockroach scope, production health, hosted dashboard, public upload, auto-apply, registry mutation, or mutation authority.",
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
    "production-hardening-completion-audit",
    "load-test-observation-harness",
    "production-telemetry-capture-design",
    "production-telemetry-capture-fixtures",
    "production-telemetry-readiness-review",
    "production-telemetry-implementation-proposal",
    "production-telemetry-exporter-boundary",
    "production-telemetry-local-pipeline-fixtures",
    "production-telemetry-nendb-retention-fixtures",
    "production-telemetry-workbench-readonly-preview",
    "production-telemetry-ci-artifact-preview",
    "production-telemetry-ci-harness-boundary",
    "production-telemetry-ci-archive-application",
    "production-telemetry-ci-archive-evidence-policy",
    "production-telemetry-ci-gate-readiness",
    "production-telemetry-ci-gate-application-boundary",
    "production-telemetry-ci-gate-dry-run-policy",
    "production-telemetry-ci-gate-dry-run-evaluator",
    "production-telemetry-ci-gate-advisory-ci-report",
    "production-telemetry-ci-gate-advisory-ci-report-application-boundary",
    "production-telemetry-ci-gate-advisory-ci-report-publication-policy",
    "production-telemetry-ci-gate-required-status-check-readiness",
    "production-telemetry-ci-gate-required-status-check-application-boundary",
    "production-telemetry-ci-gate-required-status-check-policy",
    "production-telemetry-ci-gate-required-status-check-enforcement-readiness",
    "production-telemetry-ci-gate-required-status-check-enforcement-application-boundary",
    "production-telemetry-ci-gate-required-status-check-enforcement-policy",
    "production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
    "production-telemetry-ci-gate-required-status-check-enforcement-report",
    "production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
    "production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
    "production-hardening-backlog-refresh",
    "nendb-durable-history-hardening",
    "agent-query-cross-run-comparison",
    "audit-chain-snapshot-compare",
    "app-facing-production-integration-fixtures",
    "app-facing-production-integration-readiness-review",
    "app-facing-production-integration-implementation-proposal",
    "app-facing-production-integration-boundary",
    "app-facing-production-integration-local-fixtures",
    "app-facing-production-integration-nendb-handoff-fixtures",
    "app-facing-production-integration-audit-remediation-bridge",
    "app-facing-production-integration-solid-webui-readonly-preview",
    "app-facing-production-integration-ci-advisory-remediation-report",
    "app-facing-production-integration-ci-advisory-remediation-report-application-boundary",
    "app-facing-production-integration-ci-advisory-remediation-report-publication-policy",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-policy",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
    "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
    "app-facing-eight-level-application-boundary",
    "app-facing-eight-level-policy",
    "app-facing-eight-level-evaluator",
    "app-facing-nine-level-report",
    "app-facing-nine-level-application-boundary",
    "app-facing-nine-level-policy",
    "app-facing-nine-level-evaluator",
    "app-facing-ten-level-report",
    "app-facing-ten-level-application-boundary",
    "app-facing-ten-level-policy",
    "app-facing-ten-level-evaluator",
    "app-facing-eleven-level-report",
    "app-facing-eleven-level-application-boundary",
    "app-facing-eleven-level-policy",
    "app-facing-eleven-level-evaluator",
    "app-facing-twelve-level-report",
    "app-facing-twelve-level-application-boundary",
    "app-facing-twelve-level-policy",
    "app-facing-twelve-level-evaluator",
    "app-facing-thirteen-level-report",
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
    "zig build causal-human-agent-feedback-loop",
    "zig build causal-human-agent-feedback-loop -- --format json",
    "zig build causal-rollout-automation-guardrails",
    "zig build causal-rollout-automation-guardrails -- --format json",
    "zig build causal-wall-clock-benchmark-baselines",
    "zig build causal-wall-clock-benchmark-baselines -- --format json",
    "zig build causal-production-capacity-planning",
    "zig build causal-production-capacity-planning -- --format json",
    "zig build causal-production-hardening-completion-audit",
    "zig build causal-production-hardening-completion-audit -- --format json",
    "zig build causal-load-test-observation-harness",
    "zig build causal-load-test-observation-harness -- --format json",
    "zig build causal-load-test-observation-harness -- observe app-request-trace --iterations 1 --format json",
    "zig build causal-production-telemetry-capture-design",
    "zig build causal-production-telemetry-capture-design -- --format json",
    "zig build causal-production-telemetry-capture-fixtures",
    "zig build causal-production-telemetry-capture-fixtures -- --format json",
    "zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json",
    "zig build causal-production-telemetry-capture-fixtures -- validate --format json",
    "mkdir -p ../../.zig-cache/causal-artifacts",
    "zig build causal-production-telemetry-capture-fixtures -- --format json 2> ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json",
    "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json reject --reason \"negative readiness path\"",
    "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json reject --reason \"negative proposal path\"",
    "zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for local pipeline fixtures\" --verified-command \"zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for exporter boundary planning\\\" --verified-command \\\"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json reject --reason \"negative boundary path\"",
    "zig build causal-production-telemetry-local-pipeline-fixtures -- --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json approve --reason \"approved boundary reviewed for local pipeline fixtures\" --verified-command \"zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason \\\"proposal evidence reviewed for local pipeline fixtures\\\" --verified-command \\\"zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \\\\\\\"ready evidence reviewed for exporter boundary planning\\\\\\\" --verified-command \\\\\\\"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\\\\\\\\\\\\\"fixtures reviewed for implementation proposal\\\\\\\\\\\\\\\" --verified-command \\\\\\\\\\\\\\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\\\\\\\\\\\\\" --verified-command \\\\\\\\\\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\\\\\\\\\" --verified-command \\\\\\\\\\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\\\\\\\\\" --verified-command \\\\\\\\\\\\\\\"zig build examples\\\\\\\\\\\\\\\" --verified-command \\\\\\\\\\\\\\\"zig build test\\\\\\\\\\\\\\\"\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-local-pipeline-fixtures -- --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json reject --reason \"negative local pipeline fixture path\"",
    "zig build causal-production-telemetry-nendb-retention-fixtures -- --from-local-pipeline ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json approve --reason \"approved local pipeline reviewed for NenDB retention fixtures\" --verified-command \"zig build causal-production-telemetry-local-pipeline-fixtures\" --verified-command \"zig build causal-nendb-storage-backend\" --verified-command \"zig build causal-durable-production-retention -- --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-nendb-retention-fixtures -- --from-local-pipeline ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json reject --reason \"negative NenDB retention fixture path\"",
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
    "zig build causal-production-telemetry-workbench-readonly-preview -- --from-retention ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json approve --reason \"read-only SolidJS webui preview reviewed\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-workbench-readonly-preview -- --from-retention ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json reject --reason \"negative workbench preview path\"",
    "zig build causal-production-telemetry-ci-artifact-preview -- --from-workbench ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json approve --reason \"CI artifact preview reviewed\" --verified-command \"zig build causal-production-telemetry-workbench-readonly-preview\" --verified-command \"zig build causal-artifacts\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-ci-artifact-preview -- --from-workbench ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json reject --reason \"negative CI artifact preview path\"",
    "zig build causal-production-telemetry-ci-harness-boundary -- --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json --workflow ../../.github/workflows/zigeffect-causal.yml approve --reason \"CI harness boundary reviewed\" --verified-command \"zig build causal-production-telemetry-ci-artifact-preview\" --verified-command \"zig build causal-artifacts\" --verified-command \"zig build release-gate --summary none\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-ci-harness-boundary -- --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json --workflow ../../.github/workflows/zigeffect-causal.yml reject --reason \"negative CI harness boundary path\"",
    "zig build causal-production-telemetry-ci-archive-application -- --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json plan --reason \"CI archive application planned from reviewed harness boundary\"",
    "zig build causal-production-telemetry-ci-archive-application -- --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json record-applied --reason \"negative archive application path\" --workflow-after ../../.github/workflows/zigeffect-causal.yml --workflow-change \".github/workflows/zigeffect-causal.yml\" --before \"source harness workflow digest\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-archive-application-negative",
    "zig build causal-production-telemetry-ci-archive-evidence-policy -- --from-archive-application ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-application.json approve --reason \"CI archive evidence policy reviewed\" --verified-command \"zig build causal-production-telemetry-ci-archive-application\" --verified-command \"zig build causal-artifacts\" --verified-command \"zig build release-gate --summary none\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-ci-archive-evidence-policy -- --from-archive-application ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-application.json reject --reason \"negative CI archive evidence policy path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-archive-evidence-policy-negative",
    "zig build causal-production-telemetry-ci-gate-readiness -- --from-archive-evidence-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-evidence-policy.json approve --reason \"CI gate readiness reviewed\" --verified-command \"zig build causal-production-telemetry-ci-archive-evidence-policy\" --verified-command \"zig build causal-artifacts\" --verified-command \"zig build release-gate --summary none\" --verified-command \"zig build release-gate-report\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-ci-gate-readiness -- --from-archive-evidence-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-evidence-policy.json reject --reason \"negative CI gate readiness path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-readiness-negative",
    "zig build causal-production-telemetry-ci-gate-application-boundary -- --from-gate-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-readiness.json plan --reason \"CI gate application boundary planned\"",
    "zig build causal-production-telemetry-ci-gate-application-boundary -- --from-gate-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-readiness.json record-applied --reason \"negative CI gate application boundary path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-application-boundary-negative",
    "zig build causal-production-telemetry-ci-gate-dry-run-policy -- --from-gate-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-application-boundary.json approve --reason \"CI gate dry-run policy reviewed\" --verified-command \"zig build causal-production-telemetry-ci-gate-application-boundary\" --verified-command \"zig build causal-artifacts\" --verified-command \"zig build release-gate --summary none\" --verified-command \"zig build release-gate-report\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-ci-gate-dry-run-policy -- --from-gate-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-application-boundary.json reject --reason \"negative CI gate dry-run policy path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-policy-negative",
    "zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- --from-dry-run-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-policy.json evaluate --reason \"CI gate dry-run evidence evaluated\" --evidence .zig-cache/release-gate/zigeffect-release-gate.json --evidence .zig-cache/causal-artifacts/zigeffect-causal-causal-scoped-fiber.json",
    "zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- --from-dry-run-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-policy-negative.json evaluate --reason \"negative CI gate dry-run evaluator path\" --evidence .zig-cache/release-gate/zigeffect-release-gate.json --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-evaluator-negative",
    "zig build causal-production-telemetry-ci-gate-advisory-ci-report -- --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-evaluator.json summarize --reason \"CI advisory report reviewed\"",
    "zig build causal-production-telemetry-ci-gate-advisory-ci-report -- --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-evaluator-negative.json summarize --reason \"negative CI advisory report path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-negative",
    "zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-advisory-ci-report.json plan --reason \"CI advisory report application boundary planned\"",
    "zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-negative.json record-applied --reason \"negative CI advisory report application boundary path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-negative",
    "zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy -- --from-application ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-applied.json approve --reason \"CI advisory report publication policy reviewed\" --verified-command \"zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary\" --verified-command \"zig build causal-artifacts\" --verified-command \"zig build release-gate --summary none\" --verified-command \"zig build release-gate-report\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy -- --from-application ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-negative.json reject --reason \"negative CI advisory report publication policy path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-publication-policy-negative",
    "zig build causal-production-telemetry-ci-gate-required-status-check-readiness -- --from-publication-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-publication-policy.json approve --reason \"required status check readiness reviewed\" --verified-command \"zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy\" --verified-command \"zig build causal-artifacts\" --verified-command \"zig build release-gate --summary none\" --verified-command \"zig build release-gate-report\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-ci-gate-required-status-check-readiness -- --from-publication-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-publication-policy-negative.json reject --reason \"negative required status check readiness path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness-negative",
    "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness.json plan --reason \"required status check application boundary planned\"",
    "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-readiness-negative.json record-applied --reason \"negative required status check application boundary path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary-negative",
    "zig build causal-production-telemetry-ci-gate-required-status-check-policy -- --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary.json approve --reason \"required status check policy reviewed\" --verified-command \"zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary\" --verified-command \"zig build causal-artifacts\" --verified-command \"zig build release-gate --summary none\" --verified-command \"zig build release-gate-report\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-ci-gate-required-status-check-policy -- --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary-negative.json reject --reason \"negative required status check policy path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-policy-negative",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness -- --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-policy.json approve --reason \"required status check enforcement readiness reviewed\" --required-check-name \"zigeffect causal release gate\" --branch-protection-evidence \"reviewed branch protection required status check evidence\" --workflow-evidence \"reviewed release gate workflow evidence\" --failure-mode-evidence \"reviewed failing release gate blocks future required check\" --owner-approval \"reviewed owner approval for future required check enforcement\" --rollback-evidence \"reviewed rollback removes required status check from branch protection\" --verified-command \"zig build causal-production-telemetry-ci-gate-required-status-check-policy\" --verified-command \"zig build causal-artifacts\" --verified-command \"zig build release-gate --summary none\" --verified-command \"zig build release-gate-report\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness -- --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-policy-negative.json reject --reason \"negative required status check enforcement readiness path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness-negative",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness.json plan --reason \"required status check enforcement application boundary planned\"",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness-negative.json record-applied --reason \"negative required status check enforcement application boundary path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary-negative",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.json approve --reason \"required status check enforcement policy reviewed\" --verified-command \"zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary\" --verified-command \"zig build causal-artifacts\" --verified-command \"zig build release-gate --summary none\" --verified-command \"zig build release-gate-report\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary-negative.json reject --reason \"negative required status check enforcement policy path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy.json evaluate --reason \"required status check enforcement evidence evaluated\" --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy.json --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.json --evidence .zig-cache/release-gate/zigeffect-release-gate.json",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative.json evaluate --reason \"negative required status check enforcement evaluator path\" --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative.json --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator-negative",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator.json summarize --reason \"required status check enforcement report reviewed\"",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator-negative.json summarize --reason \"negative required status check enforcement report path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-negative",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report.json plan --reason \"required status check enforcement report application boundary planned\"",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-negative.json record-applied --reason \"negative required status check enforcement report application boundary path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary-negative",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.json approve --reason \"required status check enforcement report policy reviewed\" --verified-command \"zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary\" --verified-command \"zig build causal-artifacts\" --verified-command \"zig build release-gate --summary none\" --verified-command \"zig build release-gate-report\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary-negative.json reject --reason \"negative required status check enforcement report policy path\" --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-policy-negative",
    "zig build causal-production-hardening-backlog -- --format json 2> ../../.zig-cache/causal-artifacts/production-hardening-backlog.json",
    "zig build causal-production-hardening-backlog-refresh -- --from-backlog ../../.zig-cache/causal-artifacts/production-hardening-backlog.json refresh --reason \"production hardening backlog refreshed after report policy\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-nendb-durable-history-hardening",
    "zig build causal-app-facing-production-integration-fixtures",
    "zig build causal-app-facing-production-integration-fixtures -- --format json",
    "zig build causal-app-facing-production-integration-fixtures -- emit worker-request-redacted-lineage --format json",
    "zig build causal-app-facing-production-integration-fixtures -- validate --format json",
    "zig build causal-app-facing-production-integration-fixtures -- --format json 2> ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json",
    "zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-app-facing-production-integration-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json reject --reason \"negative readiness path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-readiness-review-negative",
    "zig build causal-app-facing-production-integration-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for app-facing integration planning\" --verified-command \"zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-app-facing-production-integration-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json reject --reason \"negative proposal path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-implementation-proposal-negative",
    "zig build causal-app-facing-production-integration-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for app-facing local fixtures\" --verified-command \"zig build causal-app-facing-production-integration-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for app-facing integration planning\\\" --verified-command \\\"zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-app-facing-production-integration-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json reject --reason \"negative boundary path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-boundary-negative",
    "zig build causal-app-facing-production-integration-local-fixtures -- --from-boundary ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary.json approve --reason \"guarded boundary reviewed for local app-facing fixtures\" --verified-command \"zig build causal-app-facing-production-integration-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json approve --reason \\\"proposal evidence reviewed for app-facing local fixtures\\\" --verified-command \\\"zig build causal-app-facing-production-integration-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json approve --reason \\\\\\\"ready evidence reviewed for app-facing integration planning\\\\\\\" --verified-command \\\\\\\"zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \\\\\\\\\\\\\\\"fixtures reviewed for implementation proposal\\\\\\\\\\\\\\\" --verified-command \\\\\\\\\\\\\\\"zig build causal-app-facing-production-integration-fixtures -- validate --format json\\\\\\\\\\\\\\\" --verified-command \\\\\\\\\\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\\\\\\\\\" --verified-command \\\\\\\\\\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\\\\\\\\\" --verified-command \\\\\\\\\\\\\\\"zig build examples\\\\\\\\\\\\\\\" --verified-command \\\\\\\\\\\\\\\"zig build test\\\\\\\\\\\\\\\"\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-local-fixtures -- --from-boundary ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary.json reject --reason \"negative local fixtures path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-local-fixtures-negative",
    "zig build causal-app-facing-production-integration-nendb-handoff-fixtures -- --from-local-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures.json approve --reason \"ready local app-facing fixtures reviewed for NenDB handoff fixtures\" --verified-command \"zig build causal-app-facing-production-integration-local-fixtures\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-nendb-handoff-fixtures -- --from-local-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures.json reject --reason \"negative nendb handoff path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-nendb-handoff-fixtures-negative",
    "zig build causal-app-facing-production-integration-audit-remediation-bridge -- --from-handoff ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures.json approve --reason \"ready app-facing NenDB handoff fixtures reviewed for audit remediation bridge\" --verified-command \"zig build causal-app-facing-production-integration-nendb-handoff-fixtures\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-audit-remediation-bridge -- --from-handoff ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures.json reject --reason \"negative audit remediation bridge path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-audit-remediation-bridge-negative",
    "zig build causal-app-facing-production-integration-solid-webui-readonly-preview -- --from-bridge ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-audit-remediation-bridge.json approve --reason \"ready app-facing audit remediation bridge reviewed for SolidJS read-only preview\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-audit-remediation-bridge\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-solid-webui-readonly-preview -- --from-bridge ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-audit-remediation-bridge.json reject --reason \"negative SolidJS read-only preview path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-solid-webui-readonly-preview-negative",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report -- --from-preview ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-solid-webui-readonly-preview.json approve --reason \"ready app-facing SolidJS read-only preview reviewed for CI advisory remediation report\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-solid-webui-readonly-preview\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report -- --from-preview ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-solid-webui-readonly-preview.json reject --reason \"negative CI advisory remediation report path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-negative",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report.json plan --reason \"app-facing advisory remediation report application boundary planned\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-application-boundary-plan",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report.json record-applied --reason \"reviewed app-facing advisory remediation report application boundary\" --report-after ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-after.txt --publication-change \"reviewed local advisory remediation report publication boundary\" --before \"before local advisory report application boundary evidence\" --after \"after local advisory report application boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report.json record-applied --reason \"negative missing evidence path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-application-boundary-negative",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-application-boundary.json approve --reason \"reviewed app-facing advisory remediation report publication policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-application-boundary.json reject --reason \"negative app-facing advisory remediation report publication policy path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-publication-policy-negative",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness -- --from-publication-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-publication-policy.json approve --reason \"reviewed app-facing advisory remediation report consumption readiness\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness -- --from-publication-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-publication-policy.json reject --reason \"negative app-facing advisory remediation report consumption readiness path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-readiness-negative",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-readiness.json plan --reason \"app-facing advisory remediation report consumption boundary planned\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-boundary-plan",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-readiness.json record-applied --reason \"reviewed app-facing advisory remediation report consumption boundary\" --consumer-after ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-boundary-after.txt --consumer-change \"reviewed read-only consumer boundary for agents CI advisory readers reviewers and SolidJS webui\" --before \"before local read-only consumption boundary evidence\" --after \"after local read-only consumption boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-readiness.json record-applied --reason \"negative app-facing advisory remediation report consumption boundary path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-boundary-negative",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy -- --from-boundary ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-boundary.json approve --reason \"reviewed app-facing advisory remediation report consumption policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy -- --from-boundary ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-boundary.json reject --reason \"negative app-facing advisory remediation report consumption policy path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-policy-negative",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-policy.json evaluate --reason \"reviewed app-facing advisory remediation report consumption evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-support.txt",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-policy.json evaluate --reason \"advisory app-facing consumption evaluator missing support evidence\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-evaluator-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-policy.json evaluate --reason \"blocked app-facing consumption evaluator unsafe request\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-request-unsafe.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-evaluator-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-evaluator.json summarize --reason \"reviewed app-facing advisory remediation report consumption report\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-evaluator-advisory.json summarize --reason \"advisory app-facing consumption report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-evaluator-blocked.json summarize --reason \"blocked app-facing consumption report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report.json plan --reason \"app-facing advisory remediation report consumption report application boundary planned\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-application-boundary-plan",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report.json record-applied --reason \"reviewed app-facing advisory remediation report consumption report application boundary\" --report-after ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-application-after.txt --report-application-change \"reviewed local consumption report application boundary for agents reviewers CI advisory readers and SolidJS webui\" --before \"before local consumption report application boundary evidence\" --after \"after local consumption report application boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-blocked.json record-applied --reason \"blocked app-facing consumption report application boundary source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-application-boundary-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-application-boundary.json approve --reason \"reviewed app-facing advisory remediation report consumption report policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-application-boundary.json reject --reason \"negative app-facing advisory remediation report consumption report policy path\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-policy-negative",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-application-boundary-blocked.json approve --reason \"blocked app-facing advisory remediation report consumption report policy source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-policy-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-policy.json evaluate --reason \"reviewed app-facing advisory remediation report consumption report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluator-support.txt",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-policy.json evaluate --reason \"advisory app-facing advisory remediation report consumption report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluator-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-policy-blocked.json evaluate --reason \"blocked app-facing advisory remediation report consumption report evaluator source\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluator-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-evaluator.json summarize --reason \"reviewed app-facing advisory remediation report consumption report evaluation report\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluator-advisory.json summarize --reason \"advisory app-facing advisory remediation report consumption report evaluation report\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluator-blocked.json summarize --reason \"blocked app-facing advisory remediation report consumption report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-evaluation-report.json plan --reason \"app-facing advisory remediation report consumption report evaluation report application boundary planned\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary-plan",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-evaluation-report.json record-applied --reason \"reviewed app-facing advisory remediation report consumption report evaluation report application boundary\" --evaluation-report-after ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-application-after.txt --evaluation-report-application-change \"reviewed local evaluation report application boundary for agents reviewers CI advisory readers and SolidJS webui\" --before \"before local evaluation report application boundary evidence\" --after \"after local evaluation report application boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-blocked.json record-applied --reason \"blocked app-facing advisory remediation report consumption report evaluation report application boundary source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.json approve --reason \"reviewed app-facing advisory remediation report consumption report evaluation report policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.json reject --reason \"blocked app-facing advisory remediation report consumption report evaluation report policy\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-policy-reject",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.json evaluate --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator-support.txt",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.json evaluate --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-policy-reject.json evaluate --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluator source\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator.json summarize --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator-advisory.json summarize --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator-blocked.json summarize --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report.json plan --reason \"app-facing advisory remediation report consumption report evaluation report evaluation report application boundary planned\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-plan",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report.json record-applied --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report application boundary\" --evaluation-report-evaluation-report-after ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-after.txt --evaluation-report-evaluation-report-application-change \"reviewed local evaluation report evaluation report application boundary for agents reviewers CI advisory readers and SolidJS webui\" --before \"before local evaluation report evaluation report application boundary evidence\" --after \"after local evaluation report evaluation report application boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-blocked.json record-applied --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report application boundary source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-1559c7e904ae31e2.json approve --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-1559c7e904ae31e2.json reject --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report policy\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy-reject",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-blocked.json approve --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report policy source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-1559c7e904ae31e2-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy.json evaluate --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator-support.txt",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-1559c7e904ae31e2-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy.json evaluate --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy-blocked.json evaluate --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluator source\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-1559c7e904ae31e2-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator.json summarize --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator-advisory.json summarize --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator-blocked.json summarize --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-1559c7e904ae31e2-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report.json plan --reason \"app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report application boundary planned\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-plan",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-1559c7e904ae31e2-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report.json record-applied --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report application boundary\" --evaluation-report-evaluation-report-evaluation-report-after ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-after.txt --evaluation-report-evaluation-report-evaluation-report-application-change \"reviewed local evaluation report evaluation report evaluation report application boundary for agents reviewers CI advisory readers and SolidJS webui\" --before \"before local evaluation report evaluation report evaluation report application boundary evidence\" --after \"after local evaluation report evaluation report evaluation report application boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-blocked.json record-applied --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report application boundary source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-8647693e68603dc4.json approve --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-8647693e68603dc4.json reject --reason \"rejected app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report policy\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy-reject",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-blocked.json approve --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report policy source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy-ab1d305b37585600.json evaluate --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-support.txt",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy-ab1d305b37585600.json evaluate --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy-blocked.json evaluate --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluator source\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-88227538b2cab4f7.json summarize --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory.json summarize --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked.json summarize --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-1ed481ad46bc4cf1.json plan --reason \"app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report application boundary planned\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-plan",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-1ed481ad46bc4cf1.json record-applied --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report application boundary\" --evaluation-report-evaluation-report-evaluation-report-evaluation-report-after ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-after.txt --evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change \"reviewed local evaluation report evaluation report evaluation report evaluation report application boundary for agents reviewers CI advisory readers and SolidJS webui\" --before \"before local evaluation report evaluation report evaluation report evaluation report application boundary evidence\" --after \"after local evaluation report evaluation report evaluation report evaluation report application boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked.json record-applied --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report application boundary source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-fa99b12beae01779.json approve --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-fa99b12beae01779.json reject --reason \"rejected app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report policy\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-reject",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-51930a87ca49b501.json evaluate --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-support.txt",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-51930a87ca49b501.json evaluate --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-blocked.json evaluate --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluator source\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-882f94f2e9f86dc1.json summarize --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory.json summarize --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked.json summarize --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-703575bb1247cd12.json plan --reason \"planned app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-703575bb1247cd12.json record-applied --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary\" --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change \"reviewed local evaluation report evaluation report evaluation report evaluation report evaluation report application boundary for agents reviewers CI advisory readers and SolidJS webui\" --before \"before local evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence\" --after \"after local evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence\" --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-after test/fixtures/app-facing-five-level-application-boundary-after-safe.txt --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked.json record-applied --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary source\" --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change \"blocked local evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence\" --before \"blocked before evidence\" --after \"blocked after evidence\" --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-after ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked.txt --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json approve --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json reject --reason \"rejected app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report policy\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-reject",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-blocked.json approve --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report policy source\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.json evaluate --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-support.txt",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.json evaluate --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-blocked.json evaluate --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator source\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.json summarize --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory.json summarize --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked.json summarize --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json plan --reason \"planned app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-plan",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json record-applied --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary\" --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-after test/fixtures/app-facing-six-level-application-boundary-after-safe.txt --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change \"reviewed local evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary for agents reviewers CI advisory readers and SolidJS webui\" --before \"before local evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence\" --after \"after local evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked.json record-applied --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json approve --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json reject --reason \"rejected app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-reject",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-blocked.json approve --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy source\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.json evaluate --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-support.txt",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.json evaluate --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-blocked.json evaluate --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator source\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.json summarize --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report\"",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory.json summarize --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked.json summarize --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json plan --reason \"planned app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-plan",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json record-applied --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary\" --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-after test/fixtures/app-facing-seven-level-application-boundary-after-safe.txt --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change \"reviewed local evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary for agents reviewers CI advisory readers and SolidJS webui\" --before \"before local evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence\" --after \"after local evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked.json record-applied --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json approve --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json reject --reason \"rejected app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-reject",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-blocked.json approve --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy source\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.json evaluate --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-support.txt --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.json evaluate --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator missing support\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy-blocked.json evaluate --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator source\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help",
    "zig build causal-app-facing-eight-level-application-boundary -- --help",
    "zig build causal-app-facing-eight-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json plan --reason \"planned app-facing eight-level application boundary\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-application-boundary-plan",
    "zig build causal-app-facing-eight-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json record-applied --reason \"reviewed app-facing eight-level application boundary\" --after-report test/fixtures/app-facing-eight-level-application-boundary-after-safe.txt --application-change \"reviewed local eight-level application boundary for agents reviewers CI advisory readers and SolidJS webui\" --before \"before local eight-level application boundary evidence\" --after \"after local eight-level application boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-application-boundary",
    "zig build causal-app-facing-eight-level-policy -- --help",
    "zig build causal-app-facing-eight-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-application-boundary.json approve --reason \"reviewed app-facing eight-level policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-eight-level-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-policy",
    "zig build causal-app-facing-eight-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-application-boundary.json reject --reason \"rejected app-facing eight-level policy\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-policy-reject",
    "zig build causal-app-facing-eight-level-evaluator -- --help",
    "zig build causal-app-facing-eight-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-policy.json evaluate --reason \"reviewed app-facing eight-level evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-support.txt --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator",
    "zig build causal-app-facing-eight-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-policy.json evaluate --reason \"advisory app-facing eight-level evaluator missing support\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-advisory",
    "zig build causal-app-facing-eight-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-policy-reject.json evaluate --reason \"blocked app-facing eight-level evaluator source\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-blocked",
    "zig build causal-app-facing-nine-level-report -- --help",
    "zig build causal-app-facing-nine-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator.json summarize --reason \"reviewed app-facing nine-level report\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-report",
    "zig build causal-app-facing-nine-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-advisory.json summarize --reason \"advisory app-facing nine-level report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-report-advisory",
    "zig build causal-app-facing-nine-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-blocked.json summarize --reason \"blocked app-facing nine-level report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-report-blocked",
    "zig build causal-app-facing-nine-level-application-boundary -- --help",
    "zig build causal-app-facing-nine-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-report.json plan --reason \"planned app-facing nine-level application boundary\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-application-boundary-plan",
    "zig build causal-app-facing-nine-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-report.json record-applied --reason \"reviewed app-facing nine-level application boundary\" --after-report test/fixtures/app-facing-nine-level-application-boundary-after-safe.txt --application-change \"reviewed local nine-level application boundary for agents reviewers CI advisory readers and SolidJS webui\" --before \"before local nine-level application boundary evidence\" --after \"after local nine-level application boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-nine-level-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-application-boundary",
    "zig build causal-app-facing-nine-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-report-blocked.json record-applied --reason \"blocked app-facing nine-level application boundary source\" --after-report test/fixtures/app-facing-nine-level-application-boundary-after-safe.txt --application-change \"reviewed local nine-level blocked source boundary probe\" --before \"before local nine-level blocked source evidence\" --after \"after local nine-level blocked source evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-nine-level-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-application-boundary-blocked",
    "zig build causal-app-facing-nine-level-policy -- --help",
    "zig build causal-app-facing-nine-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-application-boundary.json approve --reason \"reviewed app-facing nine-level policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-nine-level-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-policy",
    "zig build causal-app-facing-nine-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-application-boundary.json reject --reason \"rejected app-facing nine-level policy\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-policy-reject",
    "zig build causal-app-facing-nine-level-evaluator -- --help",
    "zig build causal-app-facing-nine-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-policy.json evaluate --reason \"reviewed app-facing nine-level evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-evaluator-support.txt --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-evaluator",
    "zig build causal-app-facing-nine-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-policy.json evaluate --reason \"advisory app-facing nine-level evaluator missing support\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-evaluator-advisory",
    "zig build causal-app-facing-nine-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-policy-reject.json evaluate --reason \"blocked app-facing nine-level evaluator source\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-evaluator-blocked",
    "zig build causal-app-facing-ten-level-report -- --help",
    "zig build causal-app-facing-ten-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-evaluator.json summarize --reason \"reviewed app-facing ten-level report\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-report",
    "zig build causal-app-facing-ten-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-evaluator-advisory.json summarize --reason \"advisory app-facing ten-level report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-report-advisory",
    "zig build causal-app-facing-ten-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-nine-level-evaluator-blocked.json summarize --reason \"blocked app-facing ten-level report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-report-blocked",
    "zig build causal-app-facing-ten-level-application-boundary -- --help",
    "zig build causal-app-facing-ten-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-report.json plan --reason \"planned app-facing ten-level application boundary\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-application-boundary-plan",
    "zig build causal-app-facing-ten-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-report.json record-applied --reason \"reviewed app-facing ten-level application boundary\" --after-report test/fixtures/app-facing-ten-level-application-boundary-after-safe.txt --application-change \"reviewed local ten-level application boundary for agents reviewers CI advisory readers and SolidJS webui\" --before \"before local ten-level application boundary evidence\" --after \"after local ten-level application boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-ten-level-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-application-boundary",
    "zig build causal-app-facing-ten-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-report-blocked.json record-applied --reason \"blocked app-facing ten-level application boundary source\" --after-report test/fixtures/app-facing-ten-level-application-boundary-after-safe.txt --application-change \"reviewed local ten-level blocked source boundary probe\" --before \"before local ten-level blocked source evidence\" --after \"after local ten-level blocked source evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-ten-level-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-application-boundary-blocked",
    "zig build causal-app-facing-ten-level-policy -- --help",
    "zig build causal-app-facing-ten-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-application-boundary.json approve --reason \"reviewed app-facing ten-level policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-ten-level-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-policy",
    "zig build causal-app-facing-ten-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-application-boundary.json reject --reason \"rejected app-facing ten-level policy\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-policy-reject",
    "zig build causal-app-facing-ten-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-application-boundary-blocked.json approve --reason \"blocked source app-facing ten-level policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-ten-level-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-policy-blocked",
    "zig build causal-app-facing-ten-level-evaluator -- --help",
    "zig build causal-app-facing-ten-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-policy.json evaluate --reason \"reviewed app-facing ten-level evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-support.txt --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator",
    "zig build causal-app-facing-ten-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-policy.json evaluate --reason \"advisory app-facing ten-level evaluator missing support\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-advisory",
    "zig build causal-app-facing-ten-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-policy-reject.json evaluate --reason \"blocked app-facing ten-level evaluator source\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-blocked",
    "zig build causal-app-facing-eleven-level-report -- --help",
    "zig build causal-app-facing-eleven-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator.json summarize --reason \"reviewed app-facing eleven-level report\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report",
    "zig build causal-app-facing-eleven-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-advisory.json summarize --reason \"advisory app-facing eleven-level report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-advisory",
    "zig build causal-app-facing-eleven-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-blocked.json summarize --reason \"blocked app-facing eleven-level report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-blocked",
    "zig build causal-app-facing-eleven-level-application-boundary -- --help",
    "zig build causal-app-facing-eleven-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report.json plan --reason \"planned app-facing eleven-level application boundary\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-application-boundary-plan",
    "zig build causal-app-facing-eleven-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report.json record-applied --reason \"reviewed app-facing eleven-level application boundary\" --after-report test/fixtures/app-facing-eleven-level-application-boundary-after-safe.txt --application-change \"reviewed local eleven-level application boundary for agents reviewers CI advisory readers and SolidJS webui\" --before \"before local eleven-level application boundary evidence\" --after \"after local eleven-level application boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-eleven-level-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-application-boundary",
    "zig build causal-app-facing-eleven-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-blocked.json record-applied --reason \"blocked app-facing eleven-level application boundary source\" --after-report test/fixtures/app-facing-eleven-level-application-boundary-after-safe.txt --application-change \"reviewed local eleven-level blocked source boundary probe\" --before \"before local eleven-level blocked source evidence\" --after \"after local eleven-level blocked source evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-eleven-level-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-application-boundary-blocked",
    "zig build causal-app-facing-eleven-level-policy -- --help",
    "zig build causal-app-facing-eleven-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-application-boundary.json approve --reason \"reviewed app-facing eleven-level policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-eleven-level-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-policy",
    "zig build causal-app-facing-eleven-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-application-boundary.json reject --reason \"rejected app-facing eleven-level policy\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-policy-reject",
    "zig build causal-app-facing-eleven-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-application-boundary-blocked.json approve --reason \"blocked source app-facing eleven-level policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-eleven-level-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-policy-blocked",
    "zig build causal-app-facing-eleven-level-evaluator -- --help",
    "zig build causal-app-facing-eleven-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-policy.json evaluate --reason \"reviewed app-facing eleven-level evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-support.txt --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator",
    "zig build causal-app-facing-eleven-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-policy.json evaluate --reason \"advisory app-facing eleven-level evaluator missing support\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-advisory",
    "zig build causal-app-facing-eleven-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-policy-reject.json evaluate --reason \"blocked app-facing eleven-level evaluator source\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-blocked",
    "zig build causal-app-facing-twelve-level-report -- --help",
    "zig build causal-app-facing-twelve-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator.json summarize --reason \"reviewed app-facing twelve-level report\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report",
    "zig build causal-app-facing-twelve-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-advisory.json summarize --reason \"advisory app-facing twelve-level report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report-advisory",
    "zig build causal-app-facing-twelve-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-blocked.json summarize --reason \"blocked app-facing twelve-level report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report-blocked",
    "zig build causal-app-facing-twelve-level-application-boundary -- --help",
    "zig build causal-app-facing-twelve-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report.json plan --reason \"planned app-facing twelve-level application boundary\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-application-boundary-plan",
    "zig build causal-app-facing-twelve-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report.json record-applied --reason \"reviewed app-facing twelve-level application boundary\" --after-report test/fixtures/app-facing-twelve-level-application-boundary-after-safe.txt --application-change \"reviewed local twelve-level application boundary for agents reviewers CI advisory readers and SolidJS webui\" --before \"before local twelve-level application boundary evidence\" --after \"after local twelve-level application boundary evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-twelve-level-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-application-boundary",
    "zig build causal-app-facing-twelve-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report-blocked.json record-applied --reason \"blocked app-facing twelve-level application boundary source\" --after-report test/fixtures/app-facing-twelve-level-application-boundary-after-safe.txt --application-change \"reviewed local twelve-level blocked source boundary probe\" --before \"before local twelve-level blocked source evidence\" --after \"after local twelve-level blocked source evidence\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-twelve-level-report -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-application-boundary-blocked",
    "zig build causal-app-facing-twelve-level-policy -- --help",
    "zig build causal-app-facing-twelve-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-application-boundary.json approve --reason \"reviewed app-facing twelve-level policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-twelve-level-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy",
    "zig build causal-app-facing-twelve-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-application-boundary.json reject --reason \"rejected app-facing twelve-level policy\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy-reject",
    "zig build causal-app-facing-twelve-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-application-boundary-blocked.json approve --reason \"blocked source app-facing twelve-level policy\" --verified-command \"bun run zigeffect:workbench:typecheck\" --verified-command \"bun run zigeffect:workbench:test\" --verified-command \"zig build causal-app-facing-twelve-level-application-boundary -- --help\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy-blocked",
    "zig build causal-app-facing-twelve-level-evaluator -- --help",
    "zig build causal-app-facing-twelve-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy.json evaluate --reason \"reviewed app-facing twelve-level evaluator\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-support.txt --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator",
    "zig build causal-app-facing-twelve-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy.json evaluate --reason \"advisory app-facing twelve-level evaluator missing support\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-advisory",
    "zig build causal-app-facing-twelve-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy-reject.json evaluate --reason \"blocked app-facing twelve-level evaluator source\" --request ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-blocked",
    "zig build causal-app-facing-thirteen-level-report -- --help",
    "zig build causal-app-facing-thirteen-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator.json summarize --reason \"reviewed app-facing thirteen-level report\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report",
    "zig build causal-app-facing-thirteen-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-advisory.json summarize --reason \"advisory app-facing thirteen-level report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report-advisory",
    "zig build causal-app-facing-thirteen-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-blocked.json summarize --reason \"blocked app-facing thirteen-level report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report-blocked",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.json summarize --reason \"reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory.json summarize --reason \"advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-advisory",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked.json summarize --reason \"blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report source\" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked",
    "zig test --dep causal_artifact -Mroot=tools/causal_query.zig -Mcausal_artifact=tools/causal_artifact.zig",
    "zig test --dep causal_artifact --dep causal_compare --dep causal_run -Mroot=tools/causal_snapshot.zig -Mcausal_artifact=tools/causal_artifact.zig --dep causal_artifact -Mcausal_compare=tools/causal_compare.zig -Mcausal_run=tools/causal_run.zig",
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
        "start-app-facing-thirteen-level-application-boundary",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-thirteen-level-application-boundary",
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
    try expectBacklogItemStatus("agent-query-interface", "delivered");
    try expectBacklogItem("encryption-at-rest-policy");
    try expectBacklogItem("alerting-integrations");
    try expectBacklogItemStatus("alerting-integrations", "delivered");
    try expectBacklogItem("live-dashboard-streaming-workbench");
    try expectBacklogItemStatus("live-dashboard-streaming-workbench", "delivered");
    try expectBacklogItem("workbench-graph-visual-debugging");
    try expectBacklogItemStatus("workbench-graph-visual-debugging", "delivered");
    try expectBacklogItem("human-agent-feedback-loop");
    try expectBacklogItemStatus("human-agent-feedback-loop", "delivered");
    try expectBacklogItem("rollout-automation-guardrails");
    try expectBacklogItemStatus("rollout-automation-guardrails", "delivered");
    try expectBacklogItem("wall-clock-benchmark-baselines");
    try expectBacklogItemStatus("wall-clock-benchmark-baselines", "delivered");
    try expectBacklogItem("production-capacity-planning");
    try expectBacklogItemStatus("production-capacity-planning", "delivered");
    try expectBacklogItem("production-hardening-completion-audit");
    try expectBacklogItemStatus("production-hardening-completion-audit", "delivered");
    try expectBacklogItem("load-test-observation-harness");
    try expectBacklogItemStatus("load-test-observation-harness", "delivered");
    try expectBacklogItem("production-telemetry-capture-design");
    try expectBacklogItemStatus("production-telemetry-capture-design", "delivered");
    try expectBacklogItem("production-telemetry-capture-fixtures");
    try expectBacklogItemStatus("production-telemetry-capture-fixtures", "delivered");
    try expectBacklogItem("production-telemetry-readiness-review");
    try expectBacklogItemStatus("production-telemetry-readiness-review", "delivered");
    try expectBacklogItem("production-telemetry-implementation-proposal");
    try expectBacklogItemStatus("production-telemetry-implementation-proposal", "delivered");
    try expectBacklogItem("production-telemetry-exporter-boundary");
    try expectBacklogItemStatus("production-telemetry-exporter-boundary", "delivered");
    try expectBacklogItem("production-telemetry-local-pipeline-fixtures");
    try expectBacklogItemStatus("production-telemetry-local-pipeline-fixtures", "delivered");
    try expectBacklogItem("production-telemetry-nendb-retention-fixtures");
    try expectBacklogItemStatus("production-telemetry-nendb-retention-fixtures", "delivered");
    try expectBacklogItem("production-telemetry-workbench-readonly-preview");
    try expectBacklogItemStatus("production-telemetry-workbench-readonly-preview", "delivered");
    try expectBacklogItem("production-telemetry-ci-artifact-preview");
    try expectBacklogItemStatus("production-telemetry-ci-artifact-preview", "delivered");
    try expectBacklogItem("production-telemetry-ci-harness-boundary");
    try expectBacklogItemStatus("production-telemetry-ci-harness-boundary", "delivered");
    try expectBacklogItem("production-telemetry-ci-archive-application");
    try expectBacklogItemStatus("production-telemetry-ci-archive-application", "delivered");
    try expectBacklogItem("production-telemetry-ci-archive-evidence-policy");
    try expectBacklogItemStatus("production-telemetry-ci-archive-evidence-policy", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-readiness");
    try expectBacklogItemStatus("production-telemetry-ci-gate-readiness", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-application-boundary");
    try expectBacklogItemStatus("production-telemetry-ci-gate-application-boundary", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-dry-run-policy");
    try expectBacklogItemStatus("production-telemetry-ci-gate-dry-run-policy", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-dry-run-evaluator");
    try expectBacklogItemStatus("production-telemetry-ci-gate-dry-run-evaluator", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-advisory-ci-report");
    try expectBacklogItemStatus("production-telemetry-ci-gate-advisory-ci-report", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-advisory-ci-report-application-boundary");
    try expectBacklogItemStatus("production-telemetry-ci-gate-advisory-ci-report-application-boundary", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-advisory-ci-report-publication-policy");
    try expectBacklogItemStatus("production-telemetry-ci-gate-advisory-ci-report-publication-policy", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-required-status-check-readiness");
    try expectBacklogItemStatus("production-telemetry-ci-gate-required-status-check-readiness", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-required-status-check-application-boundary");
    try expectBacklogItemStatus("production-telemetry-ci-gate-required-status-check-application-boundary", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-required-status-check-policy");
    try expectBacklogItemStatus("production-telemetry-ci-gate-required-status-check-policy", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-required-status-check-enforcement-readiness");
    try expectBacklogItemStatus("production-telemetry-ci-gate-required-status-check-enforcement-readiness", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-required-status-check-enforcement-application-boundary");
    try expectBacklogItemStatus("production-telemetry-ci-gate-required-status-check-enforcement-application-boundary", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-required-status-check-enforcement-policy");
    try expectBacklogItemStatus("production-telemetry-ci-gate-required-status-check-enforcement-policy", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-required-status-check-enforcement-evaluator");
    try expectBacklogItemStatus("production-telemetry-ci-gate-required-status-check-enforcement-evaluator", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-required-status-check-enforcement-report");
    try expectBacklogItemStatus("production-telemetry-ci-gate-required-status-check-enforcement-report", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary");
    try expectBacklogItemStatus("production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary", "delivered");
    try expectBacklogItem("production-telemetry-ci-gate-required-status-check-enforcement-report-policy");
    try expectBacklogItemStatus("production-telemetry-ci-gate-required-status-check-enforcement-report-policy", "delivered");
    try expectBacklogItem("production-hardening-backlog-refresh");
    try expectBacklogItemStatus("production-hardening-backlog-refresh", "delivered");
    try expectBacklogItem("nendb-durable-history-hardening");
    try expectBacklogItemStatus("nendb-durable-history-hardening", "delivered");
    try expectBacklogItem("agent-query-cross-run-comparison");
    try expectBacklogItemStatus("agent-query-cross-run-comparison", "delivered");
    try expectBacklogItem("audit-chain-snapshot-compare");
    try expectBacklogItemStatus("audit-chain-snapshot-compare", "delivered");
    try expectBacklogItem("app-facing-production-integration-fixtures");
    try expectBacklogItemStatus("app-facing-production-integration-fixtures", "delivered");
    try expectBacklogItem("app-facing-production-integration-readiness-review");
    try expectBacklogItemStatus("app-facing-production-integration-readiness-review", "delivered");
    try expectBacklogItem("app-facing-production-integration-implementation-proposal");
    try expectBacklogItemStatus("app-facing-production-integration-implementation-proposal", "delivered");
    try expectBacklogItem("app-facing-production-integration-boundary");
    try expectBacklogItemStatus("app-facing-production-integration-boundary", "delivered");
    try expectBacklogItem("app-facing-production-integration-local-fixtures");
    try expectBacklogItemStatus("app-facing-production-integration-local-fixtures", "delivered");
    try expectBacklogItem("app-facing-production-integration-nendb-handoff-fixtures");
    try expectBacklogItemStatus("app-facing-production-integration-nendb-handoff-fixtures", "delivered");
    try expectBacklogItem("app-facing-production-integration-audit-remediation-bridge");
    try expectBacklogItemStatus("app-facing-production-integration-audit-remediation-bridge", "delivered");
    try expectBacklogItem("app-facing-production-integration-solid-webui-readonly-preview");
    try expectBacklogItemStatus("app-facing-production-integration-solid-webui-readonly-preview", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-application-boundary");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-application-boundary", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-publication-policy");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-publication-policy", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-policy");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-policy", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "delivered");
    try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report");
    try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "delivered");
    try expectBacklogItem("app-facing-eight-level-application-boundary");
    try expectBacklogItemStatus("app-facing-eight-level-application-boundary", "delivered");
    try expectBacklogItem("app-facing-eight-level-policy");
    try expectBacklogItemStatus("app-facing-eight-level-policy", "delivered");
    try expectBacklogItem("app-facing-nine-level-policy");
    try expectBacklogItemStatus("app-facing-nine-level-policy", "delivered");
    try expectBacklogItem("app-facing-nine-level-evaluator");
    try expectBacklogItemStatus("app-facing-nine-level-evaluator", "delivered");
    try expectBacklogItem("app-facing-ten-level-report");
    try expectBacklogItemStatus("app-facing-ten-level-report", "delivered");
    try expectBacklogItem("app-facing-ten-level-application-boundary");
    try expectBacklogItemStatus("app-facing-ten-level-application-boundary", "delivered");
    try expectBacklogItem("app-facing-ten-level-policy");
    try expectBacklogItemStatus("app-facing-ten-level-policy", "delivered");
    try expectBacklogItem("app-facing-ten-level-evaluator");
    try expectBacklogItemStatus("app-facing-ten-level-evaluator", "delivered");
    try expectBacklogItem("app-facing-eleven-level-report");
    try expectBacklogItemStatus("app-facing-eleven-level-report", "delivered");
    try expectBacklogItem("app-facing-eleven-level-application-boundary");
    try expectBacklogItemStatus("app-facing-eleven-level-application-boundary", "delivered");
    try expectBacklogItem("app-facing-eleven-level-policy");
    try expectBacklogItemStatus("app-facing-eleven-level-policy", "delivered");
    try expectBacklogItem("app-facing-eleven-level-evaluator");
    try expectBacklogItemStatus("app-facing-eleven-level-evaluator", "delivered");
    try expectBacklogItem("app-facing-twelve-level-report");
    try expectBacklogItemStatus("app-facing-twelve-level-report", "delivered");
    try expectBacklogItem("app-facing-twelve-level-application-boundary");
    try expectBacklogItemStatus("app-facing-twelve-level-application-boundary", "delivered");
    try expectBacklogItem("app-facing-twelve-level-policy");
    try expectBacklogItemStatus("app-facing-twelve-level-policy", "delivered");
    try expectBacklogItem("app-facing-twelve-level-evaluator");
    try expectBacklogItemStatus("app-facing-twelve-level-evaluator", "delivered");
    try expectBacklogItem("app-facing-thirteen-level-report");
    try expectBacklogItemStatus("app-facing-thirteen-level-report", "delivered");
}

test "production hardening backlog preserves user constraints" {
    try expectConstraint("durable storage direction: NenDB adapter only");
    try expectConstraint("workbench direction: SolidJS inside webui-dev/zig-webui");
    try expectConstraint("visual graph adapter starts with @dschz/solid-g6 over @antv/g6; solid-flow remains optional editor research");
    try expectConstraint("human workbench and agent query interface share one causal truth model but expose separate ergonomics");
    try expectNonGoal("non-NenDB durable adapter work");
    try expectNonGoal("alternate frontend renderer support");
    try expectNonGoal("production mutation authority");
}

test "production hardening backlog text mentions dependency order and next branch" {
    const allocator = std.testing.allocator;
    const report = try formatProductionHardeningBacklogText(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.production-hardening-backlog.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "recommended next branch: codex/zigeffect-causal-app-facing-thirteen-level-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "dependency order:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-artifact-aggregation") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-deployment-runbooks") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "artifact-access-control") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "unified-causal-spine-contract") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "agent-query-interface") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-capacity-planning") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-capacity-planning") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-hardening-completion-audit") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-hardening-completion-audit") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "load-test-observation-harness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-load-test-observation-harness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-capture-design") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-capture-design") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-capture-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-capture-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-readiness-review") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-readiness-review") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-implementation-proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-implementation-proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-exporter-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-exporter-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-local-pipeline-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-local-pipeline-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-nendb-retention-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-nendb-retention-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-workbench-readonly-preview") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-workbench-readonly-preview") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-artifact-preview") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-artifact-preview") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-harness-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-harness-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-archive-application") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-archive-application") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-archive-evidence-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-archive-evidence-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-dry-run-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-dry-run-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-dry-run-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-dry-run-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-advisory-ci-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-advisory-ci-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-advisory-ci-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-advisory-ci-report-publication-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-required-status-check-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-required-status-check-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-required-status-check-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-required-status-check-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-required-status-check-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-required-status-check-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-required-status-check-enforcement-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-required-status-check-enforcement-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-required-status-check-enforcement-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-required-status-check-enforcement-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-required-status-check-enforcement-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-required-status-check-enforcement-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-required-status-check-enforcement-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-telemetry-ci-gate-required-status-check-enforcement-report-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-hardening-backlog-refresh") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-production-hardening-backlog-refresh") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "nendb-durable-history-hardening") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-nendb-durable-history-hardening") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "agent-query-cross-run-comparison") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "codex/zigeffect-causal-agent-query-compare-runs") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "audit-chain-snapshot-compare") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "codex/zigeffect-causal-audit-chain-snapshot-compare") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-readiness-review") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-readiness-review") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-implementation-proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-implementation-proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-local-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-local-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-nendb-handoff-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-nendb-handoff-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-audit-remediation-bridge") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-audit-remediation-bridge") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-solid-webui-readonly-preview") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-solid-webui-readonly-preview") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-ci-advisory-remediation-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-ci-advisory-remediation-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-ci-advisory-remediation-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-ci-advisory-remediation-report-publication-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-ci-advisory-remediation-report-consumption-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-ci-advisory-remediation-report-consumption-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-eight-level-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-eight-level-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-eight-level-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-eight-level-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-nine-level-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-nine-level-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-nine-level-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-nine-level-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-ten-level-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-ten-level-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-ten-level-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-ten-level-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-ten-level-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-ten-level-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-eleven-level-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-eleven-level-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-eleven-level-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-eleven-level-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-eleven-level-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-eleven-level-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-eleven-level-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-eleven-level-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-twelve-level-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-twelve-level-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-twelve-level-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-twelve-level-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-twelve-level-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-twelve-level-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-twelve-level-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-twelve-level-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-thirteen-level-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-thirteen-level-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy") != null);
}

test "production hardening backlog JSON is agent-readable" {
    const allocator = std.testing.allocator;
    const report = try formatProductionHardeningBacklogJson(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-hardening-backlog.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"recommended_next_branch\": \"codex/zigeffect-causal-app-facing-thirteen-level-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-eight-level-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-eight-level-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-eight-level-application-boundary -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-eight-level-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-eight-level-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-eight-level-policy -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-eight-level-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-eight-level-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-eight-level-evaluator -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-nine-level-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-nine-level-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-nine-level-report -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-nine-level-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-nine-level-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-nine-level-application-boundary -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-nine-level-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-nine-level-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-nine-level-policy -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-nine-level-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-nine-level-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-nine-level-evaluator -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-ten-level-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-ten-level-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-ten-level-report -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-ten-level-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-ten-level-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-ten-level-application-boundary -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-ten-level-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-ten-level-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-ten-level-policy -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-ten-level-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-ten-level-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-ten-level-evaluator -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-eleven-level-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-eleven-level-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-eleven-level-report -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-eleven-level-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-eleven-level-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-eleven-level-application-boundary -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-eleven-level-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-eleven-level-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-eleven-level-policy -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-eleven-level-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-eleven-level-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-eleven-level-evaluator -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-twelve-level-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-twelve-level-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-twelve-level-report -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-twelve-level-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-twelve-level-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-twelve-level-application-boundary -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-twelve-level-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-twelve-level-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-twelve-level-policy -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-twelve-level-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-twelve-level-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-twelve-level-evaluator -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-thirteen-level-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-thirteen-level-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-thirteen-level-report -- --help") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"global_constraints\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"backlog_items\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"human-agent-feedback-loop\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-human-agent-feedback-loop\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"rollout-automation-guardrails\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-rollout-automation-guardrails\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"wall-clock-benchmark-baselines\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-wall-clock-benchmark-baselines\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-capacity-planning\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-capacity-planning\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-capacity-planning -- --format json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-hardening-completion-audit\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-hardening-completion-audit\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-hardening-completion-audit -- --format json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"agent-query-cross-run-comparison\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-agent-query-compare-runs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig test --dep causal_artifact -Mroot=tools/causal_query.zig -Mcausal_artifact=tools/causal_artifact.zig") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"audit-chain-snapshot-compare\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-audit-chain-snapshot-compare\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal_snapshot.zig") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"load-test-observation-harness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-load-test-observation-harness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-load-test-observation-harness -- observe app-request-trace --iterations 1 --format json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-capture-design\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-capture-design\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-capture-design -- --format json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-capture-fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-capture-fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-capture-fixtures -- validate --format json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-readiness-review\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-readiness-review\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-readiness-review") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-implementation-proposal\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-implementation-proposal\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-implementation-proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-exporter-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-exporter-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-exporter-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-local-pipeline-fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-local-pipeline-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-nendb-retention-fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-nendb-retention-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-workbench-readonly-preview\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-workbench-readonly-preview\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-workbench-readonly-preview") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-artifact-preview\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-artifact-preview\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-artifact-preview") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-harness-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-harness-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-harness-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-archive-application\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-archive-application\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-archive-application") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-archive-evidence-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-archive-evidence-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-archive-evidence-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-readiness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-readiness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-dry-run-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-dry-run-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-dry-run-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-dry-run-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-advisory-ci-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-advisory-ci-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-advisory-ci-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-advisory-ci-report-publication-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-required-status-check-readiness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-required-status-check-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-required-status-check-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-required-status-check-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-required-status-check-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-required-status-check-enforcement-readiness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-required-status-check-enforcement-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-required-status-check-enforcement-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-required-status-check-enforcement-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-required-status-check-enforcement-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-telemetry-ci-gate-required-status-check-enforcement-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"production-hardening-backlog-refresh\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-production-hardening-backlog-refresh\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-production-hardening-backlog-refresh") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"nendb-durable-history-hardening\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-nendb-durable-history-hardening\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-nendb-durable-history-hardening") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-fixtures -- validate --format json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-readiness-review\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-readiness-review\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-readiness-review") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-implementation-proposal\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-implementation-proposal\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-implementation-proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-local-fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-local-fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-local-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-nendb-handoff-fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-nendb-handoff-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-audit-remediation-bridge\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-audit-remediation-bridge") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-solid-webui-readonly-preview\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-solid-webui-readonly-preview") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-publication-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator") != null);
}

test "production hardening backlog parses supported formats" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-production-hardening-backlog"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--json" }));
}
