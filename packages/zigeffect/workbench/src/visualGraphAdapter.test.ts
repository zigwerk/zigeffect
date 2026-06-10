import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";

const adapterSource = () => readFileSync(new URL("./visualGraphAdapter.tsx", import.meta.url), "utf8");

test("visual graph adapter maps group tone priority and edge kind metadata", () => {
  const source = adapterSource();

  expect(source).toContain("group: node.group");
  expect(source).toContain("detail: node.detail");
  expect(source).toContain("priority: node.priority");
  expect(source).toContain("stroke: toneStroke(node.tone)");
  expect(source).toContain("kind: edge.kind");
  expect(source).toContain("stroke: toneStroke(edge.tone)");
});

test("visual graph adapter layout is perspective-aware", () => {
  const source = adapterSource();

  expect(source).toContain("solidG6Layout(model: VisualGraphModel)");
  expect(source).toContain('type: "radial"');
  expect(source).toContain('unitRadius: model.perspective === "ownership" ? 120 : 90');
});
