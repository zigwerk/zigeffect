import { expect, test } from "bun:test";
import {
  type CausalEvent,
  causePathForEvent,
  deriveAppFacingPreviewModel,
  deriveAppRemediationModel,
  deriveGovernanceModel,
  deriveLiveDashboardModel,
  deriveProductionTelemetryPreviewModel,
  deriveVisualGraphModel,
  deriveWorkbenchModel,
  deriveGraphModel,
  deriveRemediationChainModel,
  filterEvents,
  parseArtifactJson,
  queryCommandsForEvent,
} from "./causalArtifact";

const sampleArtifact = JSON.stringify({
  schema: "zigeffect.causal.v1",
  schema_version: 1,
  event_taxonomy_version: 1,
  events: [
    {
      id: 5,
      kind: "fiber_forked",
      run_id: 1,
      parent_id: 2,
      fiber_id: 42,
      scope_id: 1,
      label: "dogfood child fiber",
      type_name: "",
      status: "pending",
      redacted_detail: "",
    },
    {
      id: 1,
      kind: "run_started",
      run_id: 1,
      parent_id: null,
      fiber_id: null,
      scope_id: null,
      label: "zigeffect dogfood",
      type_name: "DogfoodHarness",
      status: "",
      redacted_detail: "",
    },
    {
      id: 3,
      kind: "service_required",
      run_id: 1,
      parent_id: 2,
      fiber_id: null,
      scope_id: null,
      label: "Config",
      type_name: "Config",
      status: "missing",
      redacted_detail: "missing provider",
    },
    {
      id: 2,
      kind: "scope_opened",
      run_id: 1,
      parent_id: 1,
      fiber_id: null,
      scope_id: 1,
      label: "dogfood scope",
      type_name: "",
      status: "opened",
      redacted_detail: "",
    },
    {
      id: 4,
      kind: "resource_acquired",
      run_id: 1,
      parent_id: 2,
      fiber_id: null,
      scope_id: 1,
      label: "dogfood database",
      type_name: "DogfoodDatabaseConnection",
      status: "success",
      redacted_detail: "left open",
    },
    {
      id: 6,
      kind: "scope_closed",
      run_id: 1,
      parent_id: 2,
      fiber_id: null,
      scope_id: 1,
      label: "dogfood scope",
      type_name: "",
      status: "closed",
      redacted_detail: "",
    },
    {
      id: 7,
      kind: "schedule_decision",
      run_id: 1,
      parent_id: 1,
      fiber_id: null,
      scope_id: null,
      label: "dogfood retry policy",
      type_name: "Schedule.exponential",
      status: "exhausted",
      redacted_detail: "retry budget exhausted",
    },
    {
      id: 8,
      kind: "resource_finalized",
      run_id: 1,
      parent_id: 2,
      fiber_id: null,
      scope_id: 2,
      label: "cleanup finalizer",
      type_name: "DogfoodFinalizer",
      status: "failure",
      redacted_detail: "CloseFailed",
    },
    {
      id: 9,
      kind: "assertion_recorded",
      run_id: 1,
      parent_id: 1,
      fiber_id: null,
      scope_id: null,
      label: "package tests",
      type_name: "assertion",
      status: "failure",
      redacted_detail: "expected success",
    },
  ],
});

const sampleAuditChain = {
  schema: "zigeffect.causal.audit-chain.v1",
  schema_version: 1,
  mode: "local",
  target: "package-tests",
  assessment: "unchanged",
  source: {
    session: ".zig-cache/causal-artifacts/zigeffect-causal-dev-session-package-tests.json",
    audit: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-audit.json",
    decision: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-decision.json",
    proposal: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-patch-proposal.json",
    before: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-before.json",
    after: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-after.json",
    compare: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-compare.txt",
  },
  proposal_status: "ready-for-review",
  approval_status: "approved",
  approved: true,
  applied: false,
  finding_delta: 0,
  event_ids: [1, 2, 3, 5],
  disappeared_event_ids: [1],
  persisting_event_ids: [2],
  appeared_event_ids: [3],
  missing_event_ids: [5],
  verification_commands: ["zig build examples", "zig build test --summary none"],
  claim_guardrails: ["Do not claim remediation without verification."],
  proposal_guardrails: ["This proposal does not apply source changes."],
  chain_guardrails: ["Chain comparison is evidence, not authorization to edit source."],
};

const sampleLiveStream = {
  schema: "zigeffect.causal.live-dashboard-stream.v1",
  schema_version: 1,
  mode: "local-fixture",
  target: "package-tests",
  mutation_authority: "none",
  source: {
    snapshot: ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
    alert_preview: ".zig-cache/causal-artifacts/alerting-integrations.json",
    compare: ".zig-cache/causal-artifacts/compare.txt",
  },
  stream: {
    window_policy: "drop-oldest",
    max_frames: 4,
    frame_count: 5,
    truncated: true,
    redaction: "artifact-redacted",
  },
  frames: [
    {
      sequence: 1,
      event_id: 1,
      event_kind: "run_started",
      status: "ok",
      label: "run",
      lane: "run:1",
      parent_id: null,
      dashboard_priority: "normal",
    },
    {
      sequence: 2,
      event_id: 2,
      event_kind: "scope_opened",
      status: "ok",
      label: "scope",
      lane: "scope:1",
      parent_id: 1,
      dashboard_priority: "normal",
    },
    {
      sequence: 3,
      event_id: 3,
      event_kind: "service_required",
      status: "missing",
      label: "Config",
      lane: "run:1",
      parent_id: 2,
      finding_kind: "service_requirement_without_provider",
      dashboard_priority: "critical",
    },
    {
      sequence: 4,
      event_id: 4,
      event_kind: "resource_acquired",
      status: "success",
      label: "db",
      lane: "resource:db",
      parent_id: 2,
      dashboard_priority: "watch",
    },
    {
      sequence: 5,
      event_id: 5,
      event_kind: "fiber_forked",
      status: "pending",
      label: "child",
      lane: "fiber:42",
      parent_id: 2,
      finding_kind: "fiber_pending_after_scope_close",
      dashboard_priority: "watch",
    },
  ],
  layouts: ["dagre", "force", "radial"],
  guardrails: ["Read-only dashboard evidence only.", "Mutation authority remains none."],
};

const sampleAppAudit = {
  schema: "zigeffect.causal.app-remediation-audit.v1",
  schema_version: 1,
  mode: "local",
  target: "yachdee-platform",
  source: {
    app_artifact: ".zig-cache/causal-artifacts/app.json",
    advice: ".zig-cache/causal-artifacts/app-advice.txt",
  },
  approval_status: "pending",
  applied: false,
  mutation_authority: "none",
  incident_count: 2,
  incidents: [
    {
      action: "fix-app-config",
      event_id: 2,
      event_kind: "assertion_recorded",
      label: "YACHDEE_ENV",
      subsystem: "app_config",
      fix_category: "config-or-secret-binding",
      policy_gate: "config-only",
      query_commands: ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"],
    },
    {
      action: "wire-app-requirement",
      event_id: 3,
      event_kind: "assertion_recorded",
      label: "HealthService",
      subsystem: "app_service_layer",
      fix_category: "service-provider-or-layer",
      policy_gate: "source-only",
      query_commands: ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 3"],
    },
  ],
  policy_gates: ["config-only", "source-only"],
  verification_commands: ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"],
  claim_guardrails: ["Do not claim an app fix without rerunning the app request/job scenario."],
};

const sampleAppPolicy = {
  schema: "zigeffect.causal.app-policy-decision.v1",
  schema_version: 1,
  mode: "local",
  target: "yachdee-platform",
  decision: "approve",
  approval_status: "approve",
  mutation_authority: "none",
  applied: false,
  source: {
    app_remediation_audit: ".zig-cache/causal-artifacts/app-audit.json",
    app_artifact: ".zig-cache/causal-artifacts/app.json",
  },
  policy_gates: ["config-only", "source-only"],
  gate_results: [
    {
      gate: "config-only",
      status: "allow-proposal",
      detail: "configuration proposal may be drafted without exposing secrets",
    },
    {
      gate: "source-only",
      status: "allow-proposal",
      detail: "source-only app patch proposal may be drafted",
    },
  ],
  event_ids: [2, 3],
  required_verification_commands: ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"],
  guardrails: ["Policy approval is advisory and does not apply app source, config, migrations, operations, or rollback actions."],
};

const sampleAppProposal = {
  schema: "zigeffect.causal.app-patch-proposal.v1",
  schema_version: 1,
  mode: "local",
  target: "yachdee-platform",
  proposal_status: "draft",
  approval_status: "pending",
  approved: false,
  applied: false,
  mutation_authority: "none",
  summary: "Wire HealthService and document config binding",
  change: "Add provider layer and document YACHDEE_ENV.",
  source: {
    policy: ".zig-cache/causal-artifacts/app-policy.json",
    app_remediation_audit: ".zig-cache/causal-artifacts/app-audit.json",
    app_artifact: ".zig-cache/causal-artifacts/app.json",
  },
  policy_gates: ["config-only", "source-only"],
  citations: {
    source_files: ["apps/platform/src/worker.ts"],
    config_keys: ["YACHDEE_ENV"],
    migration_files: [],
    runbooks: ["docs/runbooks/yachdee-config.md"],
    rollback_plans: ["docs/runbooks/yachdee-rollback.md"],
  },
  event_ids: [2, 3],
  required_verification_commands: ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"],
  claim_guardrails: ["Do not claim an app fix without rerunning the app request/job scenario."],
  proposal_guardrails: ["Config citations name keys or bindings only; never include secret values."],
};

const sampleAppReview = {
  schema: "zigeffect.causal.app-human-review.v1",
  schema_version: 1,
  mode: "local",
  target: "yachdee-platform",
  review_status: "approved",
  approval_status: "approved",
  approved: true,
  applied: false,
  mutation_authority: "none",
  reviewed_by: "local-reviewer",
  reason: "migration and rollback evidence reviewed",
  source: {
    policy: ".zig-cache/causal-artifacts/app-policy.json",
    app_remediation_audit: ".zig-cache/causal-artifacts/app-audit.json",
    app_artifact: ".zig-cache/causal-artifacts/app.json",
  },
  policy_gates: ["migration-required", "rollback-required"],
  citations: {
    source_files: [],
    config_keys: [],
    migration_files: ["packages/app/migrations/001.sql"],
    runbooks: ["docs/runbooks/migration.md"],
    rollback_plans: ["docs/runbooks/rollback.md"],
  },
  event_ids: [4],
  required_verification_commands: ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 4"],
  reviewed_verification_commands: ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 4"],
  review_guardrails: ["Human review approves proposal drafting only; it does not apply app source, config, migrations, operations, rollback plans, or deployment state."],
};

const sampleAppReadiness = {
  schema: "zigeffect.causal.app-application-readiness.v1",
  schema_version: 1,
  mode: "local",
  target: "yachdee-platform",
  decision: "approve",
  readiness_status: "ready",
  ready_for_application: true,
  reviewed_by: "local-reviewer",
  policy: "manual-app-application-readiness",
  reason: "reviewed proposal citations and verification evidence",
  applied: false,
  mutation_authority: "none",
  summary: "Wire HealthService and document config binding",
  change: "Add provider layer and document YACHDEE_ENV.",
  source: {
    proposal: ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
    policy: ".zig-cache/causal-artifacts/yachdee-platform-app-policy-decision.json",
    app_remediation_audit: ".zig-cache/causal-artifacts/yachdee-platform-app-remediation-audit.json",
    app_artifact: ".zig-cache/causal-artifacts/app.json",
    human_review: ".zig-cache/causal-artifacts/yachdee-platform-app-human-review.json",
  },
  policy_gates: ["source-only", "config-only"],
  citations: {
    source_files: ["apps/platform/src/worker.ts"],
    config_keys: ["YACHDEE_API_BASE_URL"],
    migration_files: [],
    runbooks: [],
    rollback_plans: [],
  },
  event_ids: [2],
  checks: [{ name: "proposal-state", status: "pass", detail: "proposal is draft" }],
  required_verification_commands: ["zig build causal-query -- --file app.json cause 2"],
  verified_commands: ["zig build causal-query -- --file app.json cause 2"],
  application_steps: ["Apply the reviewed change outside this readiness command."],
  readiness_guardrails: ["Readiness does not edit app source."],
};

const sampleAppApplication = {
  schema: "zigeffect.causal.app-application.v1",
  schema_version: 1,
  source_readiness: ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
  source_proposal: ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
  mode: "record-applied",
  application_status: "applied",
  applied: true,
  mutation_authority: "record-only",
  applied_by: "local-reviewer",
  policy: "manual-app-application",
  reason: "source and config change landed",
  readiness_status: "ready",
  ready_for_application: true,
  target: "yachdee-platform",
  summary: "Wire HealthService and document config binding",
  change: "Add provider layer and document YACHDEE_ENV.",
  source: {
    readiness: ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
    proposal: ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
    policy: ".zig-cache/causal-artifacts/yachdee-platform-app-policy-decision.json",
    app_remediation_audit: ".zig-cache/causal-artifacts/yachdee-platform-app-remediation-audit.json",
    app_artifact: ".zig-cache/causal-artifacts/app.json",
    human_review: ".zig-cache/causal-artifacts/yachdee-platform-app-human-review.json",
  },
  policy_gates: ["source-only", "config-only"],
  citations: {
    source_files: ["apps/platform/src/worker.ts"],
    config_keys: ["YACHDEE_API_BASE_URL"],
    migration_files: [],
    runbooks: [],
    rollback_plans: [],
  },
  event_ids: [2],
  checks: [
    { name: "readiness-ready", status: "pass", detail: "readiness is ready for app application" },
    { name: "change-evidence-present", status: "pass", detail: "caller recorded evidence for every policy-gate change category" },
  ],
  required_verification_commands: ["zig build causal-query -- --file app.json cause 2"],
  verified_commands: ["zig build causal-query -- --file app.json cause 2"],
  change_evidence: {
    source_changes: ["apps/platform/src/worker.ts"],
    config_changes: ["YACHDEE_API_BASE_URL"],
    migration_changes: [],
    operation_changes: [],
    rollback_changes: [],
  },
  before_evidence: [".zig-cache/causal-artifacts/yachdee-platform-before-app.json"],
  after_evidence: [".zig-cache/causal-artifacts/yachdee-platform-after-app.json"],
  application_steps: ["Keep this application artifact with the reviewed change evidence."],
  guardrails: ["This command records application state; it does not silently mutate source or external systems."],
};

const sampleProductionTelemetryRetention = {
  schema: "zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1",
  schema_version: 1,
  source_local_pipeline: ".zig-cache/causal-artifacts/local-pipeline.json",
  source_boundary: ".zig-cache/causal-artifacts/boundary.json",
  source_proposal: ".zig-cache/causal-artifacts/proposal.json",
  source_readiness: ".zig-cache/causal-artifacts/readiness.json",
  source_fixtures: ".zig-cache/causal-artifacts/fixtures.json",
  decision: "approve",
  retention_fixture_status: "ready",
  ready_for_next_branch: true,
  recommendation: "start-production-telemetry-workbench-readonly-preview",
  next_branch_if_ready: "codex/zigeffect-causal-production-telemetry-workbench-readonly-preview",
  applied: false,
  mutation_authority: "none",
  production_telemetry_ingestion: false,
  live_exporter_enabled: false,
  network_send_enabled: false,
  collector_endpoint_configured: false,
  otlp_serialization_enabled: false,
  runtime_pipeline_enabled: false,
  durable_write_enabled: false,
  nendb_write_enabled: false,
  ci_gate_enabled: false,
  checks: [
    { name: "local-pipeline-schema", status: "pass", detail: "source local pipeline schema is supported" },
    { name: "no-nendb-write", status: "pass", detail: "NenDB writes remain disabled" },
  ],
  nendb_mapping_fixtures: [
    {
      id: "nendb-runtime-event-node-fixture",
      source_envelope: "runtime-span-normalized-envelope",
      target_schema: "zigeffect.causal.nendb_node.v1",
      label: "causal.telemetry.runtime_span",
      retained_fields: ["event_id_ref", "trace_id_ref", "span_id_ref"],
      blocked_fields: ["raw_payload", "credentials"],
    },
  ],
  retention_validation_checks: ["nendb-write-disabled", "durable-write-disabled"],
  implementation_gates: ["workbench read-only preview must be reviewed before UI work"],
  non_goals: ["Live local or production pipeline execution", "React or alternate renderer work"],
  blocked_claims: ["nendb-write-enabled", "mutation-authority-granted"],
  required_verification_commands: [
    "zig build causal-production-telemetry-local-pipeline-fixtures",
    "zig build examples",
  ],
  verified_commands: [
    "zig build causal-production-telemetry-local-pipeline-fixtures",
    "zig build examples",
  ],
};

const sampleAppFacingSolidWebuiPreview = {
  schema: "zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1",
  schema_version: 1,
  source_schema: "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1",
  tool: "causal-app-facing-production-integration-solid-webui-readonly-preview",
  source_bridge: ".zig-cache/causal-artifacts/source-audit-remediation-bridge.json",
  source_bridge_status: "ready",
  status: "ready",
  solid_webui_readonly_preview_status: "ready",
  decision: "approve",
  reason: "ready app-facing audit remediation bridge reviewed for SolidJS read-only preview",
  ready_for_next_branch: true,
  applied: false,
  mutation_authority: "none",
  read_only_preview: true,
  solid_webui_enabled: true,
  solid_webui_renderer: "solidjs",
  webui_bridge: "webui-dev/zig-webui",
  hosted_live_dashboard_enabled: false,
  app_mutation_controls_enabled: false,
  react_renderer_enabled: false,
  alternate_renderer_enabled: false,
  nendb_write_enabled: false,
  nendb_adapter_execution_enabled: false,
  durable_write_enabled: false,
  deployment_mutation_enabled: false,
  app_runtime_integration_enabled: false,
  agent_query_live_projection_enabled: false,
  preview_panels: ["status", "source-artifacts", "authority-boundary", "solid-webui-preview-state", "verification"],
  app_preview_sections: [
    {
      id: "solid-webui-preview",
      title: "SolidJS WebUI read-only preview",
      evidence_refs: ["solid-webui-review-preview-bridge", "webui_sample_ref", "solid_view_ref"],
      blocked_authority: ["live-dashboard-host", "app-mutation-button", "react-renderer", "alternate-renderer"],
    },
  ],
  bridge_records: [
    {
      id: "solid-webui-review-preview-bridge",
      status: "read-only-preview-next",
      source_ref: "nendb-solid-webui-preview-node-handoff-fixture",
      target_ref: "review_state_ref",
      bridge_kind: "solid-webui-preview",
      retained_refs: ["webui_sample_ref", "solid_view_ref"],
      blocked_claims: ["react-renderer", "alternate-renderer"],
    },
  ],
  checks: [
    { name: "solid-webui-readonly", status: "pass", detail: "preview is read-only SolidJS inside webui-dev/zig-webui" },
    { name: "react-renderer-disabled", status: "pass", detail: "React renderer is not enabled" },
  ],
  validation_checks: ["solid-webui-readonly", "solidjs-renderer-only", "cockroach-scope-rejected"],
  blocked_claims: ["applied=true", "production-health", "mutation-proof", "cockroach-adapter-work"],
  non_goals: ["hosted live dashboard", "app mutation controls", "NenDB production writes"],
  required_verification_commands: ["bun run zigeffect:workbench:typecheck", "bun run zigeffect:workbench:test"],
  verified_commands: ["bun run zigeffect:workbench:typecheck", "bun run zigeffect:workbench:test"],
  recommendation: "start-app-facing-production-integration-ci-advisory-remediation-report",
  next_branch_if_ready: "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report",
};

test("parseArtifactJson parses causal artifacts", () => {
  const parsed = parseArtifactJson(sampleArtifact);

  expect(parsed).toHaveProperty("events");
});

test("deriveWorkbenchModel normalizes metadata and sorts events by id", () => {
  const model = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
    artifactPath: ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
  });

  expect(model.schema).toBe("zigeffect.causal.v1");
  expect(model.schemaVersion).toBe("1");
  expect(model.taxonomyVersion).toBe("1");
  expect(model.events.map((event) => event.idText)).toEqual([
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
  ]);
  expect(model.kinds).toContain("service_required");
  expect(model.statuses).toContain("missing");
});

test("deriveWorkbenchModel computes runtime-aligned findings", () => {
  const model = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
    artifactPath: "artifact.json",
  });

  expect(model.findings.map((finding) => finding.kind)).toEqual([
    "service_requirement_without_provider",
    "resource_acquired_without_finalization",
    "fiber_pending_after_scope_close",
    "retry_budget_exhausted",
    "finalizer_failure",
    "assertion_failure",
  ]);
  expect(model.findings[0]?.eventId).toBe("3");
});

test("filterEvents supports text kind and status filters", () => {
  const model = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
    artifactPath: "artifact.json",
  });

  expect(filterEvents(model.events, { text: "Config" }).map((event) => event.idText)).toEqual(["3"]);
  expect(filterEvents(model.events, { kind: "resource_acquired" }).map((event) => event.idText)).toEqual(["4"]);
  expect(filterEvents(model.events, { status: "failure" }).map((event) => event.idText)).toEqual(["8", "9"]);
});

test("deriveLiveDashboardModel normalizes bounded stream artifacts", () => {
  const dashboard = deriveLiveDashboardModel(sampleLiveStream, { artifactPath: "live.json" });

  expect(dashboard?.schema).toBe("zigeffect.causal.live-dashboard-stream.v1");
  expect(dashboard?.target).toBe("package-tests");
  expect(dashboard?.mode).toBe("local-fixture");
  expect(dashboard?.mutationAuthority).toBe("none");
  expect(dashboard?.stream.windowPolicy).toBe("drop-oldest");
  expect(dashboard?.stream.maxFrames).toBe(4);
  expect(dashboard?.stream.frameCount).toBe(5);
  expect(dashboard?.stream.truncated).toBe(true);
  expect(dashboard?.frames.map((frame) => frame.eventId)).toEqual(["1", "2", "3", "4", "5"]);
  expect(dashboard?.priorityCounts.critical).toBe(1);
  expect(dashboard?.priorityCounts.watch).toBe(2);
  expect(dashboard?.sources.find((source) => source.kind === "snapshot")?.workbenchCommand).toBe(
    "zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
  );
  expect(dashboard?.sources.find((source) => source.kind === "compare")?.workbenchCommand).toBeNull();
  expect(dashboard?.layouts).toEqual(["dagre", "force", "radial"]);
  expect(dashboard?.guardrails).toContain("Mutation authority remains none.");
});

test("deriveLiveDashboardModel treats normal causal artifacts as static streams", () => {
  const raw = parseArtifactJson(sampleArtifact);
  const workbench = deriveWorkbenchModel(raw, { artifactPath: "sample-artifact.json" });
  const dashboard = deriveLiveDashboardModel(raw, { artifactPath: "sample-artifact.json" }, workbench);

  expect(dashboard?.schema).toBe("zigeffect.causal.v1");
  expect(dashboard?.mode).toBe("static-snapshot");
  expect(dashboard?.frames.length).toBe(workbench.events.length);
  expect(dashboard?.stream.truncated).toBe(false);
  expect(dashboard?.priorityCounts.critical).toBeGreaterThan(0);
});

test("queryCommandsForEvent generates copyable causal-query commands", () => {
  const model = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
    artifactPath: ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
  });
  const event = model.events.find((candidate) => candidate.idText === "5");

  expect(event).toBeDefined();
  expect(queryCommandsForEvent(event!, model.artifactPath)).toEqual([
    {
      label: "Cause",
      command:
        "zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json cause 5",
    },
    {
      label: "Lineage",
      command:
        "zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json lineage 5",
    },
    {
      label: "Resources",
      command:
        "zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json resources 1",
    },
    {
      label: "Pending fibers",
      command:
        "zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json fibers pending",
    },
    {
      label: "Requirements",
      command:
        "zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json requirements 1",
    },
  ]);
});

test("deriveWorkbenchModel tolerates partial artifacts", () => {
  const model = deriveWorkbenchModel(
    {
      events: [
        {
          id: "alpha",
          kind: "effect_suspended",
          label: "future event",
        },
      ],
    },
    { artifactPath: "future.json" },
  );

  expect(model.schema).toBe("unknown");
  expect(model.events[0]?.idText).toBe("alpha");
  expect(model.events[0]?.status).toBe("unknown");
  expect(model.warnings).toContain("artifact schema is missing");
});

test("deriveGraphModel summarizes roots parent edges and runtime lanes", () => {
  const model = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
    artifactPath: "artifact.json",
  });
  const graph = deriveGraphModel(model.events, model.findings);

  expect(graph.roots.map((event) => event.idText)).toEqual(["1"]);
  expect(graph.parentEdges.length).toBe(8);
  expect(graph.parentEdges.map((edge) => `${edge.from}->${edge.to}`)).toContain("2->5");
  expect(causePathForEvent(model.events, "5").map((event) => event.idText)).toEqual(["1", "2", "5"]);
  expect(graph.lanes.some((lane) => lane.kind === "resource" && lane.status === "warning")).toBe(true);
  expect(graph.lanes.some((lane) => lane.kind === "retry" && lane.status === "warning")).toBe(true);
  expect(graph.unhealthyLanes.length).toBeGreaterThan(0);
});

test("deriveVisualGraphModel maps causal graph data for read-only layouts", () => {
  const workbench = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
    artifactPath: "sample-artifact.json",
  });
  const graph = deriveGraphModel(workbench.events, workbench.findings);
  const visual = deriveVisualGraphModel(workbench, graph, "force");

  expect(visual.layoutMode).toBe("force");
  expect(visual.nodes.length).toBe(workbench.events.length);
  expect(visual.edges.length).toBe(graph.parentEdges.length);
  expect(visual.nodes.find((node) => node.id === "3")?.tone).toBe("warning");
  expect(visual.nodes.find((node) => node.id === "8")?.tone).toBe("failure");
  expect(visual.adapter.solid).toBe("@dschz/solid-g6");
  expect(visual.adapter.engine).toBe("@antv/g6");
  expect(visual.adapter.directEngineApi).toBe("not-required");
});

test("deriveVisualGraphModel defaults to cause perspective with parent edges", () => {
  const workbench = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
    artifactPath: "sample-artifact.json",
  });
  const graph = deriveGraphModel(workbench.events, workbench.findings);
  const visual = deriveVisualGraphModel(workbench, graph, {
    layoutMode: "dagre",
    perspective: "cause",
    selectedEventId: "8",
  });

  expect(visual.perspective).toBe("cause");
  expect(visual.nodes.some((node) => node.id === "event:8" && node.priority === "critical")).toBe(true);
  expect(visual.edges.some((edge) => edge.kind === "parent" && edge.source === "event:2" && edge.target === "event:8")).toBe(true);
  expect(visual.legend.some((entry) => entry.label === "Failure")).toBe(true);
});

test("deriveVisualGraphModel creates topology group nodes for runtime lanes", () => {
  const workbench = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
    artifactPath: "sample-artifact.json",
  });
  const graph = deriveGraphModel(workbench.events, workbench.findings);
  const visual = deriveVisualGraphModel(workbench, graph, {
    layoutMode: "force",
    perspective: "topology",
  });

  expect(visual.perspective).toBe("topology");
  expect(visual.nodes.some((node) => node.group === "run" && node.id === "run:1")).toBe(true);
  expect(visual.nodes.some((node) => node.group === "scope" && node.id === "scope:1")).toBe(true);
  expect(visual.edges.some((edge) => edge.kind === "owns" && edge.source === "scope:1" && edge.target === "event:2")).toBe(true);
});

test("deriveVisualGraphModel emphasizes ownership and finalizer failures", () => {
  const workbench = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
    artifactPath: "sample-artifact.json",
  });
  const graph = deriveGraphModel(workbench.events, workbench.findings);
  const visual = deriveVisualGraphModel(workbench, graph, {
    layoutMode: "radial",
    perspective: "ownership",
  });

  expect(visual.nodes.some((node) => node.group === "resource" && node.tone === "failure")).toBe(true);
  expect(visual.edges.some((edge) => edge.kind === "finalizes" && edge.target === "event:8")).toBe(true);
  expect(visual.warnings.every((warning) => !warning.includes("mutation"))).toBe(true);
});

test("deriveVisualGraphModel creates lineage ref nodes from app semantic refs", () => {
  const raw = {
    schema: "zigeffect.causal.v1",
    schema_version: 1,
    event_taxonomy_version: 1,
    events: [
      {
        id: 1,
        kind: "span_recorded",
        label: "load project",
        status: "success",
        artifact_id: "artifact:response:project",
        domain_entity_ref: "project:123",
        data_subject_ref: "tenant:acme",
        schema_ref: "Project.v1",
      },
  ],
};

  const workbench = deriveWorkbenchModel(raw, { artifactPath: "lineage.json" });
  const graph = deriveGraphModel(workbench.events, workbench.findings);
  const visual = deriveVisualGraphModel(workbench, graph, {
    layoutMode: "radial",
    perspective: "lineage",
  });

  expect(visual.nodes.some((node) => node.group === "data" && node.id === "data-subject:tenant:acme")).toBe(true);
  expect(visual.nodes.some((node) => node.group === "artifact" && node.id === "artifact:artifact:response:project")).toBe(true);
  expect(visual.edges.some((edge) => edge.kind === "reads" || edge.kind === "emits")).toBe(true);
});

test("deriveVisualGraphModel maps live stream frames when events are absent", () => {
  const workbench = deriveWorkbenchModel(sampleLiveStream, {
    artifactPath: "sample-live-dashboard-stream.json",
  });
  const graph = deriveGraphModel(workbench.events, workbench.findings);
  const dashboard = deriveLiveDashboardModel(sampleLiveStream, {
    artifactPath: "sample-live-dashboard-stream.json",
  }, workbench);
  const visual = deriveVisualGraphModel(workbench, graph, "dagre", dashboard);

  expect(workbench.events.length).toBe(0);
  expect(visual.nodes.length).toBe(5);
  expect(visual.edges.length).toBe(4);
  expect(visual.nodes.find((node) => node.id === "3")?.tone).toBe("failure");
  expect(visual.nodes.find((node) => node.id === "4")?.tone).toBe("warning");
  expect(visual.edges.map((edge) => `${edge.source}->${edge.target}`)).toContain("2->5");
});

test("deriveGraphModel tracks orphaned parent references", () => {
  const graph = deriveGraphModel([
    { ...minimalEvent("1"), parentId: null },
    { ...minimalEvent("2"), parentId: "missing" },
  ], []);

  expect(graph.roots.map((event) => event.idText)).toEqual(["1"]);
  expect(graph.orphans.map((event) => event.idText)).toEqual(["2"]);
  expect(graph.parentEdges).toEqual([]);
  expect(causePathForEvent(graph.orphans, "2").map((event) => event.idText)).toEqual(["2"]);
});

test("causePathForEvent stops at cycles", () => {
  const events = [
    { ...minimalEvent("1"), parentId: "2" },
    { ...minimalEvent("2"), parentId: "1" },
  ];

  expect(causePathForEvent(events, "1").map((event) => event.idText)).toEqual(["2", "1"]);
});

test("deriveRemediationChainModel normalizes audit-chain evidence", () => {
  const chain = deriveRemediationChainModel(sampleAuditChain, {
    artifactPath: ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-audit-chain.json",
  });

  expect(chain).toBeDefined();
  expect(chain?.schema).toBe("zigeffect.causal.audit-chain.v1");
  expect(chain?.target).toBe("package-tests");
  expect(chain?.assessment).toBe("unchanged");
  expect(chain?.approvalStatus).toBe("approved");
  expect(chain?.applied).toBe(false);
  expect(chain?.sourceSteps.map((step) => step.kind)).toEqual([
    "session",
    "audit",
    "decision",
    "proposal",
    "before",
    "after",
    "compare",
  ]);
  expect(chain?.sourceSteps.find((step) => step.kind === "before")?.workbenchCommand).toBe(
    "zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-before.json",
  );
  expect(chain?.classifications.eventIds).toEqual(["1", "2", "3", "5"]);
  expect(chain?.classifications.persisting).toEqual(["2"]);
  expect(chain?.verificationCommands).toEqual(["zig build examples", "zig build test --summary none"]);
  expect(chain?.guardrails).toContain("Chain comparison is evidence, not authorization to edit source.");
  expect(chain?.guardrails.length).toBe(3);
});

test("deriveGovernanceModel detects supported governance artifacts", () => {
  const governance = deriveGovernanceModel(sampleAuditChain, { artifactPath: "chain.json" });

  expect(governance?.kind).toBe("audit-chain");
  expect(governance?.summary).toContain("package-tests");
});

test("deriveGovernanceModel detects app remediation audit artifacts", () => {
  const governance = deriveGovernanceModel({
    schema: "zigeffect.causal.app-remediation-audit.v1",
    schema_version: 1,
    target: "yachdee-platform",
    applied: false,
    mutation_authority: "none",
    incident_count: 2,
  }, { artifactPath: "app-audit.json" });

  expect(governance?.kind).toBe("app-remediation-audit");
  expect(governance?.summary).toContain("2 app incidents");
  expect(governance?.applied).toBe(false);
  expect(governance?.mutationAuthority).toBe("none");
});

test("deriveAppRemediationModel reads app audit incidents and gates", () => {
  const app = deriveAppRemediationModel(sampleAppAudit, { artifactPath: "app-audit.json" });

  expect(app?.kind).toBe("app-remediation-audit");
  expect(app?.target).toBe("yachdee-platform");
  expect(app?.incidents.map((incident) => incident.eventId)).toEqual(["2", "3"]);
  expect(app?.incidents[0]?.policyGate).toBe("config-only");
  expect(app?.policyGates).toEqual(["config-only", "source-only"]);
  expect(app?.verificationCommands).toEqual(["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"]);
  expect(app?.guardrails).toContain("Do not claim an app fix without rerunning the app request/job scenario.");
  expect(app?.sourceSteps.map((step) => step.label)).toEqual(["App artifact", "Advice"]);
  expect(app?.sourceSteps[0]?.workbenchCommand).toBe("zig build causal-workbench -- .zig-cache/causal-artifacts/app.json");
});

test("deriveGovernanceModel attaches app remediation details", () => {
  const governance = deriveGovernanceModel(sampleAppAudit, { artifactPath: "app-audit.json" });

  expect(governance?.app?.incidents.length).toBe(2);
  expect(governance?.app?.sourceSteps[0]?.workbenchCommand).toBe("zig build causal-workbench -- .zig-cache/causal-artifacts/app.json");
});

test("deriveGovernanceModel detects app policy decision artifacts", () => {
  const governance = deriveGovernanceModel({
    schema: "zigeffect.causal.app-policy-decision.v1",
    schema_version: 1,
    target: "yachdee-platform",
    decision: "needs-human-review",
    applied: false,
    mutation_authority: "none",
  }, { artifactPath: "app-policy.json" });

  expect(governance?.kind).toBe("app-policy-decision");
  expect(governance?.summary).toContain("needs-human-review app policy decision");
  expect(governance?.applied).toBe(false);
  expect(governance?.mutationAuthority).toBe("none");
});

test("deriveAppRemediationModel reads app policy gate decisions", () => {
  const app = deriveAppRemediationModel(sampleAppPolicy, { artifactPath: "app-policy.json" });

  expect(app?.kind).toBe("app-policy-decision");
  expect(app?.decision).toBe("approve");
  expect(app?.gateResults.map((gate) => `${gate.gate}:${gate.status}`)).toEqual([
    "config-only:allow-proposal",
    "source-only:allow-proposal",
  ]);
  expect(app?.sourceSteps.map((step) => step.label)).toEqual(["App remediation audit", "App artifact"]);
  expect(app?.verificationCommands).toContain("zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2");
  expect(app?.guardrails).toContain("Policy approval is advisory and does not apply app source, config, migrations, operations, or rollback actions.");
});

test("deriveGovernanceModel detects app patch proposal artifacts", () => {
  const governance = deriveGovernanceModel({
    schema: "zigeffect.causal.app-patch-proposal.v1",
    schema_version: 1,
    target: "yachdee-platform",
    proposal_status: "draft",
    approval_status: "pending",
    applied: false,
    mutation_authority: "none",
  }, { artifactPath: "app-proposal.json" });

  expect(governance?.kind).toBe("app-patch-proposal");
  expect(governance?.summary).toContain("draft app patch proposal");
  expect(governance?.applied).toBe(false);
  expect(governance?.mutationAuthority).toBe("none");
});

test("deriveAppRemediationModel reads app patch proposal citations and guardrails", () => {
  const app = deriveAppRemediationModel(sampleAppProposal, { artifactPath: "app-proposal.json" });

  expect(app?.kind).toBe("app-patch-proposal");
  expect(app?.proposalStatus).toBe("draft");
  expect(app?.citations.map((group) => `${group.label}:${group.values.length}`)).toEqual([
    "Source files:1",
    "Config keys:1",
    "Migration files:0",
    "Runbooks:1",
    "Rollback plans:1",
  ]);
  expect(app?.sourceSteps.map((step) => step.label)).toEqual(["App policy decision", "App remediation audit", "App artifact"]);
  expect(app?.guardrails).toContain("Config citations name keys or bindings only; never include secret values.");
});

test("deriveGovernanceModel detects app human review artifacts", () => {
  const governance = deriveGovernanceModel(sampleAppReview, { artifactPath: "app-review.json" });

  expect(governance?.kind).toBe("app-human-review");
  expect(governance?.summary).toContain("approved app human review");
  expect(governance?.applied).toBe(false);
  expect(governance?.mutationAuthority).toBe("none");
});

test("deriveAppRemediationModel reads app human review citations and verification", () => {
  const app = deriveAppRemediationModel(sampleAppReview, { artifactPath: "app-review.json" });

  expect(app?.kind).toBe("app-human-review");
  expect(app?.approvalStatus).toBe("approved");
  expect(app?.approved).toBe(true);
  expect(app?.proposalStatus).toBe("approved");
  expect(app?.policyGates).toEqual(["migration-required", "rollback-required"]);
  expect(app?.citations.map((group) => `${group.label}:${group.values.length}`)).toEqual([
    "Source files:0",
    "Config keys:0",
    "Migration files:1",
    "Runbooks:1",
    "Rollback plans:1",
  ]);
  expect(app?.sourceSteps.map((step) => step.label)).toEqual(["App policy decision", "App remediation audit", "App artifact"]);
  expect(app?.verificationCommands).toContain("zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 4");
  expect(app?.guardrails).toContain("Human review approves proposal drafting only; it does not apply app source, config, migrations, operations, rollback plans, or deployment state.");
});

test("deriveGovernanceModel detects app application readiness artifacts", () => {
  const governance = deriveGovernanceModel(sampleAppReadiness, { artifactPath: "app-readiness.json" });

  expect(governance?.kind).toBe("app-application-readiness");
  expect(governance?.summary).toContain("ready app application readiness");
  expect(governance?.applied).toBe(false);
  expect(governance?.mutationAuthority).toBe("none");
});

test("deriveAppRemediationModel reads app application readiness checks and steps", () => {
  const app = deriveAppRemediationModel(sampleAppReadiness, { artifactPath: "app-readiness.json" });

  expect(app?.kind).toBe("app-application-readiness");
  expect(app?.readinessStatus).toBe("ready");
  expect(app?.readyForApplication).toBe(true);
  expect(app?.checks.map((check) => `${check.name}:${check.status}`)).toEqual(["proposal-state:pass"]);
  expect(app?.sourceSteps.map((step) => step.label)).toEqual([
    "App patch proposal",
    "App policy decision",
    "App human review",
    "App remediation audit",
    "App artifact",
  ]);
  expect(app?.verificationCommands).toContain("zig build causal-query -- --file app.json cause 2");
  expect(app?.applicationSteps).toContain("Apply the reviewed change outside this readiness command.");
  expect(app?.guardrails).toContain("Readiness does not edit app source.");
});

test("deriveGovernanceModel detects app application artifacts", () => {
  const governance = deriveGovernanceModel(sampleAppApplication, { artifactPath: "app-application.json" });

  expect(governance?.kind).toBe("app-application");
  expect(governance?.summary).toContain("applied app application");
  expect(governance?.applied).toBe(true);
  expect(governance?.mutationAuthority).toBe("record-only");
});

test("deriveProductionTelemetryPreviewModel reads ready NenDB retention fixtures", () => {
  const preview = deriveProductionTelemetryPreviewModel(sampleProductionTelemetryRetention, {
    artifactPath: "retention.json",
  });

  expect(preview?.schema).toBe("zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1");
  expect(preview?.status).toBe("ready");
  expect(preview?.readyForNextBranch).toBe(true);
  expect(preview?.authority.nendbWriteEnabled).toBe(false);
  expect(preview?.authority.durableWriteEnabled).toBe(false);
  expect(preview?.sources.map((source) => source.kind)).toEqual([
    "local-pipeline",
    "boundary",
    "proposal",
    "readiness",
    "fixtures",
  ]);
  expect(preview?.mappingFixtures.map((fixture) => fixture.id)).toContain("nendb-runtime-event-node-fixture");
  expect(preview?.mappingFixtures[0]?.retainedFields).toContain("event_id_ref");
  expect(preview?.validationChecks).toContain("nendb-write-disabled");
  expect(preview?.verificationCommands).toContain("zig build causal-production-telemetry-local-pipeline-fixtures");
  expect(preview?.nextBranch).toBe("codex/zigeffect-causal-production-telemetry-workbench-readonly-preview");
});

test("deriveProductionTelemetryPreviewModel reads blocked retention fixtures", () => {
  const preview = deriveProductionTelemetryPreviewModel({
    ...sampleProductionTelemetryRetention,
    decision: "reject",
    retention_fixture_status: "blocked",
    ready_for_next_branch: false,
    checks: [{ name: "decision-approved", status: "fail", detail: "reviewer rejected" }],
  }, { artifactPath: "blocked-retention.json" });

  expect(preview?.status).toBe("blocked");
  expect(preview?.readyForNextBranch).toBe(false);
  expect(preview?.checks[0]).toEqual({ name: "decision-approved", status: "fail", detail: "reviewer rejected" });
});

test("deriveAppFacingPreviewModel reads ready SolidJS WebUI preview artifacts", () => {
  const preview = deriveAppFacingPreviewModel(sampleAppFacingSolidWebuiPreview, {
    artifactPath: "app-preview.json",
  });

  expect(preview?.schema).toBe("zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1");
  expect(preview?.sourceMode).toBe("solid-webui-readonly-preview");
  expect(preview?.status).toBe("ready");
  expect(preview?.decision).toBe("approve");
  expect(preview?.readyForNextBranch).toBe(true);
  expect(preview?.authority.readOnlyPreview).toBe(true);
  expect(preview?.authority.solidWebuiEnabled).toBe(true);
  expect(preview?.authority.solidWebuiRenderer).toBe("solidjs");
  expect(preview?.authority.webuiBridge).toBe("webui-dev/zig-webui");
  expect(preview?.authority.appMutationControlsEnabled).toBe(false);
  expect(preview?.authority.hostedLiveDashboardEnabled).toBe(false);
  expect(preview?.authority.reactRendererEnabled).toBe(false);
  expect(preview?.authority.alternateRendererEnabled).toBe(false);
  expect(preview?.bridgeRecords.map((record) => record.id)).toContain("solid-webui-review-preview-bridge");
  expect(preview?.sections.map((section) => section.id)).toContain("solid-webui-preview");
  expect(preview?.blockedClaims).toContain("applied=true");
  expect(preview?.verificationCommands).toContain("bun run zigeffect:workbench:test");
  expect(preview?.nextBranch).toBe("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report");
});

test("deriveAppFacingPreviewModel adapts ready audit remediation bridge artifacts into source preview mode", () => {
  const sourceBridge = {
    schema: "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1",
    audit_remediation_bridge_status: "ready",
    decision: "approve",
    applied: false,
    mutation_authority: "none",
    solid_webui_preview_enabled: false,
    audit_remediation_bridge_records: sampleAppFacingSolidWebuiPreview.bridge_records,
    checks: [{ name: "authority-boundary", status: "pass", detail: "no mutation authority" }],
    bridge_validation_checks: ["solid-webui-readonly-preview-next-only"],
    verified_commands: ["zig build causal-app-facing-production-integration-audit-remediation-bridge"],
    recommendation: "start-app-facing-production-integration-solid-webui-readonly-preview",
    next_branch_if_ready: "codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview",
  };

  const preview = deriveAppFacingPreviewModel(sourceBridge, { artifactPath: "source-bridge.json" });

  expect(preview?.sourceMode).toBe("audit-remediation-bridge");
  expect(preview?.status).toBe("ready");
  expect(preview?.authority.readOnlyPreview).toBe(false);
  expect(preview?.authority.solidWebuiEnabled).toBe(false);
  expect(preview?.authority.appMutationControlsEnabled).toBe(false);
  expect(preview?.bridgeRecords.map((record) => record.id)).toContain("solid-webui-review-preview-bridge");
  expect(preview?.validationChecks).toContain("solid-webui-readonly-preview-next-only");
  expect(preview?.nextBranch).toBe("codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview");
});

test("deriveAppFacingPreviewModel keeps authority drift visible instead of hiding blocked artifacts", () => {
  const preview = deriveAppFacingPreviewModel(
    {
      ...sampleAppFacingSolidWebuiPreview,
      status: "blocked",
      app_mutation_controls_enabled: true,
      checks: [{ name: "app-mutation-controls-disabled", status: "fail", detail: "mutation controls are enabled" }],
    },
    { artifactPath: "app-preview-blocked.json" },
  );

  expect(preview?.status).toBe("blocked");
  expect(preview?.authority.appMutationControlsEnabled).toBe(true);
  expect(preview?.checks[0]).toEqual({
    name: "app-mutation-controls-disabled",
    status: "fail",
    detail: "mutation controls are enabled",
  });
});

test("deriveAppRemediationModel reads app application evidence", () => {
  const app = deriveAppRemediationModel(sampleAppApplication, { artifactPath: "app-application.json" });

  expect(app?.kind).toBe("app-application");
  expect(app?.applicationStatus).toBe("applied");
  expect(app?.readinessStatus).toBe("ready");
  expect(app?.readyForApplication).toBe(true);
  expect(app?.changeEvidence.map((group) => `${group.label}:${group.values.length}`)).toEqual([
    "Source changes:1",
    "Config changes:1",
    "Migration changes:0",
    "Operation changes:0",
    "Rollback changes:0",
  ]);
  expect(app?.beforeEvidence).toEqual([".zig-cache/causal-artifacts/yachdee-platform-before-app.json"]);
  expect(app?.afterEvidence).toEqual([".zig-cache/causal-artifacts/yachdee-platform-after-app.json"]);
  expect(app?.sourceSteps.map((step) => step.label)).toEqual([
    "App application readiness",
    "App patch proposal",
    "App policy decision",
    "App human review",
    "App remediation audit",
    "App artifact",
  ]);
});

test("deriveAppRemediationModel tolerates partial app artifacts", () => {
  const app = deriveAppRemediationModel({
    schema: "zigeffect.causal.app-remediation-audit.v1",
    source: {},
  }, { artifactPath: "partial-app-audit.json" });

  expect(app?.target).toBe("unknown");
  expect(app?.incidents).toEqual([]);
  expect(app?.warnings).toContain("artifact schema_version is missing");
});

test("deriveRemediationChainModel tolerates partial chain artifacts", () => {
  const chain = deriveRemediationChainModel({
    schema: "zigeffect.causal.audit-chain.v1",
    source: { before: "before.json" },
  }, { artifactPath: "partial-chain.json" });

  expect(chain?.target).toBe("unknown");
  expect(chain?.sourceSteps.map((step) => step.kind)).toEqual(["before"]);
  expect(chain?.warnings).toContain("artifact schema_version is missing");
  expect(chain?.classifications.disappeared).toEqual([]);
});

function minimalEvent(idText: string): CausalEvent {
  return {
    idText,
    numericId: Number(idText),
    kind: "unknown",
    status: "unknown",
    label: "",
    typeName: "",
    redactedDetail: "",
    runId: null,
    parentId: null,
    fiberId: null,
    scopeId: null,
    traceId: null,
    spanId: null,
    artifactId: "",
    domainEntityRef: "",
    dataSubjectRef: "",
    schemaRef: "",
    raw: { id: Number(idText) },
  };
}
