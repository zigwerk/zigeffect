import { expect, test } from "bun:test";
import type { StatechartDefinitionArtifact, StatechartExecution } from "./statechartModel";
import { comparePathWithXState, toXStateConfig } from "./xstateOracle";

const definition: StatechartDefinitionArtifact = {
  schema: "zigeffect.statechart.definition.v1",
  schema_version: 1,
  id: "oracle.review",
  version: 1,
  fingerprint: "101",
  initial: "root",
  description: "",
  state_type: "State",
  event_type: "Event",
  context_type: "void",
  command_type: "void",
  states: [
    { id: "root", kind: "compound", parent: null, initial: "idle", description: "", entry: [], exit: [], source: { file: "", declaration: "", line: 0, column: 0 } },
    { id: "idle", kind: "atomic", parent: "root", initial: null, description: "", entry: [], exit: [], source: { file: "", declaration: "", line: 0, column: 0 } },
    { id: "done", kind: "final", parent: "root", initial: null, description: "", entry: [], exit: [], source: { file: "", declaration: "", line: 0, column: 0 } },
  ],
  transitions: [
    { id: "finish", source: "idle", event: "finish", target: "done", kind: "external", reenter: false, guard: null, actions: [], description: "", source_ref: { file: "", declaration: "", line: 0, column: 0 } },
  ],
};

const execution: StatechartExecution = {
  schema: "zigeffect.statechart.execution.v1",
  instanceId: "1",
  decisionFingerprint: "9",
  outcome: "transitioned",
  event: "finish",
  transitionIds: ["finish"],
  fromConfiguration: ["idle"],
  toConfiguration: ["done"],
  revision: "1",
  actions: [],
  guards: [],
  commands: [],
  commandOutcomes: [],
  internalEvents: [],
};

test("native definitions project to executable XState v5 configs", () => {
  const config = toXStateConfig(definition);
  expect(config.initial).toBe("root");
  expect(config.states.root?.states?.idle?.on?.finish).toBeDefined();
});

test("XState acts as an independent path equivalence oracle", () => {
  const report = comparePathWithXState(definition, [execution]);
  expect(report.equivalent).toBe(true);
  expect(report.steps[0]?.actual).toEqual(["done"]);
});
