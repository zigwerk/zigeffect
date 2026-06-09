import { expect, test } from "bun:test";
import {
  deriveWorkbenchModel,
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
