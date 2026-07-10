import { expect, test } from "bun:test";
import {
  compareProjectSessions,
  deriveProjectDevelopmentModel,
  focusProjectDevelopment,
  parseProjectDevelopmentFrameMessage,
} from "./projectDevelopment";

const fixture = {
  schema: "zigeffect.project-development.v1",
  sequence: 7,
  connection: "live",
  recovery_state: "clean",
  approval_state: "pending",
  current_session: "session-2",
  baseline_session: "session-1",
  manifest: {
    schema: "zigeffect.project.v1",
    name: "billing-system",
    version: "0.1.0",
    kind: "system",
    components: [
      { id: "api", kind: "service", path: "services/api", depends_on: ["shared"], capabilities: ["http", "sql"] },
      { id: "shared", kind: "package", path: "packages/shared", depends_on: [], capabilities: [] },
    ],
    commands: [
      { id: "check", argv: ["zig", "build", "test"] },
      { id: "dev", argv: ["zig", "build", "run"], component: "api" },
    ],
    requirements: [
      { id: "req-api", summary: "serve typed invoices", component: "api", status: "active" },
      { id: "req-shared", summary: "share invoice Schema", component: "shared", status: "satisfied" },
    ],
    acceptance_checks: [
      { id: "check-api", requirement: "req-api", command: "check", expectation: "tests pass", status: "failed" },
    ],
  },
  status: {
    schema: "zigeffect.project-status.v1",
    project: "billing-system",
    requirements_total: 2,
    requirements_open: 1,
    checks_total: 1,
    checks_pending: 0,
    checks_failed: 1,
    tasks: [{ id: "task-api", requirement: "req-api", component: "api", summary: "implement route", status: "active" }],
    evidence: [{
      id: "evidence-test",
      requirement: "req-api",
      acceptance_check: "check-api",
      component: "api",
      kind: "test_result",
      artifact: ".zigeffect/receipts/check.json",
      causal_event_ids: [12],
      summary: "test failed",
    }],
    next_actions: [{ id: "next-api", requirement: "req-api", component: "api", summary: "repair route", command: "check" }],
  },
  handoff: {
    schema: "zigeffect.agent-handoff.v1",
    project: "billing-system",
    provider: "codex",
    session: "session-2",
    summary: "repairing token=sentinel-secret-for-tests",
    tasks: [],
    evidence: [],
    next_actions: [],
    blockers: [],
  },
  sessions: [
    { id: "session-1", provider: "claude-code", status: "completed", connection: "recovered", recovery: "recovered", approval: "approved", task_ids: [], evidence_ids: [] },
    { id: "session-2", provider: "codex", status: "running", connection: "live", recovery: "clean", approval: "pending", task_ids: ["task-api"], evidence_ids: ["evidence-test"] },
  ],
  events: [
    {
      id: 12,
      kind: "span_recorded",
      label: "app.schema.decode",
      type_name: "zigeffect.app.data_transformed",
      status: "failure",
      service_key: "api",
      schema_ref: "Invoice.v1",
      redacted_detail: "invalid invoice",
    },
  ],
};

test("project development model joins manifest protocol sessions and application facts", () => {
  const model = deriveProjectDevelopmentModel(fixture);
  expect(model.project).toBe("billing-system");
  expect(model.components.map((component) => component.id)).toEqual(["api", "shared"]);
  expect(model.dependencies).toEqual([{ from: "api", to: "shared" }]);
  expect(model.requirements[0]?.checks[0]?.id).toBe("check-api");
  expect(model.requirements[0]?.evidence[0]?.id).toBe("evidence-test");
  expect(model.applicationFacts[0]).toMatchObject({ eventId: "12", kind: "schema_decode", schemaRef: "Invoice.v1" });
  expect(model.sessions[1]).toMatchObject({ id: "session-2", approval: "pending", recovery: "clean" });
  expect(JSON.stringify(model)).not.toContain("sentinel-secret");
});

test("project development focus and session comparison remain reference-aware", () => {
  const model = deriveProjectDevelopmentModel(fixture);
  const focused = focusProjectDevelopment(model, { component: "api", session: "session-2" });
  expect(focused.requirements.map((requirement) => requirement.id)).toEqual(["req-api"]);
  expect(focused.tasks.map((task) => task.id)).toEqual(["task-api"]);
  expect(focused.artifacts.map((artifact) => artifact.path)).toEqual([".zigeffect/receipts/check.json"]);
  expect(focused.applicationFacts.map((fact) => fact.eventId)).toEqual(["12"]);

  const comparison = compareProjectSessions(model, "session-1", "session-2");
  expect(comparison).toMatchObject({ baseline: "session-1", current: "session-2", tasksAdded: 1, evidenceAdded: 1 });
});

test("project development parser rejects unknown schemas duplicates and broken references", () => {
  expect(() => deriveProjectDevelopmentModel({ ...fixture, schema: "zigeffect.project-development.v9" })).toThrow();
  expect(() => deriveProjectDevelopmentModel({
    ...fixture,
    manifest: { ...fixture.manifest, components: [...fixture.manifest.components, fixture.manifest.components[0]] },
  })).toThrow("duplicate component");
  expect(() => deriveProjectDevelopmentModel({
    ...fixture,
    manifest: {
      ...fixture.manifest,
      acceptance_checks: [{ ...fixture.manifest.acceptance_checks[0], requirement: "missing" }],
    },
  })).toThrow("unknown requirement");
  expect(parseProjectDevelopmentFrameMessage("{not-json")).toBeNull();
  expect(parseProjectDevelopmentFrameMessage(JSON.stringify(fixture))?.sequence).toBe(7);
});
