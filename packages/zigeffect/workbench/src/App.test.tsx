import { expect, test } from "bun:test";
import { workbenchTabsForArtifact } from "./App";
import { readFileSync } from "node:fs";

const source = () => readFileSync(new URL("./App.tsx", import.meta.url), "utf8");

test("workbenchTabsForArtifact exposes the surviving workbench tabs", () => {
  const tabIds = workbenchTabsForArtifact().map((tab) => tab.id);

  expect(tabIds).toEqual([
    "timeline",
    "agents",
    "findings",
    "graph",
    "visual-graph",
    "diff",
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

test("workbenchTabsForArtifact labels the agents tab as Dev Session", () => {
  const agentsTab = workbenchTabsForArtifact().find((tab) => tab.id === "agents");

  expect(agentsTab?.label).toBe("Dev Session");
});

test("workbenchTabsForArtifact exposes dedicated synchronized Ziac views", () => {
  expect(workbenchTabsForArtifact("ziac.visual.v1")).toEqual([
    { id: "ziac-topology", label: "Topology" },
    { id: "ziac-map", label: "Global Map" },
  ]);
});

test("Ziac estate refresh uses the host scanner and refetches the actual artifact", () => {
  const value = source();
  expect(value).toContain("requestEstateScan");
  expect(value).toContain("refetch");
  expect(value).toContain("onEstateRefresh={refreshEstate}");
});
