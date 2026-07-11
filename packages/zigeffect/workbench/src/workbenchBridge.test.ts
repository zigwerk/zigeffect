import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { estateAccessState, loadPayloadFromBridge, parseWorkbenchLogSnapshot, requestEstateScan } from "./workbenchBridge";

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

test("loadPayloadFromBridge can load the graph visual debugging development sample", async () => {
  const payload = await loadPayloadFromBridge(
    {},
    async (sampleName) => readFileSync(new URL(`../public/${sampleName}`, import.meta.url), "utf8"),
    "?sample=visual-graph",
  );

  expect(payload.session?.artifact_path).toBe("sample-visual-graph-debugging.json");
  expect(payload.artifactJson).toContain("Project.v1");
});

test("loadPayloadFromBridge can load the generated Ziac global sample", async () => {
  const payload = await loadPayloadFromBridge(
    {},
    async (sampleName) => readFileSync(new URL(`../public/${sampleName}`, import.meta.url), "utf8"),
    "?sample=ziac",
  );

  expect(payload.session?.artifact_path).toBe("sample-ziac-global.json");
  expect(payload.artifactJson).toContain("ziac.visual.v1");
  expect(payload.artifactJson).toContain("gcp.compute.GlobalForwardingRule");
});

test("loadPayloadFromBridge can load the grouped Ziac permission sample", async () => {
  const payload = await loadPayloadFromBridge(
    {},
    async (sampleName) => JSON.stringify({ schema: sampleName }),
    "?sample=ziac-permissions",
  );

  expect(payload.artifactJson).toBe(JSON.stringify({ schema: "sample-ziac-permissions.json" }));
  expect(payload.session?.artifact_path).toBe("sample-ziac-permissions.json");
});

test("loadPayloadFromBridge can load the connected existing-estate sample", async () => {
  const payload = await loadPayloadFromBridge(
    {},
    async (sampleName) => readFileSync(new URL(`../public/${sampleName}`, import.meta.url), "utf8"),
    "?sample=ziac-estate",
  );

  expect(payload.session?.artifact_path).toBe("sample-ziac-estate.json");
  expect(estateAccessState(payload.session)).toMatchObject({ ready: true, projectId: "acme-foundation-prod" });
  expect(payload.artifactJson).toContain('"ownership": "observed"');
  expect(payload.artifactJson).toContain("gcp.sql.Instance");
});

test("loadPayloadFromBridge can load the local dev session sample", async () => {
  const payload = await loadPayloadFromBridge(
    {},
    async (sampleName) => readFileSync(new URL(`../public/${sampleName}`, import.meta.url), "utf8"),
    "?sample=dev-session",
  );

  expect(payload.session?.artifact_path).toBe("sample-dev-session.json");
  expect(payload.artifactJson).toContain("zigeffect.causal.dev-session.v1");
  expect(payload.artifactJson).toContain("Claude Code");
});

test("loadPayloadFromBridge can load the statechart and actor development sample", async () => {
  const payload = await loadPayloadFromBridge(
    {},
    async (sampleName) => readFileSync(new URL(`../public/${sampleName}`, import.meta.url), "utf8"),
    "?sample=statechart",
  );

  expect(payload.session?.artifact_path).toBe("sample-statechart-workbench.json");
  expect(payload.artifactJson).toContain("zigeffect.statechart.definition.v1");
  expect(payload.artifactJson).toContain("agent.research-review");
});

test("workbench HTML loads the WebUI bridge before the Solid bundle", () => {
  const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
  const webuiScript = html.indexOf('src="/webui.js"');
  const appModule = html.indexOf('type="module"');

  expect(webuiScript).toBeGreaterThan(-1);
  expect(appModule).toBeGreaterThan(-1);
  expect(webuiScript).toBeLessThan(appModule);
});

test("estate access fails closed until Google identity Pro entitlement and GCP connection are ready", () => {
  expect(estateAccessState(null)).toMatchObject({ ready: false, reason: "google_sign_in_required" });
  expect(estateAccessState({ estate_access: {
    identity_provider: "google",
    authenticated: true,
    entitlement: "none",
    connection: "disconnected",
  } })).toMatchObject({ ready: false, reason: "pro_required" });
  expect(estateAccessState({ estate_access: {
    identity_provider: "google",
    authenticated: true,
    entitlement: "pro",
    connection: "disconnected",
  } })).toMatchObject({ ready: false, reason: "gcp_connection_required" });
  expect(estateAccessState({ estate_access: {
    identity_provider: "google",
    authenticated: true,
    entitlement: "pro",
    connection: "connected",
    project_id: "acme-foundation-prod",
    last_scan_millis: 1783764000000,
  } })).toEqual({
    ready: true,
    reason: "ready",
    projectId: "acme-foundation-prod",
    lastScanMillis: 1783764000000,
  });
});

test("estate access rejects credential-shaped session data", () => {
  expect(estateAccessState({ estate_access: {
    identity_provider: "google",
    authenticated: true,
    entitlement: "pro",
    connection: "connected",
    project_id: "acme-foundation-prod",
    last_scan_millis: 1783764000000,
    access_token: "must-not-enter-workbench",
  } })).toMatchObject({ ready: false, reason: "invalid_access_projection" });
});

test("estate refresh calls the host scanner and accepts only a mutation-isolated receipt", async () => {
  const calls: string[] = [];
  const result = await requestEstateScan({
    webui: {
      call: async (name: string) => {
        calls.push(name);
        return JSON.stringify({
          schema: "ziac.estate-scan-receipt.v1",
          project_id: "acme-foundation-prod",
          artifact_path: "estate.json",
          resources: 17,
          edges: 20,
          pages: 2,
          ownership: "observed",
          mutation_authorized: false,
          observed_at_millis: 1783764000000,
        });
      },
    },
  });

  expect(calls).toEqual(["ziac_scan_estate"]);
  expect(result).toEqual({ ok: true, resources: 17, projectId: "acme-foundation-prod" });
  expect(await requestEstateScan({
    ziac_scan_estate: async () => JSON.stringify({
      schema: "ziac.estate-scan-receipt.v1",
      mutation_authorized: true,
      access_token: "must-not-enter-workbench",
    }),
  })).toMatchObject({ ok: false });
});

test("live Ziac JSONL logs normalize into a bounded Workbench session snapshot", () => {
  const snapshot = parseWorkbenchLogSnapshot([
    JSON.stringify({
      schema: "ziac.log.v1",
      sequence: 7,
      event_id: "build-ready",
      parent_event_id: null,
      timestamp_millis: 10,
      source: "compiler",
      severity: "info",
      message: "generation compiled",
      dropped_count: 2,
      suppressed_count: 1,
    }),
    JSON.stringify({
      schema: "ziac.log.v1",
      sequence: 8,
      event_id: "revision-ready",
      parent_event_id: "build-ready",
      timestamp_millis: 12,
      source: "cloud_run",
      severity: "warn",
      message: "revision ready with warning",
      resource_id: "gcp.run.Service.europe-west1.api",
      region: "europe-west1",
      trace_id: "trace-8",
      dropped_count: 2,
      suppressed_count: 1,
    }),
  ].join("\n"));

  expect(snapshot?.log_summary).toEqual({ retained: 2, dropped: 2, suppressed: 1 });
  expect(snapshot?.logs?.map((event) => event.event_id)).toEqual(["build-ready", "revision-ready"]);
  expect(snapshot?.logs?.[1]?.resource_id).toBe("gcp.run.Service.europe-west1.api");
});

test("live Ziac log snapshots reject malformed and credential-shaped evidence", () => {
  expect(parseWorkbenchLogSnapshot('{"schema":"other","event_id":"bad"}')).toBeNull();
  expect(parseWorkbenchLogSnapshot(JSON.stringify({
    schema: "ziac.log.v1",
    sequence: 1,
    event_id: "secret",
    timestamp_millis: 1,
    source: "process",
    severity: "error",
    message: "authorization=Bearer must-not-enter-workbench",
    dropped_count: 0,
    suppressed_count: 0,
  }))).toBeNull();
});
