import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";

const dagSource = () => readFileSync(new URL("./graph/DagPanel.tsx", import.meta.url), "utf8");
const appSource = () => readFileSync(new URL("./App.tsx", import.meta.url), "utf8");
const stylesSource = () => readFileSync(new URL("./styles.css", import.meta.url), "utf8");

test("the single DAG panel exposes perspective and layout controls plus a legend", () => {
  const source = dagSource();

  expect(source).toContain('ariaLabel="Causal graph perspective"');
  expect(source).toContain('ariaLabel="Causal graph layout"');
  expect(source).toContain("dag-legend");
  expect(source).toContain("CausalDag");
  expect(source).toContain('ariaLabel="Graph surface mode"');
  expect(source).toContain('{ value: "statechart", label: "Statechart" }');
  expect(source).toContain('{ value: "actors", label: "Actors" }');
});

test("App drives the DAG with a shared perspective + selection", () => {
  const source = appSource();

  expect(source).toContain("graphPerspective");
  expect(source).toContain("graphMode");
  expect(source).toContain("deriveStatechartGraphModel");
  expect(source).toContain("deriveActorGraphModel");
  expect(source).toContain("<DagPanel");
  expect(source).toContain("selectedId={selectedId()}");
  expect(source).toContain("createEffect(() => applyThemeToDocument(theme()))");
});

test("the token system styles every primary surface", () => {
  const source = stylesSource();

  expect(source).toContain('data-theme="light"');
  expect(source).toContain(".segmented");
  expect(source).toContain(".trace-row");
  expect(source).toContain(".cause-overlay");
  expect(source).toContain(".finding-counter");
  expect(source).toContain(".dag-legend");
  expect(source).toContain(".inspector");
});
