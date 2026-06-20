import { expect, test } from "bun:test";
import { workbenchTabsForArtifact } from "./App";

test("workbenchTabsForArtifact exposes the surviving workbench tabs", () => {
  const tabIds = workbenchTabsForArtifact().map((tab) => tab.id);

  expect(tabIds).toEqual([
    "timeline",
    "findings",
    "graph",
    "visual-graph",
    "chain",
    "queries",
    "metadata",
  ]);
});

test("workbenchTabsForArtifact does not expose deleted artifact tabs", () => {
  const tabIds = workbenchTabsForArtifact().map((tab) => tab.id);

  expect(tabIds).not.toContain("live");
  expect(tabIds).not.toContain("telemetry");
  expect(tabIds).not.toContain("app-preview");
});
