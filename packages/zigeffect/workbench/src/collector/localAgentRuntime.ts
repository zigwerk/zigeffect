import type { LocalDevAgentKind } from "../causalArtifact";
import {
  parseLocalDevSessionEventMessage,
  type LocalDevSessionEvent,
} from "../localDevSessionFeed";

export type LocalAgentRuntimeTool = {
  id: string;
  kind: LocalDevAgentKind;
  label: string;
  command: string[];
  cwd?: string;
  task?: string;
  checkLabel?: string;
};

export type LocalAgentRuntimeResult = {
  toolId: string;
  exitCode: number;
  stdout: string;
  stderr: string;
};

export type LocalAgentRuntimeRunner = {
  run: (tool: LocalAgentRuntimeTool) => Promise<LocalAgentRuntimeResult>;
};

export type LocalAgentRuntimeOptions = {
  agentEventsUrl: string;
  fetcher?: typeof fetch;
  runner?: LocalAgentRuntimeRunner;
  failFast?: boolean;
};

export type LocalAgentRuntimeSummary = {
  tools: number;
  attempted: number;
  passed: number;
  failed: number;
  postedEvents: number;
  stoppedEarly: boolean;
};

export async function postLocalAgentEvent(
  url: string,
  event: LocalDevSessionEvent,
  fetcher: typeof fetch = fetch,
): Promise<LocalDevSessionEvent> {
  const normalized = parseLocalDevSessionEventMessage(JSON.stringify(event));
  if (!normalized) {
    throw new Error(`invalid local agent event: ${event.kind}`);
  }
  const response = await fetcher(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(normalized),
  });
  if (!response.ok) {
    throw new Error(`local agent event rejected: ${response.status}`);
  }
  return normalized;
}

export const bunLocalAgentRunner: LocalAgentRuntimeRunner = {
  async run(tool) {
    const [command, ...args] = tool.command;
    if (!command) {
      throw new Error(`tool ${tool.id} has no command`);
    }

    const process = Bun.spawn([command, ...args], {
      cwd: tool.cwd,
      stdout: "pipe",
      stderr: "pipe",
    });
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(process.stdout).text(),
      new Response(process.stderr).text(),
      process.exited,
    ]);

    return {
      toolId: tool.id,
      exitCode,
      stdout,
      stderr,
    };
  },
};

export async function runLocalAgentRuntime(
  tools: readonly LocalAgentRuntimeTool[],
  options: LocalAgentRuntimeOptions,
): Promise<LocalAgentRuntimeSummary> {
  const runner = options.runner ?? bunLocalAgentRunner;
  let sequence = 0;
  let attempted = 0;
  let passed = 0;
  let failed = 0;
  let postedEvents = 0;
  let stoppedEarly = false;

  async function emit(event: Omit<LocalDevSessionEvent, "sequence">): Promise<void> {
    sequence += 1;
    await postLocalAgentEvent(options.agentEventsUrl, { sequence, ...event }, options.fetcher);
    postedEvents += 1;
  }

  for (const tool of tools) {
    attempted += 1;
    await emit({
      kind: "agent_status",
      agent_id: tool.id,
      agent_kind: tool.kind,
      agent_label: tool.label,
      status: "running",
      task: tool.task,
    });

    let toolFailed = false;
    try {
      const result = await runner.run(tool);
      toolFailed = result.exitCode !== 0;
      const detail = resultDetail(result);
      await emit({
        kind: "check_result",
        label: tool.checkLabel ?? tool.label,
        command: commandText(tool.command),
        status: toolFailed ? "fail" : "pass",
        detail,
      });
    } catch (error) {
      toolFailed = true;
      const detail = errorDetail(error);
      await emit({
        kind: "warning",
        value: `${tool.label} failed before exit: ${detail}`,
      });
      await emit({
        kind: "check_result",
        label: tool.checkLabel ?? tool.label,
        command: commandText(tool.command),
        status: "fail",
        detail,
      });
    }

    if (toolFailed) {
      failed += 1;
      await emit({
        kind: "agent_status",
        agent_id: tool.id,
        agent_kind: tool.kind,
        agent_label: tool.label,
        status: "failed",
        task: tool.task,
      });
      if (options.failFast) {
        stoppedEarly = true;
        break;
      }
    } else {
      passed += 1;
      await emit({
        kind: "agent_status",
        agent_id: tool.id,
        agent_kind: tool.kind,
        agent_label: tool.label,
        status: "done",
        task: tool.task,
      });
    }
  }

  return {
    tools: tools.length,
    attempted,
    passed,
    failed,
    postedEvents,
    stoppedEarly,
  };
}

function resultDetail(result: LocalAgentRuntimeResult): string {
  const preferred = result.exitCode === 0
    ? firstNonEmpty(result.stdout, result.stderr)
    : firstNonEmpty(result.stderr, result.stdout);
  return preferred.length > 0 ? preferred : `exit ${result.exitCode}`;
}

function firstNonEmpty(...values: string[]): string {
  for (const value of values) {
    const trimmed = value.trim();
    if (trimmed.length > 0) return trimmed;
  }
  return "";
}

function commandText(command: readonly string[]): string {
  return command.join(" ");
}

function errorDetail(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;
  return "unknown runtime error";
}
