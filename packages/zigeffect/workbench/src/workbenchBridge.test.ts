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

test("loadPayloadFromBridge can load app remediation development samples", async () => {
  const samples: Array<[string, string]> = [
    ["?sample=app-audit", "sample-app-remediation-audit.json"],
    ["?sample=app-policy", "sample-app-policy-decision.json"],
    ["?sample=app-proposal", "sample-app-patch-proposal.json"],
    ["?sample=app-review", "sample-app-human-review.json"],
    ["?sample=app-readiness", "sample-app-application-readiness.json"],
    ["?sample=app-application", "sample-app-application.json"],
  ];

  for (const [search, expected] of samples) {
    const payload = await loadPayloadFromBridge(
      {},
      async (sampleName) => JSON.stringify({ schema: sampleName }),
      search,
    );

    expect(payload.artifactJson).toBe(JSON.stringify({ schema: expected }));
    expect(payload.session?.artifact_path).toBe(expected);
  }
});

test("loadPayloadFromBridge can load the live dashboard stream development sample", async () => {
  const payload = await loadPayloadFromBridge(
    {},
    async (sampleName) => JSON.stringify({ schema: sampleName }),
    "?sample=live",
  );

  expect(payload.artifactJson).toBe(JSON.stringify({ schema: "sample-live-dashboard-stream.json" }));
  expect(payload.session?.artifact_path).toBe("sample-live-dashboard-stream.json");
});

test("loadPayloadFromBridge can load the production telemetry retention sample", async () => {
  const payload = await loadPayloadFromBridge(
    {},
    async (sampleName) => {
      expect(sampleName).toBe("sample-production-telemetry-nendb-retention-fixtures.json");
      return JSON.stringify({ schema: "zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1" });
    },
    "?sample=production-telemetry",
  );

  expect(payload.session?.artifact_path).toBe("sample-production-telemetry-nendb-retention-fixtures.json");
  expect(payload.artifactJson).toContain("production-telemetry-nendb-retention-fixtures");
});

test("loadPayloadFromBridge can load the graph visual debugging development sample", async () => {
  const payload = await loadPayloadFromBridge(
    {},
    async (sampleName) => readFileSync(new URL(`../public/${sampleName}`, import.meta.url), "utf8"),
    "?sample=visual-graph",
  );

  expect(payload.session?.artifact_path).toBe("sample-visual-graph-debugging.json");
  expect(payload.artifactJson).toContain("Project.v1");
});

test("workbench HTML loads the WebUI bridge before the Solid bundle", () => {
  const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
  const webuiScript = html.indexOf('src="/webui.js"');
  const appModule = html.indexOf('type="module"');

  expect(webuiScript).toBeGreaterThan(-1);
  expect(appModule).toBeGreaterThan(-1);
  expect(webuiScript).toBeLessThan(appModule);
});
