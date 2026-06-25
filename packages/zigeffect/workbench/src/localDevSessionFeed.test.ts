import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { deriveLocalDevSessionModel } from "./causalArtifact";
import {
  applyLocalDevSessionEvents,
  localDevSessionEventsFromJsonl,
  parseLocalDevSessionEventMessage,
} from "./localDevSessionFeed";

const sampleSession = JSON.parse(
  readFileSync(new URL("../public/sample-dev-session.json", import.meta.url), "utf8"),
);

test("localDevSessionEventsFromJsonl parses Codex and Claude Code adapter events", () => {
  const events = localDevSessionEventsFromJsonl(`
{"sequence":1,"kind":"agent_status","agent_id":"codex","agent_kind":"codex","agent_label":"Codex","status":"running","task":"editing src token=sentinel-secret"}
not json
{"sequence":2,"kind":"check_result","label":"bun run zigeffect:workbench:test","status":"pass","command":"bun run zigeffect:workbench:test","detail":"92 pass"}
{"sequence":3,"kind":"artifact_link","key":"codex_transcript","path":".zig-cache/causal-artifacts/codex-session.json"}
`);

  expect(events.map((event) => event.kind)).toEqual(["agent_status", "check_result", "artifact_link"]);
  expect(events[0]?.task).toContain("<redacted>");
  expect(JSON.stringify(events)).not.toContain("sentinel-secret");
});

test("parseLocalDevSessionEventMessage accepts one event and rejects junk", () => {
  const event = parseLocalDevSessionEventMessage(JSON.stringify({
    sequence: 4,
    kind: "agent_status",
    agent_id: "claude-code",
    agent_kind: "claude-code",
    agent_label: "Claude Code",
    status: "reviewing",
  }));

  expect(event?.agent_id).toBe("claude-code");
  expect(parseLocalDevSessionEventMessage("nope")).toBeNull();
  expect(parseLocalDevSessionEventMessage(JSON.stringify({ kind: "unknown" }))).toBeNull();
});

test("applyLocalDevSessionEvents updates local session agents checks artifacts and guardrails", () => {
  const base = deriveLocalDevSessionModel(sampleSession, { artifactPath: "sample-dev-session.json" });
  expect(base).not.toBeNull();

  const updated = applyLocalDevSessionEvents(base!, localDevSessionEventsFromJsonl(`
{"sequence":1,"kind":"agent_status","agent_id":"codex","agent_kind":"codex","agent_label":"Codex","status":"done","task":"implemented M75"}
{"sequence":2,"kind":"agent_status","agent_id":"claude-code","agent_kind":"claude-code","agent_label":"Claude Code","status":"reviewing","task":"reviewing local gate"}
{"sequence":3,"kind":"check_result","label":"local reliability gate","status":"pass","command":"bun run zigeffect:local-agent-gate","detail":"all local checks passed"}
{"sequence":4,"kind":"artifact_link","key":"agent_activity","path":".zig-cache/causal-artifacts/local-agent-activity.jsonl"}
{"sequence":5,"kind":"next_action","value":"handoff to another local agent with this receipt"}
{"sequence":6,"kind":"guardrail","value":"do not summarize unverified local checks as passing"}
`));

  expect(updated.agents.find((agent) => agent.id === "codex")?.status).toBe("done");
  expect(updated.agents.find((agent) => agent.id === "claude-code")?.status).toBe("reviewing");
  expect(updated.checks.find((check) => check.label === "local reliability gate")?.status).toBe("pass");
  expect(updated.artifacts.find((artifact) => artifact.key === "agent_activity")?.kind).toBe("jsonl");
  expect(updated.nextActions).toContain("handoff to another local agent with this receipt");
  expect(updated.guardrails).toContain("do not summarize unverified local checks as passing");
});

test("sample local agent adapter fixture applies to the dev-session sample", () => {
  const base = deriveLocalDevSessionModel(sampleSession, { artifactPath: "sample-dev-session.json" });
  const fixture = readFileSync(new URL("../public/sample-agent-activity.jsonl", import.meta.url), "utf8");
  const updated = applyLocalDevSessionEvents(base!, localDevSessionEventsFromJsonl(fixture));

  expect(updated.agents.find((agent) => agent.id === "codex")?.status).toBe("running");
  expect(updated.agents.find((agent) => agent.id === "claude-code")?.status).toBe("reviewing");
  expect(updated.checks.find((check) => check.label === "bun run zigeffect:workbench:test")?.status).toBe("pass");
  expect(updated.artifacts.find((artifact) => artifact.key === "agent_activity")?.kind).toBe("jsonl");
});
