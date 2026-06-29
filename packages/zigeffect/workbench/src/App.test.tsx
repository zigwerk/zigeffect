import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { workbenchTabsForArtifact } from "./App";

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

test("Dev Session view exposes the transport panel", () => {
  const source = readFileSync(new URL("./App.tsx", import.meta.url), "utf8");

  expect(source).toContain("<h3>Transports</h3>");
});

test("App uses live local dev session overlay when attached", () => {
  const source = readFileSync(new URL("./App.tsx", import.meta.url), "utf8");

  expect(source).toContain("live?.localDevSession()");
});
