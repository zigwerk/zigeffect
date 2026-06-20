# Causal Schema Governance

This is the registry of the official `zigeffect.causal.*` artifact schemas
produced and consumed by the surviving causal tools and backend adapters. It is a
snapshot of `zig build causal-schema-governance -- --format json` (the tool is the
source of truth — regenerate this file from it, do not hand-edit entries).

Governance rules:

- `schema` names the artifact family; `schema_version` tracks the current shape
  inside that family; `event_taxonomy_version` tracks event-kind role semantics.
- Legacy core artifacts without schema metadata remain readable; strict
  governance artifacts fail closed on unsupported schema/version; rewrite tooling
  is deferred until a real `v2` exists.
- A new schema requires: schema name, `schema_version`, producer, consumer,
  compatibility posture, tests, and docs. New `causal_*` tools that would add a
  schema must also have an approved entry in [tool-roadmap.md](tool-roadmap.md).

Regenerate this snapshot with:

```bash
cd packages/zigeffect
zig build causal-schema-governance -- --format json
```

## Snapshot

```json
{
  "schema": "zigeffect.causal.schema-governance.v1",
  "schema_version": 1,
  "current_core_schema": "zigeffect.causal.v1",
  "current_core_schema_version": 1,
  "current_event_taxonomy_version": 1,
  "schema_count": 36,
  "policy": {
    "versioning": "schema names artifact family; schema_version tracks family shape; event_taxonomy_version tracks event-kind role semantics",
    "migration": "legacy core artifacts remain readable; strict governance artifacts fail closed; rewrite tooling is deferred until a real v2 exists",
    "new_schema_requirements": ["schema name", "schema_version", "producer", "consumer", "compatibility posture", "tests", "docs"]
  },
  "schemas": [
    {
      "schema": "zigeffect.causal.v1",
      "version": 1,
      "category": "core-runtime",
      "status": "current",
      "emitted_by": ["formatCausalJson"],
      "consumed_by": ["causal-query", "causal-compare", "causal-loop", "causal-advice", "causal-workbench"],
      "compatibility": ["legacy-tolerant", "warn-forward"],
      "governance_requirements": ["compatibility tests", "taxonomy warning tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.event.v1",
      "version": 1,
      "category": "backend-export",
      "status": "current",
      "emitted_by": ["CausalJsonlBackend"],
      "consumed_by": ["jsonl readers", "agents", "external log processors"],
      "compatibility": ["sink-contract"],
      "governance_requirements": ["backend conformance tests", "adapter docs", "redaction tests"]
    },
    {
      "schema": "zigeffect.causal.otel_record.v1",
      "version": 1,
      "category": "backend-export",
      "status": "current",
      "emitted_by": ["CausalOtelBackend"],
      "consumed_by": ["OpenTelemetry exporters", "agents"],
      "compatibility": ["sink-contract"],
      "governance_requirements": ["backend conformance tests", "adapter docs", "redaction tests"]
    },
    {
      "schema": "zigeffect.causal.nendb_node.v1",
      "version": 1,
      "category": "backend-export",
      "status": "current",
      "emitted_by": ["CausalNenDbStorageBackend"],
      "consumed_by": ["NenDB adapter", "graph history queries", "agents"],
      "compatibility": ["sink-contract"],
      "governance_requirements": ["NenDB adapter tests", "bounded history tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.nendb_edge.v1",
      "version": 1,
      "category": "backend-export",
      "status": "current",
      "emitted_by": ["CausalNenDbStorageBackend"],
      "consumed_by": ["NenDB adapter", "graph history queries", "agents"],
      "compatibility": ["sink-contract"],
      "governance_requirements": ["NenDB adapter tests", "causal edge tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.nendb-retention-report.v1",
      "version": 1,
      "category": "backend-export",
      "status": "current",
      "emitted_by": ["CausalNendbStorageBackend"],
      "consumed_by": ["NenDB adapter", "agents"],
      "compatibility": ["sink-contract"],
      "governance_requirements": ["NenDB adapter tests", "retention report tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.nendb-durable-history.v1",
      "version": 1,
      "category": "backend-export",
      "status": "current",
      "emitted_by": ["CausalNendbStorageBackend"],
      "consumed_by": ["NenDB adapter", "agents"],
      "compatibility": ["sink-contract"],
      "governance_requirements": ["NenDB adapter tests", "durable history report tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.app-runtime.v1",
      "version": 1,
      "category": "app-runtime",
      "status": "current",
      "emitted_by": ["CausalAppRuntime"],
      "consumed_by": ["app remediation tools", "causal-workbench", "agents"],
      "compatibility": ["warn-forward", "record-only"],
      "governance_requirements": ["app runtime tests", "redaction tests", "workbench mapping", "docs"]
    },
    {
      "schema": "zigeffect.causal.dev-loop-verdict.v1",
      "version": 1,
      "category": "dev-loop",
      "status": "current",
      "emitted_by": ["causal-loop", "causal-verdict"],
      "consumed_by": ["causal-dev-agent", "causal-diagnosis", "agents"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["verdict tests", "agent handoff docs", "artifact manifest entry"]
    },
    {
      "schema": "zigeffect.causal.dev-session.v1",
      "version": 1,
      "category": "dev-loop",
      "status": "current",
      "emitted_by": ["causal-dev-session"],
      "consumed_by": ["agents", "causal-workbench"],
      "compatibility": ["record-only"],
      "governance_requirements": ["session tests", "bounded memory tests", "artifact manifest entry"]
    },
    {
      "schema": "zigeffect.causal.ci-verdict.v1",
      "version": 1,
      "category": "dev-loop",
      "status": "current",
      "emitted_by": ["causal-verdict", "causal-handoff"],
      "consumed_by": ["CI agents", "causal-dev-agent"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["CI verdict tests", "artifact manifest entry", "docs"]
    },
    {
      "schema": "zigeffect.causal.workbench-session.v1",
      "version": 1,
      "category": "workbench",
      "status": "current",
      "emitted_by": ["causal-workbench"],
      "consumed_by": ["SolidJS workbench", "zig-webui bridge"],
      "compatibility": ["viewer-session"],
      "governance_requirements": ["launcher tests", "read-only bridge tests", "UI build verification"]
    },
    {
      "schema": "zigeffect.causal.performance-budget.v1",
      "version": 1,
      "category": "operating-model",
      "status": "current",
      "emitted_by": ["causal-performance-budget"],
      "consumed_by": ["agents", "reviewers", "CI docs"],
      "compatibility": ["record-only"],
      "governance_requirements": ["budget report tests", "operations docs", "release guidance"]
    },
    {
      "schema": "zigeffect.causal.agent-query.v1",
      "version": 1,
      "category": "agent-query",
      "status": "current",
      "emitted_by": ["causal-query --agent"],
      "consumed_by": ["agents", "causal-dev-agent", "future workbench graph slices", "cross-run comparison"],
      "compatibility": ["strict-v1", "record-only", "bounded cross-run comparison"],
      "governance_requirements": ["agent query tests", "bounded response tests", "cross-run comparison tests", "policy metadata docs"]
    },
    {
      "schema": "zigeffect.causal.test-matrix.v1",
      "version": 1,
      "category": "test-coverage",
      "status": "current",
      "emitted_by": ["causal-test-matrix"],
      "consumed_by": ["agents", "docs"],
      "compatibility": ["record-only"],
      "governance_requirements": ["matrix tests", "scenario coverage docs", "artifact manifest entry"]
    },
    {
      "schema": "zigeffect.causal.remediation-audit.v1",
      "version": 1,
      "category": "governance",
      "status": "current",
      "emitted_by": ["causal-remediation-audit"],
      "consumed_by": ["causal-remediation-decision", "causal-patch-proposal", "causal-audit-chain"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["schema validation tests", "guardrail tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.remediation-decision.v1",
      "version": 1,
      "category": "governance",
      "status": "current",
      "emitted_by": ["causal-remediation-decision"],
      "consumed_by": ["causal-patch-proposal", "causal-audit-chain"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["schema validation tests", "decision gate tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.patch-proposal.v1",
      "version": 1,
      "category": "governance",
      "status": "current",
      "emitted_by": ["causal-patch-proposal"],
      "consumed_by": ["causal-audit-chain", "agents"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["proposal guardrail tests", "schema validation tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.audit-chain.v1",
      "version": 1,
      "category": "governance",
      "status": "current",
      "emitted_by": ["causal-audit-chain"],
      "consumed_by": ["causal-scenario-proposal", "causal-policy-decision", "agents"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["chain validation tests", "before-after evidence tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.scenario-proposal.v1",
      "version": 1,
      "category": "registry",
      "status": "current",
      "emitted_by": ["causal-scenario-proposal"],
      "consumed_by": ["causal-scenario-registry-patch", "causal-policy-decision", "agents"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["scenario proposal tests", "registry guardrail tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.registry-patch.v1",
      "version": 1,
      "category": "registry",
      "status": "current",
      "emitted_by": ["causal-scenario-registry-patch"],
      "consumed_by": ["causal-policy-decision", "causal-registry-application-readiness"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["patch validation tests", "policy gate tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.registry-application-readiness.v1",
      "version": 1,
      "category": "registry",
      "status": "current",
      "emitted_by": ["causal-registry-application-readiness"],
      "consumed_by": ["causal-registry-apply"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["readiness gate tests", "policy citation tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.registry-application.v1",
      "version": 1,
      "category": "registry",
      "status": "current",
      "emitted_by": ["causal-registry-apply"],
      "consumed_by": ["causal-workbench", "agents"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["applied-state tests", "before-after verification tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.policy-decision.v1",
      "version": 1,
      "category": "governance",
      "status": "current",
      "emitted_by": ["causal-policy-decision"],
      "consumed_by": ["registry gates", "agents", "causal-workbench"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["policy gate tests", "scenario ownership tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.snapshot-manifest.v1",
      "version": 1,
      "category": "snapshot-replay",
      "status": "current",
      "emitted_by": ["causal-snapshot"],
      "consumed_by": ["causal-snapshot compare", "causal-snapshot audit-chain-compare", "causal-snapshot replay-feasibility", "agents"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["snapshot tests", "manifest validation tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.snapshot-compare.v1",
      "version": 1,
      "category": "snapshot-replay",
      "status": "current",
      "emitted_by": ["causal-snapshot"],
      "consumed_by": ["agents", "causal-workbench"],
      "compatibility": ["record-only"],
      "governance_requirements": ["compare tests", "before-after query tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.audit-chain-snapshot-compare.v1",
      "version": 1,
      "category": "snapshot-replay",
      "status": "current",
      "emitted_by": ["causal-snapshot audit-chain-compare"],
      "consumed_by": ["agents", "reviewers", "future workbench governance views", "future app-facing production fixtures"],
      "compatibility": ["strict-v1", "record-only", "local-artifact-only", "no-mutation-authority"],
      "governance_requirements": ["audit-chain compare tests", "applied-boundary tests", "schema governance docs", "backlog handoff"]
    },
    {
      "schema": "zigeffect.causal.replay-feasibility.v1",
      "version": 1,
      "category": "snapshot-replay",
      "status": "current",
      "emitted_by": ["causal-snapshot"],
      "consumed_by": ["agents", "reviewers"],
      "compatibility": ["record-only"],
      "governance_requirements": ["feasibility tests", "non-goal tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.deterministic-replay.v1",
      "version": 1,
      "category": "snapshot-replay",
      "status": "current",
      "emitted_by": ["causal-snapshot"],
      "consumed_by": ["agents", "reviewers"],
      "compatibility": ["record-only"],
      "governance_requirements": ["registered scenario replay tests", "determinism tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.scenario-fork-proposal.v1",
      "version": 1,
      "category": "snapshot-replay",
      "status": "current",
      "emitted_by": ["causal-snapshot"],
      "consumed_by": ["reviewers", "agents"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["proposal tests", "non-mutating guardrail tests", "docs"]
    },
    {
      "schema": "zigeffect.causal.app-remediation-audit.v1",
      "version": 1,
      "category": "app-remediation",
      "status": "current",
      "emitted_by": ["causal-app-remediation-audit"],
      "consumed_by": ["causal-app-policy-decision"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["schema validation tests", "app guardrail tests", "docs", "workbench mapping"]
    },
    {
      "schema": "zigeffect.causal.app-policy-decision.v1",
      "version": 1,
      "category": "app-remediation",
      "status": "current",
      "emitted_by": ["causal-app-policy-decision"],
      "consumed_by": ["causal-app-human-review", "causal-app-patch-proposal"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["policy gate tests", "human-review gate tests", "docs", "workbench mapping"]
    },
    {
      "schema": "zigeffect.causal.app-human-review.v1",
      "version": 1,
      "category": "app-remediation",
      "status": "current",
      "emitted_by": ["causal-app-human-review"],
      "consumed_by": ["causal-app-patch-proposal", "causal-app-application-readiness"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["review evidence tests", "approval gate tests", "docs", "workbench mapping"]
    },
    {
      "schema": "zigeffect.causal.app-patch-proposal.v1",
      "version": 1,
      "category": "app-remediation",
      "status": "current",
      "emitted_by": ["causal-app-patch-proposal"],
      "consumed_by": ["causal-app-application-readiness"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["proposal tests", "mutation-authority tests", "docs", "workbench mapping"]
    },
    {
      "schema": "zigeffect.causal.app-application-readiness.v1",
      "version": 1,
      "category": "app-remediation",
      "status": "current",
      "emitted_by": ["causal-app-application-readiness"],
      "consumed_by": ["causal-app-apply"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["readiness tests", "verification command tests", "docs", "workbench mapping"]
    },
    {
      "schema": "zigeffect.causal.app-application.v1",
      "version": 1,
      "category": "app-remediation",
      "status": "current",
      "emitted_by": ["causal-app-apply"],
      "consumed_by": ["causal-workbench", "agents"],
      "compatibility": ["strict-v1", "record-only"],
      "governance_requirements": ["schema validation tests", "applied-state tests", "docs", "workbench mapping"]
    }
  ]
}
```
