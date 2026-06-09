import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { loadPayloadFromBridge } from "./workbenchBridge";

test("loadPayloadFromBridge loads artifact and session through webui.call", async () => {
  const artifactJson = JSON.stringify({
    schema: "zigeffect.causal.v1",
    schema_version: 1,
    event_taxonomy_version: 1,
    events: [{ id: 1, kind: "run_started", label: "dogfood run" }],
  });
  const sessionJson = JSON.stringify({
    schema: "zigeffect.causal.workbench-session.v1",
    artifact_path: ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
    read_only: true,
  });
  const calls: string[] = [];

  const payload = await loadPayloadFromBridge(
    {
      webui: {
        call: async (name: string) => {
          calls.push(name);
          if (name === "zigeffect_load_session") return sessionJson;
          if (name === "zigeffect_load_artifact") return artifactJson;
          throw new Error(`unexpected bridge call: ${name}`);
        },
      },
    },
    async () => {
      throw new Error("sample artifact should not be loaded when WebUI bridge is available");
    },
  );

  expect(calls).toEqual(["zigeffect_load_session", "zigeffect_load_artifact"]);
  expect(payload.artifactJson).toBe(artifactJson);
  expect(payload.session?.artifact_path).toBe(".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json");
});

test("loadPayloadFromBridge can load the chain development sample", async () => {
  const payload = await loadPayloadFromBridge(
    {},
    async (sampleName) => JSON.stringify({ schema: sampleName }),
    "?sample=chain",
  );

  expect(payload.artifactJson).toBe(JSON.stringify({ schema: "sample-chain-artifact.json" }));
  expect(payload.session?.artifact_path).toBe("sample-chain-artifact.json");
});

test("workbench HTML loads the WebUI bridge before the Solid bundle", () => {
  const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
  const webuiScript = html.indexOf('src="/webui.js"');
  const appModule = html.indexOf('type="module"');

  expect(webuiScript).toBeGreaterThan(-1);
  expect(appModule).toBeGreaterThan(-1);
  expect(webuiScript).toBeLessThan(appModule);
});
