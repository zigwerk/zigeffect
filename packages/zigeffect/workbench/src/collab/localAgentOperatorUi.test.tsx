import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";

test("App consumes the ephemeral control bootstrap and passes it to collaboration", () => {
  const source = readFileSync(new URL("../App.tsx", import.meta.url), "utf8");

  expect(source).toContain("localAgentControlBootstrapFromLocation");
  expect(source).toContain("scrubLocalAgentControlTokenFragment");
  expect(source).toContain("window.history.replaceState");
  expect(source).toContain("operatorBootstrap={controlBootstrap}");
});

test("collaboration renders local control independently of artifact session state", () => {
  const source = readFileSync(new URL("./CollabBoard.tsx", import.meta.url), "utf8");
  const operator = source.indexOf("<LocalAgentOperatorPanel");
  const artifactGate = source.indexOf("when={props.session}");

  expect(operator).toBeGreaterThan(0);
  expect(artifactGate).toBeGreaterThan(operator);
});

test("operator UI exposes connection, approved launch, durable detail, stop, and policy states", () => {
  const source = readFileSync(new URL("./LocalAgentOperatorPanel.tsx", import.meta.url), "utf8");

  expect(source).toContain('type="password"');
  expect(source).toContain("createLocalAgentControlClient");
  expect(source).toContain("operator.startPolling()");
  expect(source).toContain("<select");
  expect(source).toContain("selectedTool()?.input");
  expect(source).toContain("operator.start(");
  expect(source).toContain("operator.stop(");
  expect(source).toContain("operator.selectSession(");
  expect(source).toContain("operator-mobile-tabs");
  expect(source).toContain('label="turns"');
  expect(source).toContain('label="events"');
  expect(source).toContain("Recovery interruption");
  expect(source).toContain("latestReceipt()");
  expect(source).toContain("RefreshCw");
  expect(source).toContain("Play");
  expect(source).toContain("Square");
  expect(source).not.toContain("JSON input");
});

test("operator styles define stable controls and a narrow-screen layout", () => {
  const source = readFileSync(new URL("../styles.css", import.meta.url), "utf8");

  expect(source).toContain(".local-operator");
  expect(source).toContain(".operator-icon-button");
  expect(source).toContain(".operator-session-list");
  expect(source).toContain(".operator-detail-metrics");
  expect(source).toMatch(/@media \(max-width: 720px\)[\s\S]*\.operator-workspace/);
});
