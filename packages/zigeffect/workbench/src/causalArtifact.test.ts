import { expect, test } from "bun:test";
import {
  type CausalEvent,
  causePathForEvent,
  deriveGovernanceModel,
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
    raw: { id: Number(idText) },
  };
}
