zigeffect causal schema governance
schema: zigeffect.causal.schema-governance.v1
schema_version: 1
core schema: zigeffect.causal.v1 version 1
event taxonomy version: 1
schema count: 92

versioning policy:
- schema names the artifact family
- schema_version tracks the current shape inside that family
- event_taxonomy_version tracks event-kind role semantics

migration policy:
- legacy core artifacts without schema metadata remain readable
- strict governance artifacts fail closed on unsupported schema/version
- artifact rewrite tooling is deferred until a real v2 exists

compatibility postures:
- legacy-tolerant: accepts missing metadata and keeps event ids usable
- warn-forward: warns on newer schema/taxonomy while preserving known fields
- strict-v1: requires exact schema family and version 1
- sink-contract: emitted for downstream backend/export systems
- record-only: records review/application state without mutating source
- viewer-session: read-only local workbench/session operating state
- bounded-stream: ordered dashboard frame records with declared truncation and redaction state
- spine-contract: defines shared identity and relationship vocabulary without changing source event emission
- agent-query: compact bounded graph slices for agents
- advisory-wall-clock: timing observations are advisory and require compatible environment metadata plus human review before blocking
- planning-only: records deterministic planning assumptions and missing evidence without production sizing claims
- completion-audit: deterministic milestone closure evidence with explicit remaining gaps and no production mutation authority
- local-observation: bounded local command observation with advisory review gates and no production capacity claim

schemas:
- zigeffect.causal.v1
  version: 1
  category: core-runtime
  status: current
  compatibility: legacy-tolerant, warn-forward
  emitted by: formatCausalJson
  consumed by: causal-query, causal-compare, causal-loop, causal-advice, causal-workbench
  governance requirements: compatibility tests, taxonomy warning tests, docs
- zigeffect.causal.event.v1
  version: 1
  category: backend-export
  status: current
  compatibility: sink-contract
  emitted by: CausalJsonlBackend
  consumed by: jsonl readers, agents, external log processors
  governance requirements: backend conformance tests, adapter docs, redaction tests
- zigeffect.causal.otel_record.v1
  version: 1
  category: backend-export
  status: current
  compatibility: sink-contract
  emitted by: CausalOtelBackend
  consumed by: OpenTelemetry exporters, agents
  governance requirements: backend conformance tests, adapter docs, redaction tests
- zigeffect.causal.nendb_node.v1
  version: 1
  category: backend-export
  status: current
  compatibility: sink-contract
  emitted by: CausalNenDbStorageBackend
  consumed by: NenDB adapter, graph history queries, agents
  governance requirements: NenDB adapter tests, bounded history tests, docs
- zigeffect.causal.nendb_edge.v1
  version: 1
  category: backend-export
  status: current
  compatibility: sink-contract
  emitted by: CausalNenDbStorageBackend
  consumed by: NenDB adapter, graph history queries, agents
  governance requirements: NenDB adapter tests, causal edge tests, docs
- zigeffect.causal.nendb-retention-report.v1
  version: 1
  category: backend-export
  status: current
  compatibility: record-only
  emitted by: CausalNenDbStorageBackend.retentionReport
  consumed by: causal-durable-production-retention, NenDB adapter tests, agents
  governance requirements: NenDB retention tests, durable retention docs, schema governance entry
- zigeffect.causal.nendb-durable-history.v1
  version: 1
  category: backend-export
  status: current
  compatibility: strict-v1, nendb-only, local-fixture, record-only, no-cockroach, no-live-telemetry, no-network, no-production-mutation
  emitted by: CausalNendbStorageBackendState.durableHistoryReport, causal-nendb-durable-history-hardening
  consumed by: agents, reviewers, future cross-run query comparison, future audit-chain snapshot comparison, future app-facing production fixtures
  governance requirements: runtime report tests, fixture tool tests, redaction evidence checks, query evidence checks, next branch handoff
- zigeffect.causal.app-runtime.v1
  version: 1
  category: app-runtime
  status: current
  compatibility: warn-forward, record-only
  emitted by: CausalAppRuntime
  consumed by: app remediation tools, causal-workbench, agents
  governance requirements: app runtime tests, redaction tests, workbench mapping, docs
- zigeffect.causal.dev-loop-verdict.v1
  version: 1
  category: dev-loop
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-loop, causal-verdict
  consumed by: causal-dev-agent, causal-diagnosis, agents
  governance requirements: verdict tests, agent handoff docs, artifact manifest entry
- zigeffect.causal.dev-session.v1
  version: 1
  category: dev-loop
  status: current
  compatibility: record-only
  emitted by: causal-dev-session
  consumed by: agents, causal-workbench
  governance requirements: session tests, bounded memory tests, artifact manifest entry
- zigeffect.causal.ci-verdict.v1
  version: 1
  category: dev-loop
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-verdict, causal-handoff
  consumed by: CI agents, causal-dev-agent
  governance requirements: CI verdict tests, artifact manifest entry, docs
- zigeffect.causal.workbench-session.v1
  version: 1
  category: workbench
  status: current
  compatibility: viewer-session
  emitted by: causal-workbench
  consumed by: SolidJS workbench, zig-webui bridge
  governance requirements: launcher tests, read-only bridge tests, UI build verification
- zigeffect.causal.performance-budget.v1
  version: 1
  category: operating-model
  status: current
  compatibility: record-only
  emitted by: causal-performance-budget
  consumed by: agents, reviewers, CI docs
  governance requirements: budget report tests, operations docs, release guidance
- zigeffect.causal.m9-completion-audit.v1
  version: 1
  category: operating-model
  status: current
  compatibility: record-only
  emitted by: causal-m9-completion-audit
  consumed by: agents, reviewers, roadmap audit
  governance requirements: completion audit tests, operations docs, roadmap update
- zigeffect.causal.production-hardening-backlog.v1
  version: 1
  category: operating-model
  status: current
  compatibility: record-only
  emitted by: causal-production-hardening-backlog
  consumed by: agents, reviewers, future hardening branch workers
  governance requirements: backlog report tests, operations docs, roadmap update
- zigeffect.causal.production-artifact-aggregation.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: record-only
  emitted by: causal-production-artifact-aggregation
  consumed by: durable retention, access control, workbench, integrations, agents
  governance requirements: aggregation contract tests, operations docs, roadmap update
- zigeffect.causal.durable-production-retention.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: record-only
  emitted by: causal-durable-production-retention
  consumed by: deployment runbooks, artifact access control, workbench, agents
  governance requirements: durable retention tests, NenDB retention fixture, operations docs, roadmap update
- zigeffect.causal.production-deployment-runbooks.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: record-only
  emitted by: causal-production-deployment-runbooks
  consumed by: artifact access control, alerting integrations, rollout guardrails, agents
  governance requirements: deployment runbook tests, operations docs, roadmap update
- zigeffect.causal.artifact-access-control.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: record-only
  emitted by: causal-artifact-access-control
  consumed by: SolidJS workbench, agent query interface, live dashboard, integrations, future production hosts
  governance requirements: access-control tests, negative fixtures, operations docs, roadmap update
- zigeffect.causal.encryption-at-rest-policy.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: record-only
  emitted by: causal-encryption-at-rest-policy
  consumed by: durable retention, artifact access control, future encrypted storage adapters, agents
  governance requirements: encryption policy tests, redaction interaction fixtures, operations docs, roadmap update
- zigeffect.causal.alerting-integrations.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: record-only
  emitted by: causal-alerting-integrations
  consumed by: deployment runbooks, rollout guardrails, human-agent feedback loop, live dashboard planning, agents
  governance requirements: alerting integration tests, negative fixtures, operations docs, roadmap update
- zigeffect.causal.live-dashboard-stream.v1
  version: 1
  category: workbench
  status: current
  compatibility: record-only, bounded-stream, viewer-session
  emitted by: causal-live-dashboard-streaming-workbench fixtures, future dashboard transports
  consumed by: SolidJS workbench, Visual Graph tab, agents, future production dashboard hosts
  governance requirements: stream model tests, bounded sample fixture, Solid G6 adapter boundary docs, workbench build verification
- zigeffect.causal.unified-spine-contract.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: record-only, spine-contract
  emitted by: causal-unified-spine-contract
  consumed by: deep runtime internals, app semantic trace API, agent query interface, SolidJS workbench, NenDB adapter projection
  governance requirements: contract tests, projection boundary docs, roadmap update
- zigeffect.causal.agent-query.v1
  version: 1
  category: agent-query
  status: current
  compatibility: strict-v1, record-only, bounded cross-run comparison
  emitted by: causal-query --agent
  consumed by: agents, causal-dev-agent, future workbench graph slices, cross-run comparison
  governance requirements: agent query tests, bounded response tests, cross-run comparison tests, policy metadata docs
- zigeffect.causal.app-facing-production-integration-fixtures.v1
  version: 1
  category: app-runtime
  status: current
  compatibility: strict-v1, fixture-only, record-only, nendb-only, no-cockroach, no-live-telemetry, no-production-mutation
  emitted by: causal-app-facing-production-integration-fixtures
  consumed by: agents, reviewers, future app-facing production integration readiness review, future SolidJS workbench production app views
  governance requirements: fixture tool tests, source contract coverage, redaction negative fixtures, backlog update, docs update
- zigeffect.causal.app-facing-production-integration-readiness-review.v1
  version: 1
  category: app-runtime
  status: current
  compatibility: strict-v1, record-only, readiness-review, nendb-only, no-cockroach, no-live-telemetry, no-production-mutation
  emitted by: causal-app-facing-production-integration-readiness-review
  consumed by: agents, reviewers, production-hardening backlog, future app-facing production integration implementation proposal
  governance requirements: readiness review tests, fixture evidence checks, verification command evidence, next-branch handoff, docs update
- zigeffect.causal.app-facing-production-integration-implementation-proposal.v1
  version: 1
  category: app-runtime
  status: current
  compatibility: strict-v1, record-only, implementation-proposal, nendb-only, no-cockroach, no-live-telemetry, no-production-mutation
  emitted by: causal-app-facing-production-integration-implementation-proposal
  consumed by: agents, reviewers, production-hardening backlog, future app-facing production integration boundary
  governance requirements: implementation proposal tests, readiness artifact checks, verification command evidence, next-branch handoff, docs update
- zigeffect.causal.app-facing-production-integration-boundary.v1
  version: 1
  category: app-runtime
  status: current
  compatibility: strict-v1, record-only, guarded-boundary, nendb-only, no-cockroach, no-live-telemetry, no-production-mutation
  emitted by: causal-app-facing-production-integration-boundary
  consumed by: agents, reviewers, production-hardening backlog, future app-facing production integration local fixtures, future SolidJS workbench production app views
  governance requirements: boundary tests, proposal artifact checks, verification command evidence, next-branch handoff, docs update
- zigeffect.causal.app-facing-production-integration-local-fixtures.v1
  version: 1
  category: app-runtime
  status: current
  compatibility: strict-v1, record-only, local-fixtures, fixture-only, nendb-only, no-cockroach, no-live-telemetry, no-production-mutation
  emitted by: causal-app-facing-production-integration-local-fixtures
  consumed by: agents, reviewers, production-hardening backlog, future app-facing NenDB handoff fixtures, future SolidJS workbench production app views
  governance requirements: local fixture tests, boundary artifact checks, fixture validation checks, verification command evidence, next-branch handoff, docs update
- zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1
  version: 1
  category: app-runtime
  status: current
  compatibility: strict-v1, record-only, nendb-handoff-fixtures, fixture-only, nendb-only, no-cockroach, no-live-telemetry, no-production-mutation, no-nendb-write
  emitted by: causal-app-facing-production-integration-nendb-handoff-fixtures
  consumed by: agents, reviewers, production-hardening backlog, future app-facing audit remediation bridge, future SolidJS workbench production app views
  governance requirements: handoff fixture tests, local fixture artifact checks, NenDB node and edge handoff checks, verification command evidence, next-branch handoff, docs update
- zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1
  version: 1
  category: app-runtime
  status: current
  compatibility: strict-v1, record-only, audit-remediation-bridge, evidence-only, nendb-handoff-fixture-source, no-cockroach, no-live-telemetry, no-production-mutation, no-nendb-write, no-auto-apply
  emitted by: causal-app-facing-production-integration-audit-remediation-bridge
  consumed by: agents, reviewers, production-hardening backlog, future app-facing SolidJS read-only preview, future guarded app remediation planning
  governance requirements: bridge tests, NenDB handoff artifact checks, audit/remediation bridge catalog checks, verification command evidence, next-branch handoff, docs update
- zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1
  version: 1
  category: app-runtime
  status: current
  compatibility: strict-v1, read-only, solid-webui, webui-dev/zig-webui, no-cockroach, no-live-dashboard, no-production-mutation, no-nendb-write, no-nendb-adapter-execution, no-ci-enforcement, no-react-renderer
  emitted by: causal-app-facing-production-integration-solid-webui-readonly-preview
  consumed by: agents, reviewers, local SolidJS workbench, production-hardening backlog, future CI advisory remediation report
  governance requirements: preview producer tests, source bridge artifact checks, SolidJS workbench parser tests, WebUI sample tests, verification command evidence, next-branch handoff, docs update
- zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report.v1
  version: 1
  category: app-runtime
  status: current
  compatibility: strict-v1, advisory-only, read-only, solid-webui, webui-dev/zig-webui, no-cockroach, no-ci-enforcement, no-required-status-check, no-workflow-mutation, no-github-api-mutation, no-production-mutation, no-nendb-write, no-nendb-adapter-execution
  emitted by: causal-app-facing-production-integration-ci-advisory-remediation-report
  consumed by: agents, reviewers, local SolidJS workbench, production-hardening backlog, future app-facing advisory report application boundary
  governance requirements: report producer tests, source preview artifact checks, CI advisory bridge checks, SolidJS workbench parser tests, WebUI sample tests, verification command evidence, next-branch handoff, docs update
- zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-application-boundary.v1
  version: 1
  category: app-runtime
  status: current
  compatibility: strict-v1, record-only, advisory-only, application-boundary, reviewed-before-after-evidence, solid-webui, webui-dev/zig-webui, no-cockroach, no-ci-enforcement, no-required-status-check, no-workflow-mutation, no-github-api-mutation, no-app-mutation, no-deployment-mutation, no-production-mutation, no-nendb-write, no-nendb-adapter-execution
  emitted by: causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary
  consumed by: agents, reviewers, production-hardening backlog, future app-facing advisory report publication policy
  governance requirements: application boundary producer tests, source advisory report artifact checks, before/after evidence checks, after-report safety checks, verification command evidence, next-branch handoff, docs update
- zigeffect.causal.human-agent-feedback-loop.v1
  version: 1
  category: human-agent-feedback
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none
  emitted by: causal-human-agent-feedback-loop
  consumed by: agents, SolidJS workbench, causal-dev-loop, future NenDB adapter handoff
  governance requirements: feedback-loop tests, guardrail tests, workflow docs, backlog handoff
- zigeffect.causal.rollout-automation-guardrails.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none
  emitted by: causal-rollout-automation-guardrails
  consumed by: agents, reviewers, deployment runbooks, alerting integrations, future rollout hosts
  governance requirements: rollout guardrail tests, negative automation fixtures, operations docs, roadmap update
- zigeffect.causal.wall-clock-benchmark-baselines.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, advisory-wall-clock
  emitted by: causal-wall-clock-benchmark-baselines
  consumed by: agents, reviewers, future benchmark observation harness, future production capacity planning
  governance requirements: benchmark baseline tests, wall-clock caveat docs, environment metadata policy, capacity planning handoff
- zigeffect.causal.production-capacity-planning.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, planning-only
  emitted by: causal-production-capacity-planning
  consumed by: agents, reviewers, production-hardening completion audit, future load-test harnesses, future production planning
  governance requirements: capacity planning tests, storage assumption docs, load-test fixture docs, completion audit handoff
- zigeffect.causal.production-hardening-completion-audit.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, completion-audit
  emitted by: causal-production-hardening-completion-audit
  consumed by: agents, reviewers, production-hardening backlog, load-test observation harness
  governance requirements: completion audit tests, boundary docs, remaining gap docs, next-branch handoff
- zigeffect.causal.load-test-observation-harness.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, local-observation
  emitted by: causal-load-test-observation-harness
  consumed by: agents, reviewers, production telemetry capture design, future capacity sizing review
  governance requirements: observation harness tests, bounded runner tests, redaction docs, next-branch handoff
- zigeffect.causal.production-telemetry-capture-design.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, design-only, no-live-ingestion
  emitted by: causal-production-telemetry-capture-design
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry capture fixtures
  governance requirements: telemetry capture design tests, redaction gate docs, negative telemetry fixtures, next-branch handoff
- zigeffect.causal.production-telemetry-capture-fixtures.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, fixtures-only, no-live-ingestion
  emitted by: causal-production-telemetry-capture-fixtures
  consumed by: agents, reviewers, production-hardening backlog, production telemetry readiness review
  governance requirements: fixture catalog tests, validation report tests, negative telemetry fixtures, next-branch handoff
- zigeffect.causal.production-telemetry-readiness-review.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, readiness-review, no-live-ingestion
  emitted by: causal-production-telemetry-readiness-review
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry implementation proposal
  governance requirements: readiness review tests, fixture evidence checks, verification command evidence, next-branch handoff
- zigeffect.causal.production-telemetry-implementation-proposal.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, implementation-proposal, no-live-ingestion
  emitted by: causal-production-telemetry-implementation-proposal
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry exporter boundary
  governance requirements: proposal tests, readiness evidence checks, verification command evidence, next-branch handoff
- zigeffect.causal.production-telemetry-exporter-boundary.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, exporter-boundary, no-live-ingestion, no-network
  emitted by: causal-production-telemetry-exporter-boundary
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry local pipeline fixtures
  governance requirements: boundary tests, proposal evidence checks, no-network checks, next-branch handoff
- zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, local-pipeline-fixtures, fixtures-only, no-live-ingestion, no-network
  emitted by: causal-production-telemetry-local-pipeline-fixtures
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry NenDB retention fixtures
  governance requirements: fixture catalog tests, boundary evidence checks, redaction and sampling fixture checks, next-branch handoff
- zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, nendb-retention-fixtures, fixtures-only, no-live-ingestion, no-network, no-durable-write
  emitted by: causal-production-telemetry-nendb-retention-fixtures
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry workbench read-only preview
  governance requirements: NenDB mapping fixture tests, local pipeline evidence checks, retention policy checks, next-branch handoff
- zigeffect.causal.production-telemetry-workbench-readonly-preview.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, workbench-readonly-preview, solid-webui, no-live-ingestion, no-network, no-durable-write, no-nendb-write
  emitted by: causal-production-telemetry-workbench-readonly-preview
  consumed by: agents, reviewers, SolidJS webui workbench, production-hardening backlog, future production telemetry CI artifact preview
  governance requirements: workbench tests, source retention evidence checks, read-only authority checks, next-branch handoff
- zigeffect.causal.production-telemetry-ci-artifact-preview.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, ci-artifact-preview, preview-only, failure-attachment-catalog, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-ci-gate
  emitted by: causal-production-telemetry-ci-artifact-preview
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI harness boundary
  governance requirements: source workbench preview evidence checks, artifact candidate allowlist checks, preview-only CI authority checks, next-branch handoff
- zigeffect.causal.production-telemetry-ci-harness-boundary.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, mutation-authority-none, ci-harness-boundary, workflow-inspection, cluster-release-gate-aware, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-ci-gate, no-workflow-mutation
  emitted by: causal-production-telemetry-ci-harness-boundary
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI archive application
  governance requirements: source CI preview evidence checks, workflow required-feature checks, workflow prohibited-feature checks, cluster release-gate assumptions, next-branch handoff
- zigeffect.causal.production-telemetry-ci-archive-application.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, guarded-application, plan-or-record-applied, workflow-evidence, before-after-verification, cluster-release-gate-aware, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-ci-gate, no-tool-workflow-mutation
  emitted by: causal-production-telemetry-ci-archive-application
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI archive evidence policy
  governance requirements: source CI harness boundary evidence checks, workflow change evidence checks, before/after evidence checks, post-application verification checks, next-branch handoff
- zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, archive-evidence-policy, interpretation-policy, cluster-release-gate-aware, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-ci-gate, no-tool-workflow-mutation
  emitted by: causal-production-telemetry-ci-archive-evidence-policy
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate readiness
  governance requirements: source CI archive application evidence checks, evidence class catalog tests, interpretation rule tests, negative evidence fixtures, next-branch handoff
- zigeffect.causal.production-telemetry-ci-gate-readiness.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, ci-gate-readiness, gate-semantics, cluster-release-gate-aware, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-ci-gate-enforcement, no-workflow-mutation
  emitted by: causal-production-telemetry-ci-gate-readiness
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate application boundary
  governance requirements: source archive evidence policy checks, candidate gate signal tests, release-gate verification checks, negative gate fixtures, next-branch handoff
- zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, gate-application-boundary, plan-or-record-applied, before-after-verification, cluster-release-gate-aware, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-ci-gate-enforcement, no-tool-workflow-mutation
  emitted by: causal-production-telemetry-ci-gate-application-boundary
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate dry-run policy
  governance requirements: source CI gate readiness evidence checks, workflow change evidence checks, before/after evidence checks, after-workflow safety checks, next-branch handoff
- zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, dry-run-policy, advisory-only, bounded-ci-artifacts, cluster-release-gate-aware, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-ci-gate-enforcement, no-required-status-check, no-tool-workflow-mutation
  emitted by: causal-production-telemetry-ci-gate-dry-run-policy
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate dry-run evaluator
  governance requirements: source gate application boundary checks, candidate signal policy tests, evidence requirement tests, negative dry-run fixtures, next-branch evaluator handoff
- zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, dry-run-evaluator, advisory-findings, bounded-explicit-evidence, cluster-release-gate-aware, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-ci-gate-enforcement, no-required-status-check, no-tool-workflow-mutation
  emitted by: causal-production-telemetry-ci-gate-dry-run-evaluator
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate advisory CI report
  governance requirements: source dry-run policy checks, explicit evidence boundary tests, advisory signal tests, denied evidence fixtures, next-branch advisory CI report handoff
- zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, advisory-ci-report, reviewer-guidance, local-artifact-only, cluster-release-gate-aware, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-ci-gate-enforcement, no-required-status-check, no-tool-workflow-mutation, no-github-step-summary-write, no-pr-comment
  emitted by: causal-production-telemetry-ci-gate-advisory-ci-report
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate advisory CI report application boundary
  governance requirements: source evaluator checks, record-only publication channel tests, advisory rendering tests, negative blocked evaluator fixtures, next-branch report application boundary handoff
- zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, report-application-boundary, plan-or-record-applied, before-after-verification, local-artifact-only, cluster-release-gate-aware, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-ci-gate-enforcement, no-required-status-check, no-tool-workflow-mutation, no-tool-ci-upload, no-tool-github-step-summary-write, no-tool-pr-comment
  emitted by: causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate advisory CI report publication policy
  governance requirements: source advisory CI report checks, publication evidence tests, before/after evidence tests, report safety tests, negative application fixtures, next-branch publication policy handoff
- zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, publication-policy, interpretation-policy, non-blocking-advisory, cluster-release-gate-aware, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-ci-gate-enforcement, no-required-status-check, no-tool-workflow-mutation, no-tool-ci-upload, no-tool-github-step-summary-write, no-tool-pr-comment
  emitted by: causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate required status check readiness
  governance requirements: source application boundary checks, interpretation rule tests, denied inference tests, negative publication policy fixtures, next-branch required status check readiness handoff
- zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, required-status-check-readiness, gate-semantics, activation-guardrails, non-blocking-advisory-source, cluster-release-gate-aware, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-ci-gate-enforcement, no-required-status-check, no-branch-protection-mutation, no-github-api-mutation, no-tool-workflow-mutation, no-tool-ci-upload, no-tool-github-step-summary-write, no-tool-pr-comment
  emitted by: causal-production-telemetry-ci-gate-required-status-check-readiness
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate required status check application boundary
  governance requirements: source publication policy checks, candidate required-check profile tests, activation guardrail tests, denied inference tests, next-branch required status check application boundary handoff
- zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, required-status-check-application-boundary, plan-or-record-applied, before-after-verification, branch-protection-evidence, check-run-evidence, cluster-release-gate-aware, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-tool-github-api-mutation, no-tool-branch-protection-mutation, no-tool-workflow-mutation, no-tool-ci-upload, no-tool-github-step-summary-write, no-tool-pr-comment
  emitted by: causal-production-telemetry-ci-gate-required-status-check-application-boundary
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate required status check policy
  governance requirements: source readiness checks, branch-protection evidence checks, workflow or check-run evidence checks, after-state safety checks, next-branch required status check policy handoff
- zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, required-status-check-policy, interpretation-policy, planned-or-applied-source, branch-protection-evidence, cluster-release-gate-aware, no-live-ingestion, no-network, no-durable-write, no-nendb-write, no-tool-github-api-mutation, no-tool-branch-protection-mutation, no-tool-workflow-mutation, no-tool-ci-upload, no-tool-github-step-summary-write, no-tool-pr-comment
  emitted by: causal-production-telemetry-ci-gate-required-status-check-policy
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate required status check enforcement readiness
  governance requirements: source application-boundary checks, planned source interpretation tests, applied source interpretation tests, denied inference tests, required-check surface policy tests, next-branch enforcement-readiness handoff
- zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, required-status-check-enforcement-readiness, applied-source-required-for-ready, active-enforcement-claim-denied, merge-blocker-claim-denied, branch-protection-evidence, workflow-or-check-run-evidence, owner-approval, rollback-evidence, no-tool-github-api-mutation, no-tool-branch-protection-mutation, no-tool-workflow-mutation, no-tool-ci-upload, no-live-ingestion, no-durable-write, no-nendb-write
  emitted by: causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate required status check enforcement application boundary
  governance requirements: source policy checks, applied source checks, required check name evidence, branch-protection evidence, workflow or check-run evidence, failure-mode evidence, owner approval evidence, rollback evidence, active enforcement denied inference tests, next-branch enforcement application-boundary handoff
- zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, required-status-check-enforcement-application-boundary, plan-or-record-applied, applied-external-enforcement-evidence, active-enforcement-record, merge-blocker-record, branch-protection-before-after, workflow-or-check-run-evidence, owner-approval, rollback-evidence, no-tool-github-api-mutation, no-tool-branch-protection-mutation, no-tool-workflow-mutation, no-tool-ci-upload, no-live-ingestion, no-durable-write, no-nendb-write
  emitted by: causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate required status check enforcement policy
  governance requirements: source enforcement-readiness checks, plan mode tests, record-applied external evidence tests, branch-protection before-after evidence, workflow or check-run evidence, active enforcement record tests, merge blocker record tests, denied mutation-by-tool inference tests, next-branch enforcement policy handoff
- zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, required-status-check-enforcement-policy, interpretation-policy, active-enforcement-interpretation, merge-blocker-interpretation, planned-or-applied-source, no-tool-github-api-mutation, no-tool-branch-protection-mutation, no-tool-workflow-mutation, no-tool-check-run-creation, no-tool-ci-upload, no-live-ingestion, no-durable-write, no-nendb-write
  emitted by: causal-production-telemetry-ci-gate-required-status-check-enforcement-policy
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate required status check enforcement evaluator
  governance requirements: source enforcement application-boundary checks, planned source interpretation tests, applied active-enforcement interpretation tests, merge-blocker evidence interpretation tests, denied mutation-by-tool inference tests, policy verification checks, next-branch enforcement evaluator handoff
- zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, required-status-check-enforcement-evaluator, bounded-explicit-evidence, active-enforcement-evaluation, merge-blocker-evaluation, advisory-findings, no-tool-github-api-mutation, no-tool-branch-protection-mutation, no-tool-workflow-mutation, no-tool-check-run-creation, no-tool-ci-upload, no-live-ingestion, no-durable-write, no-nendb-write
  emitted by: causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate required status check enforcement report
  governance requirements: source enforcement policy checks, explicit bounded evidence classifier, active enforcement signal evaluation, merge blocker signal evaluation, denied mutation evidence tests, denied production evidence tests, next-branch enforcement report handoff
- zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, required-status-check-enforcement-report, reviewer-guidance, local-artifact-only, blocked-finding-preserving, no-tool-github-api-mutation, no-tool-branch-protection-mutation, no-tool-workflow-mutation, no-tool-check-run-creation, no-tool-ci-upload, no-github-step-summary-write, no-pr-comment, no-live-ingestion, no-durable-write, no-nendb-write
  emitted by: causal-production-telemetry-ci-gate-required-status-check-enforcement-report
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate required status check enforcement report application boundary
  governance requirements: source enforcement evaluator checks, blocked finding preservation tests, publication boundary tests, denied authority tests, next-branch report application-boundary handoff
- zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, report-application-boundary, plan-or-record-applied, before-after-verification, local-artifact-only, required-status-check-evidence, branch-protection-evidence, no-tool-github-api-mutation, no-tool-branch-protection-mutation, no-tool-workflow-mutation, no-tool-check-run-creation, no-tool-ci-upload, no-tool-github-step-summary-write, no-tool-pr-comment, no-live-ingestion, no-durable-write, no-nendb-write
  emitted by: causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary
  consumed by: agents, reviewers, production-hardening backlog, future production telemetry CI gate required status check enforcement report policy
  governance requirements: source report checks, plan mode tests, record-applied evidence tests, after-report safety tests, denied authority tests, next-branch report policy handoff
- zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-policy.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, record-only, required-status-check-enforcement-report-policy, interpretation-policy, planned-or-applied-source, published-report-interpretation, local-artifact-only, no-tool-github-api-mutation, no-tool-branch-protection-mutation, no-tool-workflow-mutation, no-tool-check-run-creation, no-tool-ci-upload, no-tool-github-step-summary-write, no-tool-pr-comment, no-live-ingestion, no-durable-write, no-nendb-write
  emitted by: causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy
  consumed by: agents, reviewers, production-hardening backlog, future production hardening backlog refresh
  governance requirements: source report application-boundary checks, planned source interpretation tests, applied source interpretation tests, denied publication inference tests, policy verification checks, next-branch backlog refresh handoff
- zigeffect.causal.production-hardening-backlog-refresh.v1
  version: 1
  category: production-hardening
  status: current
  compatibility: strict-v1, read-only, nendb-only, local-artifact-only, no-cockroach, no-live-telemetry, no-durable-write, no-nendb-write, no-mutation-authority
  emitted by: causal-production-hardening-backlog-refresh
  consumed by: agents, reviewers, future NenDB durable history hardening
  governance requirements: source backlog checks, terminal delivered item check, candidate selection checks, denied inference checks, next branch handoff
- zigeffect.causal.test-matrix.v1
  version: 1
  category: test-coverage
  status: current
  compatibility: record-only
  emitted by: causal-test-matrix
  consumed by: agents, docs
  governance requirements: matrix tests, scenario coverage docs, artifact manifest entry
- zigeffect.causal.remediation-audit.v1
  version: 1
  category: governance
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-remediation-audit
  consumed by: causal-remediation-decision, causal-patch-proposal, causal-audit-chain
  governance requirements: schema validation tests, guardrail tests, docs
- zigeffect.causal.remediation-decision.v1
  version: 1
  category: governance
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-remediation-decision
  consumed by: causal-patch-proposal, causal-audit-chain
  governance requirements: schema validation tests, decision gate tests, docs
- zigeffect.causal.patch-proposal.v1
  version: 1
  category: governance
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-patch-proposal
  consumed by: causal-audit-chain, agents
  governance requirements: proposal guardrail tests, schema validation tests, docs
- zigeffect.causal.audit-chain.v1
  version: 1
  category: governance
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-audit-chain
  consumed by: causal-scenario-proposal, causal-policy-decision, agents
  governance requirements: chain validation tests, before-after evidence tests, docs
- zigeffect.causal.scenario-proposal.v1
  version: 1
  category: registry
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-scenario-proposal
  consumed by: causal-scenario-registry-patch, causal-policy-decision, agents
  governance requirements: scenario proposal tests, registry guardrail tests, docs
- zigeffect.causal.registry-patch.v1
  version: 1
  category: registry
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-scenario-registry-patch
  consumed by: causal-policy-decision, causal-registry-application-readiness
  governance requirements: patch validation tests, policy gate tests, docs
- zigeffect.causal.registry-application-readiness.v1
  version: 1
  category: registry
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-registry-application-readiness
  consumed by: causal-registry-apply
  governance requirements: readiness gate tests, policy citation tests, docs
- zigeffect.causal.registry-application.v1
  version: 1
  category: registry
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-registry-apply
  consumed by: causal-workbench, agents
  governance requirements: applied-state tests, before-after verification tests, docs
- zigeffect.causal.policy-decision.v1
  version: 1
  category: governance
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-policy-decision
  consumed by: registry gates, agents, causal-workbench
  governance requirements: policy gate tests, scenario ownership tests, docs
- zigeffect.causal.snapshot-manifest.v1
  version: 1
  category: snapshot-replay
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-snapshot
  consumed by: causal-snapshot compare, causal-snapshot audit-chain-compare, causal-snapshot replay-feasibility, agents
  governance requirements: snapshot tests, manifest validation tests, docs
- zigeffect.causal.snapshot-compare.v1
  version: 1
  category: snapshot-replay
  status: current
  compatibility: record-only
  emitted by: causal-snapshot
  consumed by: agents, causal-workbench
  governance requirements: compare tests, before-after query tests, docs
- zigeffect.causal.audit-chain-snapshot-compare.v1
  version: 1
  category: snapshot-replay
  status: current
  compatibility: strict-v1, record-only, local-artifact-only, no-mutation-authority
  emitted by: causal-snapshot audit-chain-compare
  consumed by: agents, reviewers, future workbench governance views, future app-facing production fixtures
  governance requirements: audit-chain compare tests, applied-boundary tests, schema governance docs, backlog handoff
- zigeffect.causal.replay-feasibility.v1
  version: 1
  category: snapshot-replay
  status: current
  compatibility: record-only
  emitted by: causal-snapshot
  consumed by: agents, reviewers
  governance requirements: feasibility tests, non-goal tests, docs
- zigeffect.causal.deterministic-replay.v1
  version: 1
  category: snapshot-replay
  status: current
  compatibility: record-only
  emitted by: causal-snapshot
  consumed by: agents, reviewers
  governance requirements: registered scenario replay tests, determinism tests, docs
- zigeffect.causal.scenario-fork-proposal.v1
  version: 1
  category: snapshot-replay
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-snapshot
  consumed by: reviewers, agents
  governance requirements: proposal tests, non-mutating guardrail tests, docs
- zigeffect.causal.app-remediation-audit.v1
  version: 1
  category: app-remediation
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-app-remediation-audit
  consumed by: causal-app-policy-decision
  governance requirements: schema validation tests, app guardrail tests, docs, workbench mapping
- zigeffect.causal.app-policy-decision.v1
  version: 1
  category: app-remediation
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-app-policy-decision
  consumed by: causal-app-human-review, causal-app-patch-proposal
  governance requirements: policy gate tests, human-review gate tests, docs, workbench mapping
- zigeffect.causal.app-human-review.v1
  version: 1
  category: app-remediation
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-app-human-review
  consumed by: causal-app-patch-proposal, causal-app-application-readiness
  governance requirements: review evidence tests, approval gate tests, docs, workbench mapping
- zigeffect.causal.app-patch-proposal.v1
  version: 1
  category: app-remediation
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-app-patch-proposal
  consumed by: causal-app-application-readiness
  governance requirements: proposal tests, mutation-authority tests, docs, workbench mapping
- zigeffect.causal.app-application-readiness.v1
  version: 1
  category: app-remediation
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-app-application-readiness
  consumed by: causal-app-apply
  governance requirements: readiness tests, verification command tests, docs, workbench mapping
- zigeffect.causal.app-application.v1
  version: 1
  category: app-remediation
  status: current
  compatibility: strict-v1, record-only
  emitted by: causal-app-apply
  consumed by: causal-workbench, agents
  governance requirements: schema validation tests, applied-state tests, docs, workbench mapping
