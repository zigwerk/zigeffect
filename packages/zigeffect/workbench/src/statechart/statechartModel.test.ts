import { expect, test } from "bun:test";
import {
  deriveActorGraphModel,
  deriveStatechartGraphModel,
  diffStatechartDefinitions,
  parseStatechartCatalog,
  type StatechartDefinitionArtifact,
} from "./statechartModel";

const definition: StatechartDefinitionArtifact = {
  schema: "zigeffect.statechart.definition.v1",
  schema_version: 1,
  id: "agent.review",
  version: 1,
  fingerprint: "44",
  initial: "root",
  description: "Visible agent review logic",
  state_type: "State",
  event_type: "Event",
  context_type: "Context",
  command_type: "Command",
  states: [
    { id: "root", kind: "compound", parent: null, initial: "working", description: "", entry: [], exit: [], source: { file: "review.zig", declaration: "machine", line: 10, column: 1 } },
    { id: "working", kind: "parallel", parent: "root", initial: null, description: "", entry: [], exit: [], source: { file: "review.zig", declaration: "machine", line: 11, column: 1 } },
    { id: "research", kind: "atomic", parent: "working", initial: null, description: "", entry: ["start-research"], exit: [], source: { file: "review.zig", declaration: "machine", line: 12, column: 1 } },
    { id: "approval", kind: "atomic", parent: "working", initial: null, description: "", entry: [], exit: [], source: { file: "review.zig", declaration: "machine", line: 13, column: 1 } },
    { id: "done", kind: "final", parent: "root", initial: null, description: "", entry: [], exit: [], source: { file: "review.zig", declaration: "machine", line: 14, column: 1 } },
  ],
  transitions: [
    { id: "approve", source: "working", event: "approve", target: "done", kind: "external", reenter: false, guard: "has-evidence", actions: ["publish"], description: "", source_ref: { file: "review.zig", declaration: "machine", line: 20, column: 1 } },
  ],
};

test("statechart catalog parses embedded definitions snapshots and execution overlays", () => {
  const catalog = parseStatechartCatalog({
    schema: "zigeffect.causal.v1",
    statecharts: [definition],
    statechart_snapshots: [{
      schema: "zigeffect.statechart.snapshot.v1",
      schema_version: 1,
      definition_fingerprint: 44,
      instance_id: 7,
      configuration: ["root", "working", "research", "approval"],
      active_atomic_states: ["research", "approval"],
      status: "active",
      revision: 3,
      last_event_sequence: 3,
      context_redacted: true,
      context: "<redacted>",
    }],
    statechart_executions: [{
      schema: "zigeffect.statechart.execution.v1",
      schema_version: 1,
      instance_id: 7,
      decision_fingerprint: 80,
      outcome: "transitioned",
      event: "approve",
      transition_ids: ["approve"],
      from_configuration: ["research", "approval"],
      to_configuration: ["done"],
      revision: 4,
      actions: [{ phase: "transition", id: "publish" }],
      guards: [{ id: "has-evidence", transition_id: "approve", accepted: true }],
      commands: ["notify"],
      command_outcomes: [{ command: "notify", status: "failed", detail: "timeout" }],
      internal_events: [],
    }],
    statechart_coverage: [{
      schema: "zigeffect.statechart.coverage.v1",
      schema_version: 1,
      definition_id: "agent.review",
      definition_fingerprint: 44,
      summary: { total_states: 5, visited_states: 4, total_transitions: 1, visited_transitions: 1, total_events: 1, observed_events: 1 },
      states: [{ id: "research", count: 3 }],
      transitions: [{ id: "approve", count: 1 }],
      events: [{ id: "approve", count: 1 }],
    }],
  });

  expect(catalog.definitions).toHaveLength(1);
  expect(catalog.instances[0]?.activeAtomicStates).toEqual(["research", "approval"]);
  expect(catalog.executions[0]?.transitionIds).toEqual(["approve"]);
  expect(catalog.executions[0]?.guards[0]).toEqual({ id: "has-evidence", transitionId: "approve", accepted: true });
  expect(catalog.executions[0]?.commandOutcomes[0]?.status).toBe("failed");
  expect(catalog.coverage[0]?.transitionCounts.approve).toBe("1");
});

test("workbench consumes the native catalog field names without translation", () => {
  const catalog = parseStatechartCatalog({
    schema: "zigeffect.statechart.catalog.v1",
    schema_version: 1,
    definitions: [definition],
    snapshots: [],
    executions: [],
    coverage: [],
  });
  expect(catalog.definitions.map((item) => item.id)).toEqual(["agent.review"]);
});

test("statechart graph preserves containment transitions and the active overlay", () => {
  const catalog = parseStatechartCatalog({
    statecharts: [definition],
    statechart_snapshots: [{
      schema: "zigeffect.statechart.snapshot.v1",
      schema_version: 1,
      definition_fingerprint: 44,
      instance_id: 7,
      configuration: ["root", "working", "research", "approval"],
      active_atomic_states: ["research", "approval"],
      status: "active",
      revision: 3,
      last_event_sequence: 3,
      context_redacted: true,
      context: "<redacted>",
    }],
  });
  const graph = deriveStatechartGraphModel(catalog.definitions[0]!, catalog.instances[0], {
    schema: "zigeffect.statechart.coverage.v1",
    definitionId: "agent.review",
    definitionFingerprint: "44",
    stateCounts: { research: "3" },
    transitionCounts: { approve: "1" },
    eventCounts: { approve: "1" },
  });

  expect(graph.nodes.find((node) => node.id === "state:research")?.tone).toBe("warning");
  expect(graph.edges.some((edge) => edge.kind === "contains" && edge.source === "state:working" && edge.target === "state:research")).toBe(true);
  expect(graph.edges.some((edge) => edge.kind === "transition" && edge.source === "state:working" && edge.target === "state:done")).toBe(true);
  expect(graph.nodes.find((node) => node.id === "state:research")?.detail).toContain("visited:3");
  expect(graph.edges.find((edge) => edge.id === "transition:approve")?.detail).toContain("count:1");
  expect(graph.warnings).toEqual([]);
});

test("statechart catalog fails closed on dangling transition targets", () => {
  const invalid = structuredClone(definition);
  invalid.transitions[0]!.target = "missing";

  expect(() => parseStatechartCatalog({ statecharts: [invalid] })).toThrow("unknown target missing");
});

test("actor graph exposes every machine instance and its active atomic states", () => {
  const catalog = parseStatechartCatalog({
    statecharts: [definition],
    statechart_snapshots: [{
      schema: "zigeffect.statechart.snapshot.v1",
      schema_version: 1,
      definition_fingerprint: 44,
      instance_id: 7,
      configuration: ["root", "working", "research"],
      active_atomic_states: ["research"],
      status: "active",
      revision: 3,
      last_event_sequence: 3,
      context_redacted: true,
      context: "<redacted>",
    }],
  });

  const graph = deriveActorGraphModel(catalog);
  expect(graph.nodes.some((node) => node.id === "actor:7" && node.group === "actor")).toBe(true);
  expect(graph.edges.some((edge) => edge.kind === "invokes" && edge.target === "actor-state:7:research")).toBe(true);
});

test("definition version diff reports structural additions removals and changes", () => {
  const next = structuredClone(definition);
  next.version = 2;
  next.fingerprint = "45";
  next.states.push({ id: "failed", kind: "final", parent: "root", initial: null, description: "", entry: [], exit: [], source: { file: "review.zig", declaration: "machine", line: 15, column: 1 } });
  next.transitions[0]!.guard = "review-complete";
  next.transitions.push({ id: "reject", source: "working", event: "reject", target: "failed", kind: "external", reenter: false, guard: null, actions: [], description: "", source_ref: { file: "review.zig", declaration: "machine", line: 21, column: 1 } });

  const diff = diffStatechartDefinitions(definition, next);
  expect(diff.statesAdded).toEqual(["failed"]);
  expect(diff.transitionsAdded).toEqual(["reject"]);
  expect(diff.transitionsChanged).toEqual(["approve"]);
});

test("guard rejection and command failure are visible graph overlays", () => {
  const execution = parseStatechartCatalog({
    statecharts: [definition],
    statechart_executions: [{
      schema: "zigeffect.statechart.execution.v1", schema_version: 1, instance_id: 7, decision_fingerprint: 81,
      outcome: "ignored", event: "approve", transition_ids: [], from_configuration: ["research"], to_configuration: ["research"], revision: 4,
      actions: [], guards: [{ id: "has-evidence", transition_id: "approve", accepted: false }], commands: [],
      command_outcomes: [{ command: "notify", status: "failed", detail: "timeout" }], internal_events: [],
    }],
  }).executions[0]!;
  const graph = deriveStatechartGraphModel(definition, {
    schema: "zigeffect.statechart.snapshot.v1", definitionFingerprint: "44", instanceId: "7", configuration: ["research"], activeAtomicStates: ["research"], status: "active", revision: "4", lastEventSequence: "4", contextRedacted: true,
  }, undefined, execution);
  expect(graph.edges.find((edge) => edge.id === "transition:approve")?.tone).toBe("failure");
  expect(graph.nodes.find((node) => node.id === "state:research")?.tone).toBe("failure");
});

test("v2 artifacts preserve u64 identities beyond JavaScript safe integer range", () => {
  const v2 = structuredClone(definition) as unknown as Record<string, unknown>;
  v2.schema = "zigeffect.statechart.definition.v2";
  v2.schema_version = 2;
  v2.fingerprint = "18446744073709551614";
  const catalog = parseStatechartCatalog({
    statecharts: [v2],
    statechart_snapshots: [{
      schema: "zigeffect.statechart.snapshot.v2", schema_version: 2,
      definition_fingerprint: "18446744073709551614", instance_id: "18446744073709551615",
      configuration: ["root", "working", "research"], active_atomic_states: ["research"], status: "active",
      revision: "9007199254740993", last_event_sequence: "9007199254740993", context_redacted: true,
    }],
  });
  expect(catalog.instances[0]?.instanceId).toBe("18446744073709551615");
  expect(catalog.instances[0]?.revision).toBe("9007199254740993");
  expect(catalog.warnings).toEqual([]);
});

test("malformed replay identities and hostile source metadata fail closed or stay inert", () => {
  for (const invalid of ["-1", "1.5", "18446744073709551616", 9_007_199_254_740_992, {}, null]) {
    expect(() => parseStatechartCatalog({
      statecharts: [definition],
      statechart_snapshots: [{
        schema: "zigeffect.statechart.snapshot.v2", schema_version: 2, definition_fingerprint: "44",
        instance_id: invalid, configuration: ["research"], active_atomic_states: ["research"], status: "active",
        revision: "0", last_event_sequence: "0", context_redacted: true,
      }],
    })).toThrow();
  }
  const hostile = structuredClone(definition);
  hostile.states[0]!.source.file = "</script><img src=x onerror=alert(1)>";
  const catalog = parseStatechartCatalog({ statecharts: [hostile] });
  expect(catalog.definitions[0]?.states[0]?.source.file).toContain("</script>");
});

test("maximum supported graph sizes stay inside the workbench render-model budget", () => {
  const large = structuredClone(definition);
  large.id = "agent.large-graph";
  large.fingerprint = "999";
  large.initial = "s0";
  large.states = Array.from({ length: 256 }, (_, index) => ({
    id: `s${index}`, kind: "atomic" as const, parent: null, initial: null, description: "", entry: [], exit: [],
    source: { file: "machine.zig", declaration: "large", line: index + 1, column: 1 },
  }));
  large.transitions = Array.from({ length: 1024 }, (_, index) => ({
    id: `t${index}`, source: `s${index % 256}`, event: `e${index}`, target: `s${(index + 1) % 256}`,
    kind: "external" as const, reenter: false, guard: null, actions: [], description: "",
    source_ref: { file: "machine.zig", declaration: "large", line: index + 300, column: 1 },
  }));
  const started = performance.now();
  const graph = deriveStatechartGraphModel(large);
  const elapsed = performance.now() - started;
  expect(graph.nodes).toHaveLength(256);
  expect(graph.edges).toHaveLength(1024);
  expect(elapsed).toBeLessThan(500);
});
