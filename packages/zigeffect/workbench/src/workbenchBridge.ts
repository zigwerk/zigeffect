export type WorkbenchSession = {
  schema?: string;
  artifact_path?: string;
  artifact_bytes?: number;
  read_only?: boolean;
  warnings?: string[];
};

export type LoadedPayload = {
  artifactJson: string;
  session: WorkbenchSession | null;
};

type WebuiApi = {
  call?: (name: string, ...args: unknown[]) => string | Promise<string>;
  isConnected?: () => boolean;
};

export type BridgeWindow = {
  webui?: WebuiApi;
  zigeffect_load_artifact?: () => string | Promise<string>;
  zigeffect_load_session?: () => string | Promise<string>;
};

type BridgeFunctionName = "zigeffect_load_artifact" | "zigeffect_load_session";
type SampleArtifactLoader = (sampleName: string) => Promise<string>;

export async function loadPayload(): Promise<LoadedPayload> {
  const bridge = window as BridgeWindow;
  await ensureWebuiScript();
  await waitForWebuiBridge(bridge);
  return loadPayloadFromBridge(bridge, loadSampleArtifact);
}

export async function loadPayloadFromBridge(
  bridge: BridgeWindow,
  loadSample: SampleArtifactLoader = loadSampleArtifact,
  search?: string,
): Promise<LoadedPayload> {
  const session = await loadSession(bridge);
  const artifactJson = await callBridgeFunction(bridge, "zigeffect_load_artifact");

  if (artifactJson !== null) {
    return { artifactJson, session };
  }

  const sampleName = sampleNameFromSearch(search ?? currentSearch());

  return {
    artifactJson: await loadSample(sampleName),
    session: session ?? {
      schema: "zigeffect.causal.workbench-session.v1",
      artifact_path: sampleName,
      read_only: true,
      warnings: ["development sample artifact"],
    },
  };
}

async function loadSession(bridge: BridgeWindow): Promise<WorkbenchSession | null> {
  const sessionJson = await callBridgeFunction(bridge, "zigeffect_load_session");
  if (sessionJson === null) {
    return null;
  }

  try {
    return JSON.parse(sessionJson) as WorkbenchSession;
  } catch {
    return {
      schema: "zigeffect.causal.workbench-session.v1",
      read_only: true,
      warnings: ["workbench session bridge returned invalid JSON"],
    };
  }
}

async function callBridgeFunction(bridge: BridgeWindow, name: BridgeFunctionName): Promise<string | null> {
  if (typeof bridge.webui?.call === "function") {
    return bridge.webui.call(name);
  }

  const direct = bridge[name];
  if (typeof direct === "function") {
    return direct();
  }

  return null;
}

function currentSearch(): string {
  return typeof window === "undefined" ? "" : window.location.search;
}

function sampleNameFromSearch(search: string): string {
  const params = new URLSearchParams(search);
  const sample = params.get("sample");
  if (sample === "chain") return "sample-chain-artifact.json";
  if (sample === "app-audit") return "sample-app-remediation-audit.json";
  if (sample === "app-policy") return "sample-app-policy-decision.json";
  if (sample === "app-proposal") return "sample-app-patch-proposal.json";
  if (sample === "app-review") return "sample-app-human-review.json";
  if (sample === "app-readiness") return "sample-app-application-readiness.json";
  if (sample === "app-application") return "sample-app-application.json";
  if (sample === "visual-graph") return "sample-visual-graph-debugging.json";
  return "sample-artifact.json";
}

async function loadSampleArtifact(sampleName: string): Promise<string> {
  const response = await fetch(`./${sampleName}`);
  return response.text();
}

async function ensureWebuiScript(): Promise<void> {
  const existing = document.querySelector<HTMLScriptElement>('script[data-zigeffect-webui="true"]');
  if (existing) {
    return;
  }

  await new Promise<void>((resolve) => {
    const script = document.createElement("script");
    script.src = "/webui.js";
    script.dataset.zigeffectWebui = "true";
    script.onload = () => resolve();
    script.onerror = () => resolve();
    document.head.append(script);
  });
}

async function waitForWebuiBridge(bridge: BridgeWindow, timeoutMs = 1000): Promise<void> {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    if (typeof bridge.webui?.call === "function") {
      if (typeof bridge.webui.isConnected !== "function" || bridge.webui.isConnected()) {
        return;
      }
    }

    await new Promise((resolve) => setTimeout(resolve, 25));
  }
}
