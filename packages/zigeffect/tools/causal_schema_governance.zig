const std = @import("std");
const causal_artifact = @import("causal_artifact");

pub const schema_governance_schema = "zigeffect.causal.schema-governance.v1";
pub const current_core_schema = causal_artifact.supported_causal_schema;
pub const current_core_schema_version: u32 = causal_artifact.supported_causal_schema_version;
pub const current_event_taxonomy_version: u32 = causal_artifact.supported_event_taxonomy_version;

const OutputFormat = enum { text, json };

const SchemaEntry = struct {
    schema: []const u8,
    version: u32,
    category: []const u8,
    status: []const u8,
    emitted_by: []const []const u8,
    consumed_by: []const []const u8,
    compatibility: []const []const u8,
    governance_requirements: []const []const u8,
};

const schema_entries: []const SchemaEntry = &.{
    .{
        .schema = "zigeffect.causal.v1",
        .version = 1,
        .category = "core-runtime",
        .status = "current",
        .emitted_by = &.{"formatCausalJson"},
        .consumed_by = &.{ "causal-query", "causal-compare", "causal-loop", "causal-advice", "causal-workbench" },
        .compatibility = &.{ "legacy-tolerant", "warn-forward" },
        .governance_requirements = &.{ "compatibility tests", "taxonomy warning tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.event.v1",
        .version = 1,
        .category = "backend-export",
        .status = "current",
        .emitted_by = &.{"CausalJsonlBackend"},
        .consumed_by = &.{ "jsonl readers", "agents", "external log processors" },
        .compatibility = &.{"sink-contract"},
        .governance_requirements = &.{ "backend conformance tests", "adapter docs", "redaction tests" },
    },
    .{
        .schema = "zigeffect.causal.otel_record.v1",
        .version = 1,
        .category = "backend-export",
        .status = "current",
        .emitted_by = &.{"CausalOtelBackend"},
        .consumed_by = &.{ "OpenTelemetry exporters", "agents" },
        .compatibility = &.{"sink-contract"},
        .governance_requirements = &.{ "backend conformance tests", "adapter docs", "redaction tests" },
    },
    .{
        .schema = "zigeffect.causal.nendb_node.v1",
        .version = 1,
        .category = "backend-export",
        .status = "current",
        .emitted_by = &.{"CausalNenDbStorageBackend"},
        .consumed_by = &.{ "NenDB adapter", "graph history queries", "agents" },
        .compatibility = &.{"sink-contract"},
        .governance_requirements = &.{ "NenDB adapter tests", "bounded history tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.nendb_edge.v1",
        .version = 1,
        .category = "backend-export",
        .status = "current",
        .emitted_by = &.{"CausalNenDbStorageBackend"},
        .consumed_by = &.{ "NenDB adapter", "graph history queries", "agents" },
        .compatibility = &.{"sink-contract"},
        .governance_requirements = &.{ "NenDB adapter tests", "causal edge tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.nendb-retention-report.v1",
        .version = 1,
        .category = "backend-export",
        .status = "current",
        .emitted_by = &.{"CausalNenDbStorageBackend.retentionReport"},
        .consumed_by = &.{ "causal-durable-production-retention", "NenDB adapter tests", "agents" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "NenDB retention tests", "durable retention docs", "schema governance entry" },
    },
    .{
        .schema = "zigeffect.causal.nendb-durable-history.v1",
        .version = 1,
        .category = "backend-export",
        .status = "current",
        .emitted_by = &.{ "CausalNendbStorageBackendState.durableHistoryReport", "causal-nendb-durable-history-hardening" },
        .consumed_by = &.{ "agents", "reviewers", "future cross-run query comparison", "future audit-chain snapshot comparison", "future app-facing production fixtures" },
        .compatibility = &.{ "strict-v1", "nendb-only", "local-fixture", "record-only", "no-cockroach", "no-live-telemetry", "no-network", "no-production-mutation" },
        .governance_requirements = &.{ "runtime report tests", "fixture tool tests", "redaction evidence checks", "query evidence checks", "next branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.app-runtime.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"CausalAppRuntime"},
        .consumed_by = &.{ "app remediation tools", "causal-workbench", "agents" },
        .compatibility = &.{ "warn-forward", "record-only" },
        .governance_requirements = &.{ "app runtime tests", "redaction tests", "workbench mapping", "docs" },
    },
    .{
        .schema = "zigeffect.causal.dev-loop-verdict.v1",
        .version = 1,
        .category = "dev-loop",
        .status = "current",
        .emitted_by = &.{ "causal-loop", "causal-verdict" },
        .consumed_by = &.{ "causal-dev-agent", "causal-diagnosis", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "verdict tests", "agent handoff docs", "artifact manifest entry" },
    },
    .{
        .schema = "zigeffect.causal.dev-session.v1",
        .version = 1,
        .category = "dev-loop",
        .status = "current",
        .emitted_by = &.{"causal-dev-session"},
        .consumed_by = &.{ "agents", "causal-workbench" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "session tests", "bounded memory tests", "artifact manifest entry" },
    },
    .{
        .schema = "zigeffect.causal.ci-verdict.v1",
        .version = 1,
        .category = "dev-loop",
        .status = "current",
        .emitted_by = &.{ "causal-verdict", "causal-handoff" },
        .consumed_by = &.{ "CI agents", "causal-dev-agent" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "CI verdict tests", "artifact manifest entry", "docs" },
    },
    .{
        .schema = "zigeffect.causal.workbench-session.v1",
        .version = 1,
        .category = "workbench",
        .status = "current",
        .emitted_by = &.{"causal-workbench"},
        .consumed_by = &.{ "SolidJS workbench", "zig-webui bridge" },
        .compatibility = &.{"viewer-session"},
        .governance_requirements = &.{ "launcher tests", "read-only bridge tests", "UI build verification" },
    },
    .{
        .schema = "zigeffect.causal.performance-budget.v1",
        .version = 1,
        .category = "operating-model",
        .status = "current",
        .emitted_by = &.{"causal-performance-budget"},
        .consumed_by = &.{ "agents", "reviewers", "CI docs" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "budget report tests", "operations docs", "release guidance" },
    },
    .{
        .schema = "zigeffect.causal.m9-completion-audit.v1",
        .version = 1,
        .category = "operating-model",
        .status = "current",
        .emitted_by = &.{"causal-m9-completion-audit"},
        .consumed_by = &.{ "agents", "reviewers", "roadmap audit" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "completion audit tests", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.production-hardening-backlog.v1",
        .version = 1,
        .category = "operating-model",
        .status = "current",
        .emitted_by = &.{"causal-production-hardening-backlog"},
        .consumed_by = &.{ "agents", "reviewers", "future hardening branch workers" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "backlog report tests", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.production-artifact-aggregation.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-artifact-aggregation"},
        .consumed_by = &.{ "durable retention", "access control", "workbench", "integrations", "agents" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "aggregation contract tests", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.durable-production-retention.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-durable-production-retention"},
        .consumed_by = &.{ "deployment runbooks", "artifact access control", "workbench", "agents" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "durable retention tests", "NenDB retention fixture", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.production-deployment-runbooks.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-deployment-runbooks"},
        .consumed_by = &.{ "artifact access control", "alerting integrations", "rollout guardrails", "agents" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "deployment runbook tests", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.artifact-access-control.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-artifact-access-control"},
        .consumed_by = &.{ "SolidJS workbench", "agent query interface", "live dashboard", "integrations", "future production hosts" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "access-control tests", "negative fixtures", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.encryption-at-rest-policy.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-encryption-at-rest-policy"},
        .consumed_by = &.{ "durable retention", "artifact access control", "future encrypted storage adapters", "agents" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "encryption policy tests", "redaction interaction fixtures", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.alerting-integrations.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-alerting-integrations"},
        .consumed_by = &.{ "deployment runbooks", "rollout guardrails", "human-agent feedback loop", "live dashboard planning", "agents" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "alerting integration tests", "negative fixtures", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.live-dashboard-stream.v1",
        .version = 1,
        .category = "workbench",
        .status = "current",
        .emitted_by = &.{ "causal-live-dashboard-streaming-workbench fixtures", "future dashboard transports" },
        .consumed_by = &.{ "SolidJS workbench", "Visual Graph tab", "agents", "future production dashboard hosts" },
        .compatibility = &.{ "record-only", "bounded-stream", "viewer-session" },
        .governance_requirements = &.{ "stream model tests", "bounded sample fixture", "Solid G6 adapter boundary docs", "workbench build verification" },
    },
    .{
        .schema = "zigeffect.causal.unified-spine-contract.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-unified-spine-contract"},
        .consumed_by = &.{ "deep runtime internals", "app semantic trace API", "agent query interface", "SolidJS workbench", "NenDB adapter projection" },
        .compatibility = &.{ "record-only", "spine-contract" },
        .governance_requirements = &.{ "contract tests", "projection boundary docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.agent-query.v1",
        .version = 1,
        .category = "agent-query",
        .status = "current",
        .emitted_by = &.{"causal-query --agent"},
        .consumed_by = &.{ "agents", "causal-dev-agent", "future workbench graph slices", "cross-run comparison" },
        .compatibility = &.{ "strict-v1", "record-only", "bounded cross-run comparison" },
        .governance_requirements = &.{ "agent query tests", "bounded response tests", "cross-run comparison tests", "policy metadata docs" },
    },
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
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-readiness-review.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-readiness-review"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future app-facing production integration implementation proposal" },
        .compatibility = &.{ "strict-v1", "record-only", "readiness-review", "nendb-only", "no-cockroach", "no-live-telemetry", "no-production-mutation" },
        .governance_requirements = &.{ "readiness review tests", "fixture evidence checks", "verification command evidence", "next-branch handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-implementation-proposal.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-implementation-proposal"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future app-facing production integration boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "implementation-proposal", "nendb-only", "no-cockroach", "no-live-telemetry", "no-production-mutation" },
        .governance_requirements = &.{ "implementation proposal tests", "readiness artifact checks", "verification command evidence", "next-branch handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future app-facing production integration local fixtures", "future SolidJS workbench production app views" },
        .compatibility = &.{ "strict-v1", "record-only", "guarded-boundary", "nendb-only", "no-cockroach", "no-live-telemetry", "no-production-mutation" },
        .governance_requirements = &.{ "boundary tests", "proposal artifact checks", "verification command evidence", "next-branch handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-local-fixtures.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-local-fixtures"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future app-facing NenDB handoff fixtures", "future SolidJS workbench production app views" },
        .compatibility = &.{ "strict-v1", "record-only", "local-fixtures", "fixture-only", "nendb-only", "no-cockroach", "no-live-telemetry", "no-production-mutation" },
        .governance_requirements = &.{ "local fixture tests", "boundary artifact checks", "fixture validation checks", "verification command evidence", "next-branch handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-nendb-handoff-fixtures"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future app-facing audit remediation bridge", "future SolidJS workbench production app views" },
        .compatibility = &.{ "strict-v1", "record-only", "nendb-handoff-fixtures", "fixture-only", "nendb-only", "no-cockroach", "no-live-telemetry", "no-production-mutation", "no-nendb-write" },
        .governance_requirements = &.{ "handoff fixture tests", "local fixture artifact checks", "NenDB node and edge handoff checks", "verification command evidence", "next-branch handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-audit-remediation-bridge"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future app-facing SolidJS read-only preview", "future guarded app remediation planning" },
        .compatibility = &.{ "strict-v1", "record-only", "audit-remediation-bridge", "evidence-only", "nendb-handoff-fixture-source", "no-cockroach", "no-live-telemetry", "no-production-mutation", "no-nendb-write", "no-auto-apply" },
        .governance_requirements = &.{ "bridge tests", "NenDB handoff artifact checks", "audit/remediation bridge catalog checks", "verification command evidence", "next-branch handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-solid-webui-readonly-preview"},
        .consumed_by = &.{ "agents", "reviewers", "local SolidJS workbench", "production-hardening backlog", "future CI advisory remediation report" },
        .compatibility = &.{ "strict-v1", "read-only", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-live-dashboard", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-ci-enforcement", "no-react-renderer" },
        .governance_requirements = &.{ "preview producer tests", "source bridge artifact checks", "SolidJS workbench parser tests", "WebUI sample tests", "verification command evidence", "next-branch handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report"},
        .consumed_by = &.{ "agents", "reviewers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report application boundary" },
        .compatibility = &.{ "strict-v1", "advisory-only", "read-only", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution" },
        .governance_requirements = &.{ "report producer tests", "source preview artifact checks", "CI advisory bridge checks", "SolidJS workbench parser tests", "WebUI sample tests", "verification command evidence", "next-branch handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future app-facing advisory report publication policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "application-boundary", "reviewed-before-after-evidence", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution" },
        .governance_requirements = &.{ "application boundary producer tests", "source advisory report artifact checks", "before/after evidence checks", "after-report safety checks", "verification command evidence", "next-branch handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy"},
        .consumed_by = &.{ "agents", "reviewers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption readiness" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "publication-policy", "interpretation-policy", "non-blocking-advisory", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution" },
        .governance_requirements = &.{ "publication policy producer tests", "applied application-boundary source checks", "interpretation-rule tests", "denied inference tests", "verification command evidence", "next-branch consumption-readiness handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness"},
        .consumed_by = &.{ "agents", "reviewers", "local SolidJS workbench", "production-hardening backlog", "future guarded app-facing advisory report consumption boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-readiness", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution" },
        .governance_requirements = &.{ "consumption readiness producer tests", "source publication-policy checks", "consumer profile tests", "readiness dimension tests", "guardrail and denied inference tests", "verification command evidence", "next-branch consumption-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-boundary", "plan-or-record-applied", "read-only-consumption", "bounded-agent-context", "reviewed-before-after-evidence", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution" },
        .governance_requirements = &.{ "consumption boundary producer tests", "ready consumption-readiness source checks", "plan mode tests", "record-applied before/after evidence tests", "consumer-after safety tests", "verification command evidence", "next-branch consumption-policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-policy", "interpretation-policy", "applied-consumption-boundary-source", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption policy producer tests", "applied consumption-boundary source checks", "interpretation-rule tests", "consumption-scope tests", "denied inference tests", "negative fixture tests", "verification command evidence", "next-branch consumption-evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-evaluator", "bounded-explicit-evidence", "read-only-consumption", "request-classifier", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption evaluator producer tests", "ready consumption-policy source checks", "request and evidence classifier tests", "ready advisory and blocked artifact tests", "denied content tests", "redaction posture tests", "verification command evidence", "next-branch consumption-report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-report", "local-report-only", "bounded-explicit-evidence", "read-only-consumption", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report producer tests", "ready advisory and blocked evaluator source checks", "authority drift tests", "local publication channel tests", "parseable JSON tests", "verification command evidence", "next-branch consumption-report application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-report-application-boundary", "plan-or-record-applied", "reviewed-before-after-evidence", "safe-after-report", "read-only-consumption", "bounded-explicit-evidence", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report application-boundary producer tests", "ready advisory and blocked report source checks", "plan mode tests", "record-applied before/after evidence tests", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "next-branch consumption-report policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-report-policy", "applied-consumption-report-application-boundary-source", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report policy producer tests", "applied consumption-report application-boundary source checks", "interpretation-rule tests", "consumption-scope tests", "denied inference tests", "negative fixture tests", "verification command evidence", "next-branch consumption-report evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-report-evaluator", "approved-consumption-report-policy-source", "bounded-explicit-evidence", "request-classifier", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluator producer tests", "ready consumption-report policy source checks", "source application evidence checks", "request and evidence classifier tests", "ready advisory and blocked artifact tests", "denied content tests", "redaction posture tests", "verification command evidence", "next-branch consumption-report evaluation-report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-report-evaluation-report", "source-consumption-report-evaluator", "local-report-only", "bounded-explicit-evidence", "read-only-consumption", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report producer tests", "ready consumption-report evaluator source checks", "source report application evidence checks", "local publication-only tests", "ready advisory and blocked report tests", "authority drift tests", "verification command evidence", "next-branch evaluation-report application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-report-evaluation-report-application-boundary", "plan-or-record-applied", "reviewed-before-after-evidence", "safe-after-report", "read-only-consumption", "bounded-explicit-evidence", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report application-boundary producer tests", "ready advisory and blocked source report checks", "plan mode tests", "record-applied before/after evidence tests", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "next-branch evaluation-report policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-report-evaluation-report-policy", "applied-consumption-report-evaluation-report-application-boundary-source", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report policy producer tests", "applied evaluation-report application-boundary source checks", "interpretation-rule tests", "consumption-scope tests", "denied inference tests", "negative fixture tests", "verification command evidence", "next-branch evaluation-report evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-report-evaluation-report-evaluator", "approved-consumption-report-evaluation-report-policy-source", "bounded-explicit-evidence", "request-classifier", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluator producer tests", "ready consumption-report evaluation-report policy source checks", "source evaluation-report application evidence checks", "request and evidence classifier tests", "ready advisory and blocked artifact tests", "denied content tests", "redaction posture tests", "verification command evidence", "next-branch evaluation-report evaluation-report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-report-evaluation-report-evaluation-report", "source-consumption-report-evaluation-report-evaluator", "local-report-only", "bounded-explicit-evidence", "read-only-consumption", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report producer tests", "ready consumption-report evaluation-report evaluator source checks", "source evaluation-report application evidence checks", "inherited report application evidence checks", "local publication-only tests", "ready advisory and blocked report tests", "authority drift tests", "verification command evidence", "next-branch evaluation-report evaluation-report application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-report-evaluation-report-evaluation-report-application-boundary", "plan-or-record-applied", "reviewed-before-after-evidence", "safe-after-report", "read-only-consumption", "bounded-explicit-evidence", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report application-boundary producer tests", "ready advisory and blocked source report checks", "plan mode tests", "record-applied before/after evidence tests", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "next-branch evaluation-report evaluation-report policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-report-evaluation-report-evaluation-report-policy", "applied-consumption-report-evaluation-report-evaluation-report-application-boundary-source", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report policy producer tests", "applied evaluation-report evaluation-report application-boundary source checks", "interpretation-rule tests", "consumption-scope tests", "denied inference tests", "negative fixture tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-report-evaluation-report-evaluation-report-evaluator", "approved-consumption-report-evaluation-report-evaluation-report-policy-source", "bounded-explicit-evidence", "request-classifier", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluator producer tests", "ready consumption-report evaluation-report evaluation-report policy source checks", "source evaluation-report evaluation-report application evidence checks", "inherited evaluation-report and report application evidence checks", "request and evidence classifier tests", "ready advisory and blocked artifact tests", "denied content tests", "redaction posture tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "consumption-report-evaluation-report-evaluation-report-evaluation-report", "source-consumption-report-evaluation-report-evaluation-report-evaluator", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report producer tests", "ready or advisory source evaluator checks", "source evaluation-report evaluation-report policy evidence checks", "source evaluation-report evaluation-report application evidence checks", "request and evidence summary carryover", "ready advisory and blocked artifact tests", "denied authority tests", "local publication posture tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report policy" },
        .compatibility = &.{ "strict-v1", "record-only", "application-boundary", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report", "guarded-record-applied", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report application-boundary producer tests", "ready advisory and blocked source report checks", "plan mode tests", "record-applied before/after evidence tests", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "policy-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "approve-reject-decision", "local-publication-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report policy producer tests", "ready or applied source application-boundary checks", "approve reject decision tests", "interpretation rule tests", "consumption scope tests", "negative fixture tests", "denied inference rule tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluator tests", "ready advisory and blocked source policy checks", "explicit request evidence checks", "support evidence advisory checks", "redaction posture checks", "authority drift tests", "local publication posture tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report producer tests", "ready or advisory source evaluator checks", "source evaluation-report evaluation-report evaluation-report policy evidence checks", "source evaluation-report evaluation-report evaluation-report application evidence checks", "inherited evaluation-report evaluation-report evidence checks", "request and evidence summary carryover", "ready advisory and blocked artifact tests", "denied authority tests", "local publication posture tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report policy" },
        .compatibility = &.{ "strict-v1", "record-only", "application-boundary", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "guarded-record-applied", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report application-boundary producer tests", "ready advisory and blocked source report checks", "plan mode tests", "record-applied before/after evidence tests", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "policy-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "approve-reject-decision", "local-publication-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report policy producer tests", "ready applied source application-boundary checks", "approve reject decision tests", "interpretation rule tests", "consumption scope tests", "negative fixture tests", "denied inference rule tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluator tests", "ready advisory and blocked source policy checks", "explicit request evidence checks", "support evidence advisory checks", "redaction posture checks", "authority drift tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report producer tests", "ready or advisory source evaluator checks", "source evaluation-report evaluation-report evaluation-report evaluation-report policy evidence checks", "source evaluation-report evaluation-report evaluation-report evaluation-report application evidence checks", "inherited evaluation-report evaluation-report evaluation-report evidence checks", "request and evidence summary carryover", "ready advisory and blocked artifact tests", "denied authority tests", "local publication posture tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "application-boundary", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "plan-or-record-applied", "reviewed-before-after-evidence", "safe-after-report", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application-boundary producer tests", "ready advisory and blocked source report checks", "plan mode tests", "record-applied before/after evidence tests", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "policy-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "approve-reject-decision", "local-publication-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report policy producer tests", "ready applied source application-boundary checks", "approve reject decision tests", "interpretation rule tests", "consumption scope tests", "negative fixture tests", "denied inference rule tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator tests", "ready advisory and blocked source policy checks", "explicit request evidence checks", "support evidence advisory checks", "redaction posture checks", "authority drift tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report producer tests", "ready or advisory source evaluator checks", "source evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report policy evidence checks", "source evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application evidence checks", "inherited evaluation-report evaluation-report evaluation-report evaluation-report evidence checks", "request and evidence summary carryover", "ready advisory and blocked artifact tests", "denied authority tests", "local publication posture tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "application-boundary", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "plan-or-record-applied", "reviewed-before-after-evidence", "safe-after-report", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application-boundary producer tests", "ready advisory and blocked source report checks", "plan mode tests", "record-applied before/after evidence tests", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "policy-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "approve-reject-decision", "local-publication-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report policy producer tests", "ready applied source application-boundary checks", "approve reject decision tests", "interpretation rule tests", "consumption scope tests", "negative fixture tests", "denied inference rule tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator tests", "ready advisory and blocked source policy checks", "explicit request evidence checks", "support evidence advisory checks", "redaction posture checks", "authority drift tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report producer tests", "ready or advisory source evaluator checks", "source evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report policy evidence checks", "source evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application evidence checks", "inherited evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evidence checks", "request and evidence summary carryover", "ready advisory and blocked artifact tests", "denied authority tests", "local publication posture tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "application-boundary", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "plan-or-record-applied", "reviewed-before-after-evidence", "safe-after-report", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application-boundary producer tests", "ready advisory and blocked source report checks", "plan mode tests", "record-applied before/after evidence tests", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "policy-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", "approve-reject-decision", "local-publication-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report policy producer tests", "ready applied source application-boundary checks", "approve reject decision tests", "interpretation rule tests", "consumption scope tests", "negative fixture tests", "denied inference rule tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluator tests", "ready advisory and blocked source policy checks", "explicit request evidence checks", "support evidence advisory checks", "redaction posture checks", "authority drift tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing advisory report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "consumption report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report producer tests", "ready or advisory source evaluator checks", "source evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report policy evidence checks", "source evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application evidence checks", "inherited evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evidence checks", "request and evidence summary carryover", "ready advisory and blocked artifact tests", "denied authority tests", "local publication posture tests", "verification command evidence", "next-branch evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report evaluation-report application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-eight-level-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing eight-level policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "application-boundary", "source-eight-level-report", "guarded-record-applied", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "eight-level application-boundary producer tests", "ready advisory and blocked source report checks", "plan mode tests", "record-applied before/after evidence tests", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "short alias branch and build step", "next-branch eight-level policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-eight-level-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing eight-level evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "policy-only", "source-eight-level-application-boundary", "approve-reject-decision", "local-publication-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "eight-level policy producer tests", "applied source application-boundary checks", "approve reject decision tests", "interpretation rule tests", "consumption scope tests", "negative fixture tests", "denied inference rule tests", "verification command evidence", "short alias branch and build step", "next-branch eight-level evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-eight-level-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing nine-level report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-eight-level-policy", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "eight-level evaluator producer tests", "ready advisory and blocked source policy checks", "explicit request evidence checks", "support evidence advisory checks", "redaction posture checks", "authority drift tests", "verification command evidence", "short alias branch and build step", "next-branch nine-level report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-nine-level-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing nine-level application-boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-eight-level-evaluator", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "nine-level report producer tests", "ready advisory and blocked source evaluator checks", "source eight-level policy evidence carryover", "source eight-level application evidence carryover", "inherited report evidence checks", "request and evidence summary carryover", "denied authority tests", "local publication posture tests", "verification command evidence", "short alias branch and build step", "next-branch nine-level application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-nine-level-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing nine-level policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "application-boundary", "source-nine-level-report", "guarded-record-applied", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "nine-level application-boundary producer tests", "ready advisory and blocked source report checks", "plan mode tests", "record-applied before/after evidence tests", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "short alias branch and build step", "next-branch nine-level policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-nine-level-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing nine-level evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "policy-only", "source-nine-level-application-boundary", "approve-reject-decision", "local-publication-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "nine-level policy producer tests", "applied source nine-level application-boundary checks", "approved source nine-level report evidence checks", "inherited eight-level policy evidence checks", "approve reject decision tests", "interpretation rule tests", "consumption scope tests", "negative fixture tests", "denied inference rule tests", "verification command evidence", "short alias branch and build step", "next-branch nine-level evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-nine-level-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing ten-level report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-nine-level-policy", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "nine-level evaluator producer tests", "ready advisory and blocked source policy checks", "explicit request evidence checks", "support evidence advisory checks", "redaction posture checks", "authority drift tests", "verification command evidence", "short alias branch and build step", "next-branch ten-level report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-ten-level-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing ten-level application-boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-nine-level-evaluator", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "ten-level report producer tests", "ready advisory and blocked source evaluator checks", "source nine-level policy evidence carryover", "source nine-level application evidence carryover", "inherited eight-level evidence carryover", "request and evidence summary carryover", "denied authority tests", "local publication posture tests", "verification command evidence", "short alias branch and build step", "next-branch ten-level application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-ten-level-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing ten-level policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "application-boundary", "source-ten-level-report", "guarded-record-applied", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "ten-level application-boundary producer tests", "ready advisory and blocked source report checks", "plan mode tests", "record-applied before/after evidence tests", "source nine-level lineage carryover", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "short alias branch and build step", "next-branch ten-level policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-ten-level-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing ten-level evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "policy-only", "source-ten-level-application-boundary", "approve-reject-decision", "local-publication-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "ten-level policy producer tests", "applied source ten-level application-boundary checks", "source ten-level report evidence checks", "source nine-level policy application and report lineage checks", "approve reject decision tests", "interpretation rule tests", "consumption scope tests", "negative fixture tests", "denied inference rule tests", "verification command evidence", "short alias branch and build step", "next-branch ten-level evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-ten-level-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing eleven-level report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-ten-level-policy", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "ten-level evaluator producer tests", "source ten-level policy artifact checks", "ready advisory and blocked source policy checks", "bounded request evidence checks", "support evidence advisory checks", "redaction posture checks", "source ten-level report evidence carryover", "source nine-level lineage carryover", "verification command evidence", "short alias branch and build step", "next-branch eleven-level report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-eleven-level-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing eleven-level application-boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-ten-level-evaluator", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "eleven-level report producer tests", "ready advisory and blocked source evaluator checks", "source ten-level policy evidence carryover", "source ten-level application evidence carryover", "source nine-level lineage carryover", "request and evidence summary carryover", "denied authority tests", "local publication posture tests", "verification command evidence", "short alias branch and build step", "next-branch eleven-level application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-eleven-level-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing eleven-level policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "application-boundary", "source-eleven-level-report", "guarded-record-applied", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "eleven-level application-boundary producer tests", "ready advisory and blocked source report checks", "plan mode tests", "record-applied before/after evidence tests", "source ten-level lineage carryover", "source nine-level lineage carryover", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "short alias branch and build step", "next-branch eleven-level policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-eleven-level-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing eleven-level evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "policy-only", "source-eleven-level-application-boundary", "approve-reject-decision", "local-publication-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "eleven-level policy producer tests", "applied source eleven-level application-boundary checks", "source eleven-level report evidence checks", "source ten-level policy application and report lineage checks", "source nine-level policy application and report lineage checks", "approve reject decision tests", "interpretation rule tests", "consumption scope tests", "negative fixture tests", "denied inference rule tests", "verification command evidence", "short alias branch and build step", "next-branch eleven-level evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-eleven-level-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing twelve-level report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-eleven-level-policy", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "eleven-level evaluator producer tests", "source eleven-level policy artifact checks", "ready advisory and blocked source policy checks", "bounded request evidence checks", "support evidence advisory checks", "redaction posture checks", "source eleven-level report evidence carryover", "source ten-level lineage carryover", "source nine-level lineage carryover", "verification command evidence", "short alias branch and build step", "next-branch twelve-level report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-twelve-level-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing twelve-level application-boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-eleven-level-evaluator", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "twelve-level report producer tests", "ready advisory and blocked source evaluator checks", "source eleven-level policy evidence carryover", "source eleven-level application evidence carryover", "source ten-level lineage carryover", "source nine-level lineage carryover", "request and evidence summary carryover", "denied authority tests", "local publication posture tests", "verification command evidence", "short alias branch and build step", "next-branch twelve-level application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-twelve-level-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing twelve-level policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "application-boundary", "source-twelve-level-report", "guarded-record-applied", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "twelve-level application-boundary producer tests", "ready advisory and blocked source report checks", "plan mode tests", "record-applied before/after evidence tests", "source twelve-level report evidence carryover", "source eleven-level lineage carryover", "source ten-level lineage carryover", "source nine-level lineage carryover", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "short alias branch and build step", "next-branch twelve-level policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-twelve-level-policy"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing twelve-level evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "policy-only", "source-twelve-level-application-boundary", "approve-reject-decision", "local-publication-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "twelve-level policy producer tests", "applied source twelve-level application-boundary checks", "source twelve-level report evidence checks", "source eleven-level policy application and report lineage checks", "source ten-level policy application and report lineage checks", "source nine-level policy application and report lineage checks", "approve reject decision tests", "interpretation rule tests", "consumption scope tests", "negative fixture tests", "denied inference rule tests", "verification command evidence", "short alias branch and build step", "next-branch twelve-level evaluator handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-twelve-level-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing thirteen-level report" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-twelve-level-policy", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "twelve-level evaluator producer tests", "source twelve-level policy artifact checks", "ready advisory and blocked source policy checks", "bounded request evidence checks", "support evidence advisory checks", "redaction posture checks", "source twelve-level report evidence carryover", "source eleven-level lineage carryover", "source ten-level lineage carryover", "source nine-level lineage carryover", "verification command evidence", "short alias branch and build step", "next-branch thirteen-level report handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-thirteen-level-report"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing thirteen-level application-boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-twelve-level-evaluator", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "thirteen-level report producer tests", "ready advisory and blocked source twelve-level evaluator checks", "source twelve-level policy evidence carryover", "source twelve-level application evidence carryover", "source eleven-level lineage carryover", "source ten-level lineage carryover", "source nine-level lineage carryover", "request and evidence summary carryover", "denied authority tests", "local publication posture tests", "verification command evidence", "short alias branch and build step", "next-branch thirteen-level application-boundary handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        .version = 1,
        .category = "app-runtime",
        .status = "current",
        .emitted_by = &.{"causal-app-facing-thirteen-level-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing thirteen-level policy" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-only", "application-boundary", "source-thirteen-level-report", "guarded-record-applied", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
        .governance_requirements = &.{ "thirteen-level application-boundary producer tests", "ready advisory and blocked source report checks", "plan mode tests", "record-applied before/after evidence tests", "source thirteen-level report evidence carryover", "source twelve-level lineage carryover", "source eleven-level lineage carryover", "source ten-level lineage carryover", "source nine-level lineage carryover", "after-report safety tests", "authority drift tests", "local publication channel tests", "verification command evidence", "short alias branch and build step", "next-branch thirteen-level policy handoff", "docs update" },
    },
    .{
        .schema = "zigeffect.causal.human-agent-feedback-loop.v1",
        .version = 1,
        .category = "human-agent-feedback",
        .status = "current",
        .emitted_by = &.{"causal-human-agent-feedback-loop"},
        .consumed_by = &.{ "agents", "SolidJS workbench", "causal-dev-loop", "future NenDB adapter handoff" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none" },
        .governance_requirements = &.{ "feedback-loop tests", "guardrail tests", "workflow docs", "backlog handoff" },
    },
    .{
        .schema = "zigeffect.causal.rollout-automation-guardrails.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-rollout-automation-guardrails"},
        .consumed_by = &.{ "agents", "reviewers", "deployment runbooks", "alerting integrations", "future rollout hosts" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none" },
        .governance_requirements = &.{ "rollout guardrail tests", "negative automation fixtures", "operations docs", "roadmap update" },
    },
    .{
        .schema = "zigeffect.causal.wall-clock-benchmark-baselines.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-wall-clock-benchmark-baselines"},
        .consumed_by = &.{ "agents", "reviewers", "future benchmark observation harness", "future production capacity planning" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "advisory-wall-clock" },
        .governance_requirements = &.{ "benchmark baseline tests", "wall-clock caveat docs", "environment metadata policy", "capacity planning handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-capacity-planning.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-capacity-planning"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening completion audit", "future load-test harnesses", "future production planning" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "planning-only" },
        .governance_requirements = &.{ "capacity planning tests", "storage assumption docs", "load-test fixture docs", "completion audit handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-hardening-completion-audit.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-hardening-completion-audit"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "load-test observation harness" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "completion-audit" },
        .governance_requirements = &.{ "completion audit tests", "boundary docs", "remaining gap docs", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.load-test-observation-harness.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-load-test-observation-harness"},
        .consumed_by = &.{ "agents", "reviewers", "production telemetry capture design", "future capacity sizing review" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "local-observation" },
        .governance_requirements = &.{ "observation harness tests", "bounded runner tests", "redaction docs", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-capture-design.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-capture-design"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry capture fixtures" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "design-only", "no-live-ingestion" },
        .governance_requirements = &.{ "telemetry capture design tests", "redaction gate docs", "negative telemetry fixtures", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-capture-fixtures.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-capture-fixtures"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "production telemetry readiness review" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "fixtures-only", "no-live-ingestion" },
        .governance_requirements = &.{ "fixture catalog tests", "validation report tests", "negative telemetry fixtures", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-readiness-review.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-readiness-review"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry implementation proposal" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "readiness-review", "no-live-ingestion" },
        .governance_requirements = &.{ "readiness review tests", "fixture evidence checks", "verification command evidence", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-implementation-proposal.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-implementation-proposal"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry exporter boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "implementation-proposal", "no-live-ingestion" },
        .governance_requirements = &.{ "proposal tests", "readiness evidence checks", "verification command evidence", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-exporter-boundary.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-exporter-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry local pipeline fixtures" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "exporter-boundary", "no-live-ingestion", "no-network" },
        .governance_requirements = &.{ "boundary tests", "proposal evidence checks", "no-network checks", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-local-pipeline-fixtures"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry NenDB retention fixtures" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "local-pipeline-fixtures", "fixtures-only", "no-live-ingestion", "no-network" },
        .governance_requirements = &.{ "fixture catalog tests", "boundary evidence checks", "redaction and sampling fixture checks", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-nendb-retention-fixtures"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry workbench read-only preview" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "nendb-retention-fixtures", "fixtures-only", "no-live-ingestion", "no-network", "no-durable-write" },
        .governance_requirements = &.{ "NenDB mapping fixture tests", "local pipeline evidence checks", "retention policy checks", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-workbench-readonly-preview.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-workbench-readonly-preview"},
        .consumed_by = &.{ "agents", "reviewers", "SolidJS webui workbench", "production-hardening backlog", "future production telemetry CI artifact preview" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "workbench-readonly-preview", "solid-webui", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write" },
        .governance_requirements = &.{ "workbench tests", "source retention evidence checks", "read-only authority checks", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-artifact-preview.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-artifact-preview"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI harness boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "ci-artifact-preview", "preview-only", "failure-attachment-catalog", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate" },
        .governance_requirements = &.{ "source workbench preview evidence checks", "artifact candidate allowlist checks", "preview-only CI authority checks", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-harness-boundary.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-harness-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI archive application" },
        .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "ci-harness-boundary", "workflow-inspection", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate", "no-workflow-mutation" },
        .governance_requirements = &.{ "source CI preview evidence checks", "workflow required-feature checks", "workflow prohibited-feature checks", "cluster release-gate assumptions", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-archive-application.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-archive-application"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI archive evidence policy" },
        .compatibility = &.{ "strict-v1", "record-only", "guarded-application", "plan-or-record-applied", "workflow-evidence", "before-after-verification", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate", "no-tool-workflow-mutation" },
        .governance_requirements = &.{ "source CI harness boundary evidence checks", "workflow change evidence checks", "before/after evidence checks", "post-application verification checks", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-archive-evidence-policy"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate readiness" },
        .compatibility = &.{ "strict-v1", "record-only", "archive-evidence-policy", "interpretation-policy", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate", "no-tool-workflow-mutation" },
        .governance_requirements = &.{ "source CI archive application evidence checks", "evidence class catalog tests", "interpretation rule tests", "negative evidence fixtures", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-readiness.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-readiness"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "ci-gate-readiness", "gate-semantics", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate-enforcement", "no-workflow-mutation" },
        .governance_requirements = &.{ "source archive evidence policy checks", "candidate gate signal tests", "release-gate verification checks", "negative gate fixtures", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate dry-run policy" },
        .compatibility = &.{ "strict-v1", "record-only", "gate-application-boundary", "plan-or-record-applied", "before-after-verification", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate-enforcement", "no-tool-workflow-mutation" },
        .governance_requirements = &.{ "source CI gate readiness evidence checks", "workflow change evidence checks", "before/after evidence checks", "after-workflow safety checks", "next-branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-dry-run-policy"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate dry-run evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "dry-run-policy", "advisory-only", "bounded-ci-artifacts", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate-enforcement", "no-required-status-check", "no-tool-workflow-mutation" },
        .governance_requirements = &.{ "source gate application boundary checks", "candidate signal policy tests", "evidence requirement tests", "negative dry-run fixtures", "next-branch evaluator handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-dry-run-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate advisory CI report" },
        .compatibility = &.{ "strict-v1", "record-only", "dry-run-evaluator", "advisory-findings", "bounded-explicit-evidence", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate-enforcement", "no-required-status-check", "no-tool-workflow-mutation" },
        .governance_requirements = &.{ "source dry-run policy checks", "explicit evidence boundary tests", "advisory signal tests", "denied evidence fixtures", "next-branch advisory CI report handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-advisory-ci-report"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate advisory CI report application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "advisory-ci-report", "reviewer-guidance", "local-artifact-only", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate-enforcement", "no-required-status-check", "no-tool-workflow-mutation", "no-github-step-summary-write", "no-pr-comment" },
        .governance_requirements = &.{ "source evaluator checks", "record-only publication channel tests", "advisory rendering tests", "negative blocked evaluator fixtures", "next-branch report application boundary handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate advisory CI report publication policy" },
        .compatibility = &.{ "strict-v1", "record-only", "report-application-boundary", "plan-or-record-applied", "before-after-verification", "local-artifact-only", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate-enforcement", "no-required-status-check", "no-tool-workflow-mutation", "no-tool-ci-upload", "no-tool-github-step-summary-write", "no-tool-pr-comment" },
        .governance_requirements = &.{ "source advisory CI report checks", "publication evidence tests", "before/after evidence tests", "report safety tests", "negative application fixtures", "next-branch publication policy handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check readiness" },
        .compatibility = &.{ "strict-v1", "record-only", "publication-policy", "interpretation-policy", "non-blocking-advisory", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate-enforcement", "no-required-status-check", "no-tool-workflow-mutation", "no-tool-ci-upload", "no-tool-github-step-summary-write", "no-tool-pr-comment" },
        .governance_requirements = &.{ "source application boundary checks", "interpretation rule tests", "denied inference tests", "negative publication policy fixtures", "next-branch required status check readiness handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-readiness"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "required-status-check-readiness", "gate-semantics", "activation-guardrails", "non-blocking-advisory-source", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-ci-gate-enforcement", "no-required-status-check", "no-branch-protection-mutation", "no-github-api-mutation", "no-tool-workflow-mutation", "no-tool-ci-upload", "no-tool-github-step-summary-write", "no-tool-pr-comment" },
        .governance_requirements = &.{ "source publication policy checks", "candidate required-check profile tests", "activation guardrail tests", "denied inference tests", "next-branch required status check application boundary handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check policy" },
        .compatibility = &.{ "strict-v1", "record-only", "required-status-check-application-boundary", "plan-or-record-applied", "before-after-verification", "branch-protection-evidence", "check-run-evidence", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-ci-upload", "no-tool-github-step-summary-write", "no-tool-pr-comment" },
        .governance_requirements = &.{ "source readiness checks", "branch-protection evidence checks", "workflow or check-run evidence checks", "after-state safety checks", "next-branch required status check policy handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-policy"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check enforcement readiness" },
        .compatibility = &.{ "strict-v1", "record-only", "required-status-check-policy", "interpretation-policy", "planned-or-applied-source", "branch-protection-evidence", "cluster-release-gate-aware", "no-live-ingestion", "no-network", "no-durable-write", "no-nendb-write", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-ci-upload", "no-tool-github-step-summary-write", "no-tool-pr-comment" },
        .governance_requirements = &.{ "source application-boundary checks", "planned source interpretation tests", "applied source interpretation tests", "denied inference tests", "required-check surface policy tests", "next-branch enforcement-readiness handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check enforcement application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "required-status-check-enforcement-readiness", "applied-source-required-for-ready", "active-enforcement-claim-denied", "merge-blocker-claim-denied", "branch-protection-evidence", "workflow-or-check-run-evidence", "owner-approval", "rollback-evidence", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-ci-upload", "no-live-ingestion", "no-durable-write", "no-nendb-write" },
        .governance_requirements = &.{ "source policy checks", "applied source checks", "required check name evidence", "branch-protection evidence", "workflow or check-run evidence", "failure-mode evidence", "owner approval evidence", "rollback evidence", "active enforcement denied inference tests", "next-branch enforcement application-boundary handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check enforcement policy" },
        .compatibility = &.{ "strict-v1", "record-only", "required-status-check-enforcement-application-boundary", "plan-or-record-applied", "applied-external-enforcement-evidence", "active-enforcement-record", "merge-blocker-record", "branch-protection-before-after", "workflow-or-check-run-evidence", "owner-approval", "rollback-evidence", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-ci-upload", "no-live-ingestion", "no-durable-write", "no-nendb-write" },
        .governance_requirements = &.{ "source enforcement-readiness checks", "plan mode tests", "record-applied external evidence tests", "branch-protection before-after evidence", "workflow or check-run evidence", "active enforcement record tests", "merge blocker record tests", "denied mutation-by-tool inference tests", "next-branch enforcement policy handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-enforcement-policy"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check enforcement evaluator" },
        .compatibility = &.{ "strict-v1", "record-only", "required-status-check-enforcement-policy", "interpretation-policy", "active-enforcement-interpretation", "merge-blocker-interpretation", "planned-or-applied-source", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-check-run-creation", "no-tool-ci-upload", "no-live-ingestion", "no-durable-write", "no-nendb-write" },
        .governance_requirements = &.{ "source enforcement application-boundary checks", "planned source interpretation tests", "applied active-enforcement interpretation tests", "merge-blocker evidence interpretation tests", "denied mutation-by-tool inference tests", "policy verification checks", "next-branch enforcement evaluator handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check enforcement report" },
        .compatibility = &.{ "strict-v1", "record-only", "required-status-check-enforcement-evaluator", "bounded-explicit-evidence", "active-enforcement-evaluation", "merge-blocker-evaluation", "advisory-findings", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-check-run-creation", "no-tool-ci-upload", "no-live-ingestion", "no-durable-write", "no-nendb-write" },
        .governance_requirements = &.{ "source enforcement policy checks", "explicit bounded evidence classifier", "active enforcement signal evaluation", "merge blocker signal evaluation", "denied mutation evidence tests", "denied production evidence tests", "next-branch enforcement report handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-enforcement-report"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check enforcement report application boundary" },
        .compatibility = &.{ "strict-v1", "record-only", "required-status-check-enforcement-report", "reviewer-guidance", "local-artifact-only", "blocked-finding-preserving", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-check-run-creation", "no-tool-ci-upload", "no-github-step-summary-write", "no-pr-comment", "no-live-ingestion", "no-durable-write", "no-nendb-write" },
        .governance_requirements = &.{ "source enforcement evaluator checks", "blocked finding preservation tests", "publication boundary tests", "denied authority tests", "next-branch report application-boundary handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production telemetry CI gate required status check enforcement report policy" },
        .compatibility = &.{ "strict-v1", "record-only", "report-application-boundary", "plan-or-record-applied", "before-after-verification", "local-artifact-only", "required-status-check-evidence", "branch-protection-evidence", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-check-run-creation", "no-tool-ci-upload", "no-tool-github-step-summary-write", "no-tool-pr-comment", "no-live-ingestion", "no-durable-write", "no-nendb-write" },
        .governance_requirements = &.{ "source report checks", "plan mode tests", "record-applied evidence tests", "after-report safety tests", "denied authority tests", "next-branch report policy handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-policy.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy"},
        .consumed_by = &.{ "agents", "reviewers", "production-hardening backlog", "future production hardening backlog refresh" },
        .compatibility = &.{ "strict-v1", "record-only", "required-status-check-enforcement-report-policy", "interpretation-policy", "planned-or-applied-source", "published-report-interpretation", "local-artifact-only", "no-tool-github-api-mutation", "no-tool-branch-protection-mutation", "no-tool-workflow-mutation", "no-tool-check-run-creation", "no-tool-ci-upload", "no-tool-github-step-summary-write", "no-tool-pr-comment", "no-live-ingestion", "no-durable-write", "no-nendb-write" },
        .governance_requirements = &.{ "source report application-boundary checks", "planned source interpretation tests", "applied source interpretation tests", "denied publication inference tests", "policy verification checks", "next-branch backlog refresh handoff" },
    },
    .{
        .schema = "zigeffect.causal.production-hardening-backlog-refresh.v1",
        .version = 1,
        .category = "production-hardening",
        .status = "current",
        .emitted_by = &.{"causal-production-hardening-backlog-refresh"},
        .consumed_by = &.{ "agents", "reviewers", "future NenDB durable history hardening" },
        .compatibility = &.{ "strict-v1", "read-only", "nendb-only", "local-artifact-only", "no-cockroach", "no-live-telemetry", "no-durable-write", "no-nendb-write", "no-mutation-authority" },
        .governance_requirements = &.{ "source backlog checks", "terminal delivered item check", "candidate selection checks", "denied inference checks", "next branch handoff" },
    },
    .{
        .schema = "zigeffect.causal.test-matrix.v1",
        .version = 1,
        .category = "test-coverage",
        .status = "current",
        .emitted_by = &.{"causal-test-matrix"},
        .consumed_by = &.{ "agents", "docs" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "matrix tests", "scenario coverage docs", "artifact manifest entry" },
    },
    .{
        .schema = "zigeffect.causal.remediation-audit.v1",
        .version = 1,
        .category = "governance",
        .status = "current",
        .emitted_by = &.{"causal-remediation-audit"},
        .consumed_by = &.{ "causal-remediation-decision", "causal-patch-proposal", "causal-audit-chain" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "schema validation tests", "guardrail tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.remediation-decision.v1",
        .version = 1,
        .category = "governance",
        .status = "current",
        .emitted_by = &.{"causal-remediation-decision"},
        .consumed_by = &.{ "causal-patch-proposal", "causal-audit-chain" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "schema validation tests", "decision gate tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.patch-proposal.v1",
        .version = 1,
        .category = "governance",
        .status = "current",
        .emitted_by = &.{"causal-patch-proposal"},
        .consumed_by = &.{ "causal-audit-chain", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "proposal guardrail tests", "schema validation tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.audit-chain.v1",
        .version = 1,
        .category = "governance",
        .status = "current",
        .emitted_by = &.{"causal-audit-chain"},
        .consumed_by = &.{ "causal-scenario-proposal", "causal-policy-decision", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "chain validation tests", "before-after evidence tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.scenario-proposal.v1",
        .version = 1,
        .category = "registry",
        .status = "current",
        .emitted_by = &.{"causal-scenario-proposal"},
        .consumed_by = &.{ "causal-scenario-registry-patch", "causal-policy-decision", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "scenario proposal tests", "registry guardrail tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.registry-patch.v1",
        .version = 1,
        .category = "registry",
        .status = "current",
        .emitted_by = &.{"causal-scenario-registry-patch"},
        .consumed_by = &.{ "causal-policy-decision", "causal-registry-application-readiness" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "patch validation tests", "policy gate tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.registry-application-readiness.v1",
        .version = 1,
        .category = "registry",
        .status = "current",
        .emitted_by = &.{"causal-registry-application-readiness"},
        .consumed_by = &.{"causal-registry-apply"},
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "readiness gate tests", "policy citation tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.registry-application.v1",
        .version = 1,
        .category = "registry",
        .status = "current",
        .emitted_by = &.{"causal-registry-apply"},
        .consumed_by = &.{ "causal-workbench", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "applied-state tests", "before-after verification tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.policy-decision.v1",
        .version = 1,
        .category = "governance",
        .status = "current",
        .emitted_by = &.{"causal-policy-decision"},
        .consumed_by = &.{ "registry gates", "agents", "causal-workbench" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "policy gate tests", "scenario ownership tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.snapshot-manifest.v1",
        .version = 1,
        .category = "snapshot-replay",
        .status = "current",
        .emitted_by = &.{"causal-snapshot"},
        .consumed_by = &.{ "causal-snapshot compare", "causal-snapshot audit-chain-compare", "causal-snapshot replay-feasibility", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "snapshot tests", "manifest validation tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.snapshot-compare.v1",
        .version = 1,
        .category = "snapshot-replay",
        .status = "current",
        .emitted_by = &.{"causal-snapshot"},
        .consumed_by = &.{ "agents", "causal-workbench" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "compare tests", "before-after query tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.audit-chain-snapshot-compare.v1",
        .version = 1,
        .category = "snapshot-replay",
        .status = "current",
        .emitted_by = &.{"causal-snapshot audit-chain-compare"},
        .consumed_by = &.{ "agents", "reviewers", "future workbench governance views", "future app-facing production fixtures" },
        .compatibility = &.{ "strict-v1", "record-only", "local-artifact-only", "no-mutation-authority" },
        .governance_requirements = &.{ "audit-chain compare tests", "applied-boundary tests", "schema governance docs", "backlog handoff" },
    },
    .{
        .schema = "zigeffect.causal.replay-feasibility.v1",
        .version = 1,
        .category = "snapshot-replay",
        .status = "current",
        .emitted_by = &.{"causal-snapshot"},
        .consumed_by = &.{ "agents", "reviewers" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "feasibility tests", "non-goal tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.deterministic-replay.v1",
        .version = 1,
        .category = "snapshot-replay",
        .status = "current",
        .emitted_by = &.{"causal-snapshot"},
        .consumed_by = &.{ "agents", "reviewers" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "registered scenario replay tests", "determinism tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.scenario-fork-proposal.v1",
        .version = 1,
        .category = "snapshot-replay",
        .status = "current",
        .emitted_by = &.{"causal-snapshot"},
        .consumed_by = &.{ "reviewers", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "proposal tests", "non-mutating guardrail tests", "docs" },
    },
    .{
        .schema = "zigeffect.causal.app-remediation-audit.v1",
        .version = 1,
        .category = "app-remediation",
        .status = "current",
        .emitted_by = &.{"causal-app-remediation-audit"},
        .consumed_by = &.{"causal-app-policy-decision"},
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "schema validation tests", "app guardrail tests", "docs", "workbench mapping" },
    },
    .{
        .schema = "zigeffect.causal.app-policy-decision.v1",
        .version = 1,
        .category = "app-remediation",
        .status = "current",
        .emitted_by = &.{"causal-app-policy-decision"},
        .consumed_by = &.{ "causal-app-human-review", "causal-app-patch-proposal" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "policy gate tests", "human-review gate tests", "docs", "workbench mapping" },
    },
    .{
        .schema = "zigeffect.causal.app-human-review.v1",
        .version = 1,
        .category = "app-remediation",
        .status = "current",
        .emitted_by = &.{"causal-app-human-review"},
        .consumed_by = &.{ "causal-app-patch-proposal", "causal-app-application-readiness" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "review evidence tests", "approval gate tests", "docs", "workbench mapping" },
    },
    .{
        .schema = "zigeffect.causal.app-patch-proposal.v1",
        .version = 1,
        .category = "app-remediation",
        .status = "current",
        .emitted_by = &.{"causal-app-patch-proposal"},
        .consumed_by = &.{"causal-app-application-readiness"},
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "proposal tests", "mutation-authority tests", "docs", "workbench mapping" },
    },
    .{
        .schema = "zigeffect.causal.app-application-readiness.v1",
        .version = 1,
        .category = "app-remediation",
        .status = "current",
        .emitted_by = &.{"causal-app-application-readiness"},
        .consumed_by = &.{"causal-app-apply"},
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "readiness tests", "verification command tests", "docs", "workbench mapping" },
    },
    .{
        .schema = "zigeffect.causal.app-application.v1",
        .version = 1,
        .category = "app-remediation",
        .status = "current",
        .emitted_by = &.{"causal-app-apply"},
        .consumed_by = &.{ "causal-workbench", "agents" },
        .compatibility = &.{ "strict-v1", "record-only" },
        .governance_requirements = &.{ "schema validation tests", "applied-state tests", "docs", "workbench mapping" },
    },
};

fn usage() []const u8 {
    return
    \\usage:
    \\  zig build causal-schema-governance
    \\  zig build causal-schema-governance -- --format text
    \\  zig build causal-schema-governance -- --format json
    \\
    \\formats:
    \\  --format text|json
    \\
    ;
}

fn schemaEntries() []const SchemaEntry {
    return schema_entries;
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

fn hasSchema(entries: []const SchemaEntry, schema: []const u8) bool {
    for (entries) |entry| {
        if (std.mem.eql(u8, entry.schema, schema)) return true;
    }
    return false;
}

fn expectSchema(entries: []const SchemaEntry, schema: []const u8) !void {
    try std.testing.expect(hasSchema(entries, schema));
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

fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.append(allocator, ']');
}

fn appendTextList(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    label: []const u8,
    values: []const []const u8,
) !void {
    try output.print(allocator, "  {s}: ", .{label});
    for (values, 0..) |value, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, value);
    }
    try output.append(allocator, '\n');
}

fn formatSchemaGovernanceText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal schema governance\n");
    try output.print(allocator, "schema: {s}\n", .{schema_governance_schema});
    try output.appendSlice(allocator, "schema_version: 1\n");
    try output.print(allocator, "core schema: {s} version {d}\n", .{ current_core_schema, current_core_schema_version });
    try output.print(allocator, "event taxonomy version: {d}\n", .{current_event_taxonomy_version});
    try output.print(allocator, "schema count: {d}\n", .{schema_entries.len});

    try output.appendSlice(allocator,
        \\
        \\versioning policy:
        \\- schema names the artifact family
        \\- schema_version tracks the current shape inside that family
        \\- event_taxonomy_version tracks event-kind role semantics
        \\
        \\migration policy:
        \\- legacy core artifacts without schema metadata remain readable
        \\- strict governance artifacts fail closed on unsupported schema/version
        \\- artifact rewrite tooling is deferred until a real v2 exists
        \\
        \\compatibility postures:
        \\- legacy-tolerant: accepts missing metadata and keeps event ids usable
        \\- warn-forward: warns on newer schema/taxonomy while preserving known fields
        \\- strict-v1: requires exact schema family and version 1
        \\- sink-contract: emitted for downstream backend/export systems
        \\- record-only: records review/application state without mutating source
        \\- viewer-session: read-only local workbench/session operating state
        \\- bounded-stream: ordered dashboard frame records with declared truncation and redaction state
        \\- spine-contract: defines shared identity and relationship vocabulary without changing source event emission
        \\- agent-query: compact bounded graph slices for agents
        \\- advisory-wall-clock: timing observations are advisory and require compatible environment metadata plus human review before blocking
        \\- planning-only: records deterministic planning assumptions and missing evidence without production sizing claims
        \\- completion-audit: deterministic milestone closure evidence with explicit remaining gaps and no production mutation authority
        \\- local-observation: bounded local command observation with advisory review gates and no production capacity claim
        \\
        \\schemas:
        \\
    );

    for (schema_entries) |entry| {
        try output.print(allocator, "- {s}\n", .{entry.schema});
        try output.print(allocator, "  version: {d}\n", .{entry.version});
        try output.print(allocator, "  category: {s}\n", .{entry.category});
        try output.print(allocator, "  status: {s}\n", .{entry.status});
        try appendTextList(allocator, &output, "compatibility", entry.compatibility);
        try appendTextList(allocator, &output, "emitted by", entry.emitted_by);
        try appendTextList(allocator, &output, "consumed by", entry.consumed_by);
        try appendTextList(allocator, &output, "governance requirements", entry.governance_requirements);
    }

    return output.toOwnedSlice(allocator);
}

fn formatSchemaGovernanceJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, schema_governance_schema);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"current_core_schema\": ");
    try appendJsonString(allocator, &output, current_core_schema);
    try output.appendSlice(allocator, ",\n");
    try output.print(allocator, "  \"current_core_schema_version\": {d},\n", .{current_core_schema_version});
    try output.print(allocator, "  \"current_event_taxonomy_version\": {d},\n", .{current_event_taxonomy_version});
    try output.print(allocator, "  \"schema_count\": {d},\n", .{schema_entries.len});
    try output.appendSlice(allocator,
        \\  "policy": {
        \\    "versioning": "schema names artifact family; schema_version tracks family shape; event_taxonomy_version tracks event-kind role semantics",
        \\    "migration": "legacy core artifacts remain readable; strict governance artifacts fail closed; rewrite tooling is deferred until a real v2 exists",
        \\    "new_schema_requirements": ["schema name", "schema_version", "producer", "consumer", "compatibility posture", "tests", "docs"]
        \\  },
        \\  "schemas": [
        \\
    );

    for (schema_entries, 0..) |entry, index| {
        try output.appendSlice(allocator, "    {\n");
        try output.appendSlice(allocator, "      \"schema\": ");
        try appendJsonString(allocator, &output, entry.schema);
        try output.appendSlice(allocator, ",\n");
        try output.print(allocator, "      \"version\": {d},\n", .{entry.version});
        try output.appendSlice(allocator, "      \"category\": ");
        try appendJsonString(allocator, &output, entry.category);
        try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "      \"status\": ");
        try appendJsonString(allocator, &output, entry.status);
        try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "      \"emitted_by\": ");
        try appendStringArray(allocator, &output, entry.emitted_by);
        try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "      \"consumed_by\": ");
        try appendStringArray(allocator, &output, entry.consumed_by);
        try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "      \"compatibility\": ");
        try appendStringArray(allocator, &output, entry.compatibility);
        try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "      \"governance_requirements\": ");
        try appendStringArray(allocator, &output, entry.governance_requirements);
        try output.appendSlice(allocator, "\n    }");
        if (index + 1 < schema_entries.len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }

    try output.appendSlice(allocator, "  ]\n}\n");
    return output.toOwnedSlice(allocator);
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-schema-governance error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatSchemaGovernanceText(init.gpa),
        .json => try formatSchemaGovernanceJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

test "schema governance usage names command and formats" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-schema-governance") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--format text|json") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.schema-governance.v1", schema_governance_schema);
}

test "schema governance inventory includes official schemas and excludes fake fixtures" {
    const entries = schemaEntries();
    try std.testing.expectEqual(@as(usize, 151), entries.len);
    try expectSchema(entries, "zigeffect.causal.v1");
    try expectSchema(entries, "zigeffect.causal.event.v1");
    try expectSchema(entries, "zigeffect.causal.app-application.v1");
    try expectSchema(entries, "zigeffect.causal.registry-application.v1");
    try expectSchema(entries, "zigeffect.causal.snapshot-manifest.v1");
    try expectSchema(entries, "zigeffect.causal.workbench-session.v1");
    try expectSchema(entries, "zigeffect.causal.performance-budget.v1");
    try expectSchema(entries, "zigeffect.causal.m9-completion-audit.v1");
    try expectSchema(entries, "zigeffect.causal.production-hardening-backlog.v1");
    try expectSchema(entries, "zigeffect.causal.production-artifact-aggregation.v1");
    try expectSchema(entries, "zigeffect.causal.durable-production-retention.v1");
    try expectSchema(entries, "zigeffect.causal.production-deployment-runbooks.v1");
    try expectSchema(entries, "zigeffect.causal.artifact-access-control.v1");
    try expectSchema(entries, "zigeffect.causal.encryption-at-rest-policy.v1");
    try expectSchema(entries, "zigeffect.causal.alerting-integrations.v1");
    try expectSchema(entries, "zigeffect.causal.live-dashboard-stream.v1");
    try expectSchema(entries, "zigeffect.causal.unified-spine-contract.v1");
    try expectSchema(entries, "zigeffect.causal.agent-query.v1");
    try expectSchema(entries, "zigeffect.causal.human-agent-feedback-loop.v1");
    try expectSchema(entries, "zigeffect.causal.rollout-automation-guardrails.v1");
    try expectSchema(entries, "zigeffect.causal.wall-clock-benchmark-baselines.v1");
    try expectSchema(entries, "zigeffect.causal.production-capacity-planning.v1");
    try expectSchema(entries, "zigeffect.causal.production-hardening-completion-audit.v1");
    try expectSchema(entries, "zigeffect.causal.load-test-observation-harness.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-capture-design.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-capture-fixtures.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-readiness-review.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-implementation-proposal.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-exporter-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-workbench-readonly-preview.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-artifact-preview.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-harness-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-archive-application.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-readiness.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-policy.v1");
    try expectSchema(entries, "zigeffect.causal.production-hardening-backlog-refresh.v1");
    try expectSchema(entries, "zigeffect.causal.nendb-retention-report.v1");
    try expectSchema(entries, "zigeffect.causal.nendb-durable-history.v1");
    try expectSchema(entries, "zigeffect.causal.audit-chain-snapshot-compare.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-fixtures.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-readiness-review.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-implementation-proposal.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-local-fixtures.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1");
    try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1");
    try std.testing.expect(!hasSchema(entries, "zigeffect.causal.other.v1"));
    try std.testing.expect(!hasSchema(entries, "zigeffect.causal.unknown.v1"));
}

test "schema governance entries have required metadata" {
    for (schemaEntries()) |entry| {
        try std.testing.expect(entry.schema.len > 0);
        try std.testing.expectEqual(@as(u32, 1), entry.version);
        try std.testing.expect(entry.category.len > 0);
        try std.testing.expect(entry.status.len > 0);
        try std.testing.expect(entry.emitted_by.len > 0);
        try std.testing.expect(entry.consumed_by.len > 0);
        try std.testing.expect(entry.compatibility.len > 0);
        try std.testing.expect(entry.governance_requirements.len > 0);
    }
}

test "schema governance text report includes policy and representative schemas" {
    const report = try formatSchemaGovernanceText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal schema governance") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.schema-governance.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema count: 151") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event taxonomy version: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "versioning policy:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "migration policy:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "advisory-wall-clock") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "planning-only") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "completion-audit") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "local-observation") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "no-live-ingestion") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "fixtures-only") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "readiness-review") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "implementation-proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "exporter-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "local-pipeline-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "nendb-retention-fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "workbench-readonly-preview") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "ci-artifact-preview") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "no-network") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "no-durable-write") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "fixtures-only") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-application.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.registry-application.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.snapshot-manifest.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.performance-budget.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.m9-completion-audit.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-hardening-backlog.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-artifact-aggregation.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.durable-production-retention.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-deployment-runbooks.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.artifact-access-control.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.encryption-at-rest-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.alerting-integrations.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.live-dashboard-stream.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.unified-spine-contract.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.agent-query.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.human-agent-feedback-loop.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.rollout-automation-guardrails.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.wall-clock-benchmark-baselines.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-capacity-planning.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-hardening-completion-audit.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.load-test-observation-harness.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-capture-design.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-capture-fixtures.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-readiness-review.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-implementation-proposal.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-exporter-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-workbench-readonly-preview.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-artifact-preview.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-harness-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-archive-application.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-readiness.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-hardening-backlog-refresh.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.nendb-retention-report.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.nendb-durable-history.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.audit-chain-snapshot-compare.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-fixtures.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-readiness-review.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-implementation-proposal.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-local-fixtures.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-application-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "nendb-handoff-fixtures") != null);
}

test "schema governance json report is machine readable" {
    const report = try formatSchemaGovernanceJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.schema-governance.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"current_core_schema\": \"zigeffect.causal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"current_event_taxonomy_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_count\": 151") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schemas\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"compatibility\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.performance-budget.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.m9-completion-audit.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-hardening-backlog.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-artifact-aggregation.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.durable-production-retention.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-deployment-runbooks.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.artifact-access-control.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.encryption-at-rest-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.alerting-integrations.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.live-dashboard-stream.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.unified-spine-contract.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.agent-query.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.human-agent-feedback-loop.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.rollout-automation-guardrails.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.wall-clock-benchmark-baselines.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-capacity-planning.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-hardening-completion-audit.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.load-test-observation-harness.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-capture-design.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-capture-fixtures.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-readiness-review.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-implementation-proposal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-exporter-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-workbench-readonly-preview.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-artifact-preview.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-harness-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-archive-application.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-readiness.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-hardening-backlog-refresh.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.nendb-retention-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.nendb-durable-history.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.audit-chain-snapshot-compare.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-fixtures.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-readiness-review.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-implementation-proposal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-local-fixtures.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1\"") != null);
}

test "schema governance parses format options" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-schema-governance"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-schema-governance", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-schema-governance", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-schema-governance", "--format", "yaml" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-schema-governance", "--json" }));
}
