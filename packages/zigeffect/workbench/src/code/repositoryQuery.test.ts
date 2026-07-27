import { expect, test } from "bun:test";
import {
  deriveCodeQueryModel,
  InvalidCodeQueryArtifact,
  queryTermCount,
  truncationNotice,
} from "./repositoryQuery";

/**
 * Captured from the shipped CLI (`zgraphy query "resolve imports" --json`)
 * rather than written by hand, so the field names here are the ones the engine
 * actually emits. A hand-authored fixture is a test of the fixture.
 */
const fixture = {
  schema: "zgraphy.query.v4",
  query: "resolve imports",
  embedder: "feature_hash_v1",
  generation: "g-f8419468fbb923dec1cfb4bddd7f7d45e21f26dccd2d6f83819ce06be5ca80f0",
  tree_verified: false,
  confidence: "high",
  confidence_reason: "",
  scanned: 891,
  corpus: 5603,
  results: [
    {
      id: 17642997841897308639,
      label: "resolveFileImports",
      kind: "symbol",
      path: "src/indexer.zig",
      line: 1317,
      score: 0.7325016856193542,
      keyword_score: 1,
      vector_score: 0.7677016854286194,
      graph_score: 0.06903021782636642,
      matched_terms: 2,
    },
    {
      id: 12,
      label: "importsFile",
      kind: "symbol",
      path: "src/indexer.zig",
      line: 700,
      score: 0.5,
      keyword_score: 0.6,
      vector_score: 0.4,
      graph_score: 0,
      matched_terms: 1,
    },
  ],
};

test("the model keeps the three signals apart instead of collapsing them into the total", () => {
  const model = deriveCodeQueryModel(fixture);
  expect(model.results).toHaveLength(2);
  const first = model.results[0]!;
  expect(first.label).toBe("resolveFileImports");
  expect(first.keywordScore).toBe(1);
  expect(first.vectorScore).toBeCloseTo(0.7677, 3);
  expect(first.graphScore).toBeCloseTo(0.069, 3);
  // The point of the split: a result can be strong overall and weak on a
  // signal, and a panel showing only `score` cannot say so.
  expect(first.graphScore).toBeLessThan(first.score);
});

test("a 64-bit node id survives as an identity rather than being rounded", () => {
  const model = deriveCodeQueryModel(fixture);
  // 17642997841897308639 exceeds Number.MAX_SAFE_INTEGER. Parsed as a number it
  // would land on a neighbouring value and could collide with another symbol in
  // the key of a list.
  expect(model.results[0]!.id).not.toBe("12");
  expect(model.results[0]!.id.length).toBeGreaterThan(15);
});

test("a low verdict without a reason is refused", () => {
  expect(() =>
    deriveCodeQueryModel({ ...fixture, confidence: "low", confidence_reason: "" }),
  ).toThrow(InvalidCodeQueryArtifact);

  const stated = deriveCodeQueryModel({
    ...fixture,
    confidence: "low",
    confidence_reason: "every query term is common in this repository",
  });
  expect(stated.confidence).toBe("low");
  expect(stated.confidenceReason).toContain("common");
});

test("a schema this build does not understand is refused rather than half-read", () => {
  expect(() => deriveCodeQueryModel({ ...fixture, schema: "zgraphy.query.v3" })).toThrow(
    InvalidCodeQueryArtifact,
  );
});

test("a score outside the unit range is clamped, not drawn past its bar", () => {
  const model = deriveCodeQueryModel({
    ...fixture,
    results: [{ ...fixture.results[0]!, keyword_score: 1.4, graph_score: -0.2 }],
  });
  expect(model.results[0]!.keywordScore).toBe(1);
  expect(model.results[0]!.graphScore).toBe(0);
});

test("the notice separates a bounded list from a bounded scan", () => {
  const model = deriveCodeQueryModel(fixture);

  // Scan bounded only: two results against a limit of ten is the whole list.
  const scanOnly = truncationNotice(model, 10);
  expect(scanOnly).toContain("891 of 5603");
  expect(scanOnly).not.toContain("top 10");

  // Both bounded: a full list means a further result may exist unseen.
  const both = truncationNotice(model, 2);
  expect(both).toContain("top 2");
  expect(both).toContain("891 of 5603");

  // Neither: an exhaustive scan returning a short list says nothing.
  const exhaustive = deriveCodeQueryModel({ ...fixture, scanned: 5603, corpus: 5603 });
  expect(truncationNotice(exhaustive, 10)).toBe("");
});

test("term count is distinct terms, so a repeated word does not inflate the denominator", () => {
  expect(queryTermCount("resolve imports")).toBe(2);
  expect(queryTermCount("resolve resolve imports")).toBe(2);
  expect(queryTermCount("  ")).toBe(0);
  expect(queryTermCount("Resolve RESOLVE")).toBe(1);
});
