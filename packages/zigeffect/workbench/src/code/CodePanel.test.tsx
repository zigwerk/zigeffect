import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { deriveCodeQueryModel, truncationNotice } from "./repositoryQuery";

const sampleUrl = new URL("../../public/sample-repository-query.json", import.meta.url);

test("the shipped sample is a real engine answer this build can read", () => {
  const raw = JSON.parse(readFileSync(sampleUrl, "utf8")) as unknown;
  const model = deriveCodeQueryModel(raw);

  // Captured from `zgraphy query "resolve imports" --json` against this
  // repository, so it fails if the engine's JSON drifts from what the panel
  // reads — which is the failure a hand-written fixture would hide.
  expect(model.query).toBe("resolve imports");
  expect(model.embedder).toBe("feature_hash_v1");
  expect(model.results.length).toBeGreaterThan(0);
  expect(model.corpus).toBeGreaterThan(model.results.length);

  // Every result must carry its evidence, or the panel has a bar with nothing
  // behind it.
  for (const result of model.results) {
    expect(Number.isFinite(result.keywordScore)).toBe(true);
    expect(Number.isFinite(result.vectorScore)).toBe(true);
    expect(Number.isFinite(result.graphScore)).toBe(true);
    expect(result.keywordScore).toBeGreaterThanOrEqual(0);
    expect(result.keywordScore).toBeLessThanOrEqual(1);
  }

  // The sample is a bounded scan, so the panel has something real to warn about.
  expect(truncationNotice(model, 8)).toContain("of");
});

test("the panel renders all four things the code perspective owes a reader", () => {
  const source = readFileSync(new URL("./CodePanel.tsx", import.meta.url), "utf8");

  // 1. A live query box.
  expect(source).toContain("Repository query");
  expect(source).toContain("props.onQuery");
  // Disabled rather than hidden when nothing is attached: a box that silently
  // does nothing is worse than one that says it cannot.
  expect(source).toContain("No engine attached");

  // 2. Per-signal score bars — all three, kept apart.
  expect(source).toContain("keywordScore");
  expect(source).toContain("vectorScore");
  expect(source).toContain("graphScore");
  expect(source).toContain("cs-fill");

  // 3. The truncation banner.
  expect(source).toContain("truncationNotice");
  expect(source).toContain("code-truncation");

  // 4. The confidence verdict WITH its reason.
  expect(source).toContain("confidenceReason");
  expect(source).toContain("Low confidence");
});

test("the numeric score stays beside its bar", () => {
  const source = readFileSync(new URL("./CodePanel.tsx", import.meta.url), "utf8");
  // A bar communicates a shape. Two results that differ in the third decimal
  // render identically, so the number has to be readable too.
  expect(source).toContain("cs-value");
  expect(source).toContain("props.value.toFixed(2)");
});
