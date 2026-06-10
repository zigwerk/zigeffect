const std = @import("std");

pub const production_hardening_backlog_schema = "zigeffect.causal.production-hardening-backlog.v1";
pub const production_hardening_backlog_schema_version: u32 = 1;
pub const recommendation = "start-production-telemetry-ci-gate-dry-run-evaluator";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator";

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
        "start-production-telemetry-ci-gate-dry-run-evaluator",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator",
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
    try std.testing.expect(std.mem.indexOf(u8, report, "recommended next branch: codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator") != null);
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
}

test "production hardening backlog JSON is agent-readable" {
    const allocator = std.testing.allocator;
    const report = try formatProductionHardeningBacklogJson(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-hardening-backlog.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"recommended_next_branch\": \"codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator\"") != null);
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
}

test "production hardening backlog parses supported formats" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-production-hardening-backlog"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--json" }));
}
