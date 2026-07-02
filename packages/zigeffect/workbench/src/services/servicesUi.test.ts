import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";

const railSource = () => readFileSync(new URL("./ServicesRail.tsx", import.meta.url), "utf8");
const panesSource = () => readFileSync(new URL("./PinnedPanes.tsx", import.meta.url), "utf8");
const appSource = () => readFileSync(new URL("../App.tsx", import.meta.url), "utf8");
const stylesSource = () => readFileSync(new URL("../styles.css", import.meta.url), "utf8");

test("the rail exposes a pin toggle and clickable layer chips per service", () => {
  const source = railSource();

  expect(source).toContain("onTogglePin");
  expect(source).toContain('aria-pressed={isPinned(service.service_key)}');
  expect(source).toContain("onLayer(service.service_key, name)");
  // Layer chips are buttons (drill down to a layer), not passive spans.
  expect(source).toContain('class="layer-chip"');
  expect(source).toMatch(/<button[^>]*\n?\s*type="button"\n?\s*class="layer-chip"/);
});

test("pinned panes are ambient monitors: newest first, interaction promotes to focus", () => {
  const source = panesSource();

  expect(source).toContain("pinned-strip");
  expect(source).toContain(".slice(-80).reverse()"); // newest activity visible without scrolling
  expect(source).toContain("onPromote(serviceKey, event.idText)");
  expect(source).toContain("onPromote(serviceKey, null)");
  expect(source).toContain("droppedFrames"); // gap truncation surfaced per pane
});

test("App wires pinning + layer drill-down into hub mode inside the stage split", () => {
  const source = appSource();

  expect(source).toContain("<PinnedPanes");
  expect(source).toContain('class="stage-split"');
  expect(source).toContain("onTogglePin={(serviceKey) =>");
  // A layer chip focuses the service AND filters the trace to that layer.
  expect(source).toContain("setSearch(layerName)");
});

test("the pinned-pane surfaces are styled with the token system", () => {
  const source = stylesSource();

  expect(source).toContain(".stage-split {");
  expect(source).toContain(".pinned-pane {");
  expect(source).toContain(".pin-btn.pinned {");
  expect(source).toContain("button.layer-chip:hover {");
});
