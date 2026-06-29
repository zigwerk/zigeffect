import { expect, test } from "bun:test";
import type { LocalDevSessionEvent } from "../localDevSessionFeed";
import {
  bunLocalAgentRunner,
  runLocalAgentRuntime,
  type LocalAgentRuntimeRunner,
} from "./localAgentRuntime";

function eventCapture(events: LocalDevSessionEvent[]): typeof fetch {
  return (async (_input: RequestInfo | URL, init?: RequestInit) => {
    expect(init?.method).toBe("POST");
    events.push(JSON.parse(String(init?.body)) as LocalDevSessionEvent);
    return new Response(JSON.stringify({ ingested: 1 }), {
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

test("runLocalAgentRuntime posts redacted start, check, and done events in order", async () => {
  const events: LocalDevSessionEvent[] = [];
  const runner: LocalAgentRuntimeRunner = {
    async run(tool) {
      expect(tool.id).toBe("codex");
      return {
        toolId: tool.id,
        exitCode: 0,
        stdout: "checked token=sentinel-secret",
        stderr: "",
      };
    },
  };

  const summary = await runLocalAgentRuntime(
    [
      {
        id: "codex",
        kind: "codex",
        label: "Codex",
        command: ["codex", "--version"],
        task: "schema work password=sentinel-secret",
      },
    ],
    {
      agentEventsUrl: "http://collector.test/agent-events",
      fetcher: eventCapture(events),
      runner,
    },
  );

  expect(summary).toEqual({
    tools: 1,
    attempted: 1,
    passed: 1,
    failed: 0,
    postedEvents: 3,
    stoppedEarly: false,
  });
  expect(events.map((event) => event.sequence)).toEqual([1, 2, 3]);
  expect(events.map((event) => event.kind)).toEqual(["agent_status", "check_result", "agent_status"]);
  expect(events[0]).toMatchObject({
    agent_id: "codex",
    agent_kind: "codex",
    status: "running",
    task: "schema work password=<redacted>",
  });
  expect(events[1]).toMatchObject({
    kind: "check_result",
    label: "Codex",
    command: "codex --version",
    status: "pass",
    detail: "checked token=<redacted>",
  });
  expect(events[2]).toMatchObject({
    agent_id: "codex",
    status: "done",
  });
  expect(JSON.stringify(events)).not.toContain("sentinel-secret");
});

test("runLocalAgentRuntime records failures and continues by default", async () => {
  const events: LocalDevSessionEvent[] = [];
  const runner: LocalAgentRuntimeRunner = {
    async run(tool) {
      if (tool.id === "bad") {
        return {
          toolId: tool.id,
          exitCode: 2,
          stdout: "",
          stderr: "failed secret=sentinel-secret",
        };
      }
      return {
        toolId: tool.id,
        exitCode: 0,
        stdout: "ok",
        stderr: "",
      };
    },
  };

  const summary = await runLocalAgentRuntime(
    [
      { id: "bad", kind: "zigeffect", label: "zigeffect check", command: ["zig", "build", "test"] },
      { id: "good", kind: "claude-code", label: "Claude review", command: ["claude", "review"] },
    ],
    {
      agentEventsUrl: "http://collector.test/agent-events",
      fetcher: eventCapture(events),
      runner,
    },
  );

  expect(summary).toEqual({
    tools: 2,
    attempted: 2,
    passed: 1,
    failed: 1,
    postedEvents: 6,
    stoppedEarly: false,
  });
  expect(events.filter((event) => event.kind === "check_result").map((event) => event.status)).toEqual([
    "fail",
    "pass",
  ]);
  expect(events.filter((event) => event.kind === "agent_status").map((event) => event.status)).toEqual([
    "running",
    "failed",
    "running",
    "done",
  ]);
  expect(JSON.stringify(events)).not.toContain("sentinel-secret");
});

test("runLocalAgentRuntime honors failFast after a failed command", async () => {
  const events: LocalDevSessionEvent[] = [];
  let calls = 0;
  const runner: LocalAgentRuntimeRunner = {
    async run(tool) {
      calls += 1;
      return {
        toolId: tool.id,
        exitCode: tool.id === "bad" ? 1 : 0,
        stdout: "",
        stderr: tool.id === "bad" ? "nope" : "",
      };
    },
  };

  const summary = await runLocalAgentRuntime(
    [
      { id: "bad", kind: "zigeffect", label: "first", command: ["false"] },
      { id: "skipped", kind: "codex", label: "second", command: ["true"] },
    ],
    {
      agentEventsUrl: "http://collector.test/agent-events",
      fetcher: eventCapture(events),
      runner,
      failFast: true,
    },
  );

  expect(calls).toBe(1);
  expect(summary).toEqual({
    tools: 2,
    attempted: 1,
    passed: 0,
    failed: 1,
    postedEvents: 3,
    stoppedEarly: true,
  });
  expect(events.map((event) => event.sequence)).toEqual([1, 2, 3]);
});

test("runLocalAgentRuntime emits a warning for runner exceptions", async () => {
  const events: LocalDevSessionEvent[] = [];
  const runner: LocalAgentRuntimeRunner = {
    async run() {
      throw new Error("boom token=sentinel-secret");
    },
  };

  const summary = await runLocalAgentRuntime(
    [{ id: "codex", kind: "codex", label: "Codex", command: ["codex", "exec"] }],
    {
      agentEventsUrl: "http://collector.test/agent-events",
      fetcher: eventCapture(events),
      runner,
    },
  );

  expect(summary.failed).toBe(1);
  expect(events.map((event) => event.kind)).toEqual(["agent_status", "warning", "check_result", "agent_status"]);
  expect(events[1]).toMatchObject({
    kind: "warning",
    value: "Codex failed before exit: boom token=<redacted>",
  });
  expect(JSON.stringify(events)).not.toContain("sentinel-secret");
});

test("bunLocalAgentRunner executes a simple local command", async () => {
  const result = await bunLocalAgentRunner.run({
    id: "shell",
    kind: "other",
    label: "shell",
    command: ["sh", "-c", "printf ok"],
  });

  expect(result.toolId).toBe("shell");
  expect(result.exitCode).toBe(0);
  expect(result.stdout).toBe("ok");
  expect(result.stderr).toBe("");
});
