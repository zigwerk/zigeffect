import type { LocalDevAgentKind } from "../causalArtifact";
import {
  parseLocalDevSessionEventMessage,
  redactLocalDevSessionText,
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

export type LocalAgentRuntimeArtifactStream = "stdout" | "stderr" | "error";

export type LocalAgentRuntimeArtifact = {
  key: string;
  toolId: string;
  stream: LocalAgentRuntimeArtifactStream;
  filename: string;
  content: string;
  mediaType: "text/plain";
};

export type LocalAgentRuntimeArtifactSink = {
  write: (artifact: LocalAgentRuntimeArtifact) => Promise<string>;
};

export type LocalAgentRuntimeOptions = {
  agentEventsUrl: string;
  fetcher?: typeof fetch;
  runner?: LocalAgentRuntimeRunner;
  artifactSink?: LocalAgentRuntimeArtifactSink;
  failFast?: boolean;
};

export type LocalAgentRuntimeSummary = {
  tools: number;
  attempted: number;
  passed: number;
  failed: number;
  artifacts: number;
  postedEvents: number;
  stoppedEarly: boolean;
};

type WrittenArtifact = LocalAgentRuntimeArtifact & {
  path: string;
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

export function bunLocalAgentArtifactSink(rootDir: string): LocalAgentRuntimeArtifactSink {
  const root = rootDir.replace(/\/+$/, "");
  return {
    async write(artifact) {
      const filename = safeArtifactFilename(artifact.filename);
      const path = `${root}/${filename}`;
      await Bun.write(path, artifact.content);
      return path;
    },
  };
}

export async function runLocalAgentRuntime(
  tools: readonly LocalAgentRuntimeTool[],
  options: LocalAgentRuntimeOptions,
): Promise<LocalAgentRuntimeSummary> {
  const runner = options.runner ?? bunLocalAgentRunner;
  let sequence = 0;
  let attempted = 0;
  let passed = 0;
  let failed = 0;
  let artifacts = 0;
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
      const writtenArtifacts = await writeResultArtifacts(tool, result, options.artifactSink);
      artifacts += writtenArtifacts.length;
      await emitArtifactLinks(writtenArtifacts);
      const detail = resultDetail(result);
      await emit({
        kind: "check_result",
        label: tool.checkLabel ?? tool.label,
        command: commandText(tool.command),
        status: toolFailed ? "fail" : "pass",
        detail,
        artifact_path: firstArtifactPath(writtenArtifacts),
      });
    } catch (error) {
      toolFailed = true;
      const detail = errorDetail(error);
      await emit({
        kind: "warning",
        value: `${tool.label} failed before exit: ${detail}`,
      });
      const writtenArtifacts = await writeErrorArtifacts(tool, detail, options.artifactSink);
      artifacts += writtenArtifacts.length;
      await emitArtifactLinks(writtenArtifacts);
      await emit({
        kind: "check_result",
        label: tool.checkLabel ?? tool.label,
        command: commandText(tool.command),
        status: "fail",
        detail,
        artifact_path: firstArtifactPath(writtenArtifacts),
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
    artifacts,
    postedEvents,
    stoppedEarly,
  };

  async function emitArtifactLinks(writtenArtifacts: readonly WrittenArtifact[]): Promise<void> {
    for (const artifact of writtenArtifacts) {
      await emit({
        kind: "artifact_link",
        key: artifact.key,
        path: artifact.path,
      });
    }
  }
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

async function writeResultArtifacts(
  tool: LocalAgentRuntimeTool,
  result: LocalAgentRuntimeResult,
  sink: LocalAgentRuntimeArtifactSink | undefined,
): Promise<WrittenArtifact[]> {
  if (!sink) return [];
  const artifacts: LocalAgentRuntimeArtifact[] = [];
  if (result.stdout.trim().length > 0) {
    artifacts.push(runtimeArtifact(tool, "stdout", result.stdout));
  }
  if (result.stderr.trim().length > 0) {
    artifacts.push(runtimeArtifact(tool, "stderr", result.stderr));
  }
  return writeArtifacts(artifacts, sink);
}

async function writeErrorArtifacts(
  tool: LocalAgentRuntimeTool,
  detail: string,
  sink: LocalAgentRuntimeArtifactSink | undefined,
): Promise<WrittenArtifact[]> {
  if (!sink || detail.trim().length === 0) return [];
  return writeArtifacts([runtimeArtifact(tool, "error", detail)], sink);
}

async function writeArtifacts(
  artifacts: readonly LocalAgentRuntimeArtifact[],
  sink: LocalAgentRuntimeArtifactSink,
): Promise<WrittenArtifact[]> {
  const written: WrittenArtifact[] = [];
  for (const artifact of artifacts) {
    const path = await sink.write(artifact);
    written.push({ ...artifact, path });
  }
  return written;
}

function runtimeArtifact(
  tool: LocalAgentRuntimeTool,
  stream: LocalAgentRuntimeArtifactStream,
  content: string,
): LocalAgentRuntimeArtifact {
  return {
    key: `${safeArtifactKey(tool.id)}_${stream}`,
    toolId: tool.id,
    stream,
    filename: `${safeArtifactFilename(tool.id)}-${stream}.txt`,
    content: redactLocalDevSessionText(content.trim()),
    mediaType: "text/plain",
  };
}

function firstArtifactPath(writtenArtifacts: readonly WrittenArtifact[]): string | undefined {
  return writtenArtifacts[0]?.path;
}

function safeArtifactKey(value: string): string {
  const key = redactLocalDevSessionText(value)
    .toLowerCase()
    .replace(/[^a-z0-9_:-]+/g, "_")
    .replace(/^_+|_+$/g, "");
  return key.length > 0 ? key : "local_agent";
}

function safeArtifactFilename(value: string): string {
  const filename = redactLocalDevSessionText(value)
    .toLowerCase()
    .replace(/\.\.+/g, ".")
    .replace(/[^a-z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 96);
  if (filename.length === 0 || filename === "." || filename === "..") {
    return "artifact";
  }
  return filename;
}
