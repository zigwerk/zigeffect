import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { workbenchAuxViews, workbenchLensesForArtifact, workbenchTabsForArtifact } from "./App";

const source = () => readFileSync(new URL("./App.tsx", import.meta.url), "utf8");

test("workbench exposes the two headline lenses in order", () => {
  const lensIds = workbenchLensesForArtifact().map((lens) => lens.id);

  expect(lensIds).toEqual(["execution", "collaboration"]);
});

test("workbench labels the lenses for humans", () => {
  const labels = workbenchLensesForArtifact().map((lens) => lens.label);

  expect(labels).toEqual(["Execution", "Collaboration"]);
});

test("the dissolved tabs survive as auxiliary views", () => {
  const auxIds = workbenchAuxViews();

  expect(auxIds).toEqual(["diff", "chain", "metadata", "queries", "safety", "tests"]);
  // the old flat tab bar is gone; these are reachable via the command palette / More.
  expect(auxIds).not.toContain("timeline");
  expect(auxIds).not.toContain("visual-graph");
});

test("App wires the live local dev session overlay when attached", () => {
  const source = readFileSync(new URL("./App.tsx", import.meta.url), "utf8");

  expect(source).toContain("live?.localDevSession()");
  expect(source).toContain("live?.projectDevelopment()");
});

test("App drives a single selection id across every surface", () => {
  const source = readFileSync(new URL("./App.tsx", import.meta.url), "utf8");

  // one selectedId signal feeds the trace, the DAG, the inspector, and the collab board.
  expect(source).toContain("const [selectedId, setSelectedId]");
  expect(source).toContain("<TraceCanvas");
  expect(source).toContain("<DagPanel");
  expect(source).toContain("<Inspector");
  expect(source).toContain("<CollabBoard");
});

test("the collaboration board keeps the transports panel and turn count", () => {
  const source = readFileSync(new URL("./collab/CollabBoard.tsx", import.meta.url), "utf8");

  expect(source).toContain("<h3>Transports</h3>");
  expect(source).toContain('Metric label="turns"');
  expect(source).toContain("<ProjectDevelopmentPanel");
});

test("workbench tabs remain scoped to ZigEffect artifacts", () => {
  expect(workbenchTabsForArtifact()).not.toContainEqual(expect.objectContaining({ id: "ziac-topology" }));
  expect(source()).not.toContain("ZiacWorkbench");
});
