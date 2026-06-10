import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";

const appSource = () => readFileSync(new URL("./App.tsx", import.meta.url), "utf8");
const stylesSource = () => readFileSync(new URL("./styles.css", import.meta.url), "utf8");

test("VisualGraphView exposes perspective controls and debugging panels", () => {
  const source = appSource();

  expect(source).toContain("graphPerspective");
  expect(source).toContain('aria-label="Visual graph perspective"');
  expect(source).toContain("function VisualGraphDetail");
  expect(source).toContain("function VisualGraphLegend");
  expect(source).toContain("function VisualGraphWarnings");
});

test("visual graph debugging panels have dedicated responsive styles", () => {
  const source = stylesSource();

  expect(source).toContain(".visual-control-stack");
  expect(source).toContain(".visual-detail-panel");
  expect(source).toContain(".visual-legend-grid");
  expect(source).toContain(".warning-panel");
});
