import type { LocalDevSessionEvent } from "../localDevSessionFeed";
import { parseLocalDevSessionEventMessage } from "../localDevSessionFeed";
import type { LocalAgentProcessTool } from "./localAgentProcessSupervisor";
import type {
  LocalAgentTranscriptAdapter,
  LocalAgentTranscriptAgent,
} from "./localAgentTranscriptTail";

type UnknownRecord = Record<string, unknown>;

export type NativeAgentProcessToolOptions = {
  id: string;
  prompt: string;
  label?: string;
  executable?: string;
  cwd?: string;
  task?: string;
  checkLabel?: string;
  extraArgs?: readonly string[];
};

const MAX_SNIPPET_LENGTH = 4096;
const TRUNCATION_MARKER = "... [truncated]";

export const codexTranscriptAdapter: LocalAgentTranscriptAdapter = (line, agent, sequence) => {
  const record = parseRecord(line);
  if (!record) return null;
  const type = textValue(record.type);

  if (type === "item.started" || type === "item.updated" || type === "item.completed") {
    const item = recordValue(record.item);
    if (!item) return null;
    return codexItemEvent(item, type, agent, sequence);
  }

  if (type === "turn.failed") {
    return normalizedTurn(agent, sequence, {
      turn_id: textValue(record.turn_id) || `codex-turn-failed-${sequence}`,
      role: "system",
      status: "failed",
      summary: "Codex turn failed",
      output: nestedText(record.error, "message") || textValue(record.message),
    });
  }

  if (type === "error") {
    return normalizedTurn(agent, sequence, {
      turn_id: textValue(record.id) || `codex-error-${sequence}`,
      role: "system",
      status: "failed",
      summary: "Codex stream error",
      output: textValue(record.message) || nestedText(record.error, "message"),
    });
  }

  return null;
};

export const claudeCodeTranscriptAdapter: LocalAgentTranscriptAdapter = (line, agent, sequence) => {
  const record = parseRecord(line);
  if (!record) return null;
  switch (textValue(record.type)) {
    case "system":
      return claudeSystemEvent(record, agent, sequence);
    case "assistant":
      return claudeAssistantEvent(record, agent, sequence);
    case "user":
      return claudeUserEvent(record, agent, sequence);
    case "result":
      return claudeResultEvent(record, agent, sequence);
    case "stream_event":
      return null;
    default:
      return null;
  }
};

export function codexLocalAgentProcessTool(
  options: NativeAgentProcessToolOptions,
): LocalAgentProcessTool {
  requirePrompt(options.prompt);
  return {
    id: options.id,
    kind: "codex",
    label: options.label ?? "Codex",
    command: [
      options.executable ?? "codex",
      "exec",
      "--json",
      ...(options.extraArgs ?? []),
      options.prompt,
    ],
    cwd: options.cwd,
    task: options.task,
    checkLabel: options.checkLabel,
    transcriptAdapter: codexTranscriptAdapter,
  };
}

export function claudeCodeLocalAgentProcessTool(
  options: NativeAgentProcessToolOptions,
): LocalAgentProcessTool {
  requirePrompt(options.prompt);
  return {
    id: options.id,
    kind: "claude-code",
    label: options.label ?? "Claude Code",
    command: [
      options.executable ?? "claude",
      "-p",
      options.prompt,
      "--output-format",
      "stream-json",
      "--verbose",
      ...(options.extraArgs ?? []),
    ],
    cwd: options.cwd,
    task: options.task,
    checkLabel: options.checkLabel,
    transcriptAdapter: claudeCodeTranscriptAdapter,
  };
}

function codexItemEvent(
  item: UnknownRecord,
  lifecycle: string,
  agent: LocalAgentTranscriptAgent,
  sequence: number,
): LocalDevSessionEvent | null {
  const itemType = textValue(item.type);
  const turnId = textValue(item.id) || `codex-item-${sequence}`;
  const status = codexItemStatus(item, lifecycle);
  switch (itemType) {
    case "agent_message": {
      const text = boundedText(item.text);
      if (!text) return null;
      return normalizedTurn(agent, sequence, {
        turn_id: turnId,
        role: "assistant",
        status,
        summary: summaryText(text),
        output: text,
      });
    }
    case "command_execution": {
      const command = boundedText(item.command);
      return normalizedTurn(agent, sequence, {
        turn_id: turnId,
        role: "tool",
        status,
        summary: command || "Command execution",
        input: command,
        output: boundedText(item.aggregated_output),
      });
    }
    case "file_change":
      return normalizedTurn(agent, sequence, {
        turn_id: turnId,
        role: "tool",
        status,
        summary: "File changes",
        input: boundedJson(item.changes),
      });
    case "mcp_tool_call": {
      const toolName = [textValue(item.server), textValue(item.tool)]
        .filter((value) => value.length > 0)
        .join("/");
      return normalizedTurn(agent, sequence, {
        turn_id: turnId,
        role: "tool",
        status,
        summary: toolName || "MCP tool call",
        input: boundedJson(item.arguments ?? item.input),
        output: boundedJson(item.result ?? item.error),
      });
    }
    case "collab_tool_call": {
      const tool = textValue(item.tool) || "unknown";
      return normalizedTurn(agent, sequence, {
        turn_id: turnId,
        role: "tool",
        status,
        summary: `Codex collaboration: ${tool}`,
        input: boundedJson({
          sender_thread_id: item.sender_thread_id,
          receiver_thread_ids: item.receiver_thread_ids,
          prompt: item.prompt,
        }),
        output: boundedJson(item.agents_states),
      });
    }
    case "web_search":
      return normalizedTurn(agent, sequence, {
        turn_id: turnId,
        role: "tool",
        status,
        summary: "Web search",
        input: boundedText(item.query),
      });
    case "reasoning": {
      const text = boundedText(item.text);
      if (!text) return null;
      return normalizedTurn(agent, sequence, {
        turn_id: turnId,
        role: "system",
        status,
        summary: summaryText(text),
        output: text,
      });
    }
    case "todo_list":
      return normalizedTurn(agent, sequence, {
        turn_id: turnId,
        role: "system",
        status,
        summary: "Plan update",
        output: boundedJson(item.items ?? item),
      });
    case "error":
      return normalizedTurn(agent, sequence, {
        turn_id: turnId,
        role: "system",
        status: "failed",
        summary: "Codex item error",
        output: boundedText(item.message ?? item.error),
      });
    default:
      return null;
  }
}

function codexItemStatus(
  item: UnknownRecord,
  lifecycle: string,
): "started" | "completed" | "failed" {
  const status = textValue(item.status);
  const exitCode = numericValue(item.exit_code);
  if (
    status === "failed" ||
    status === "error" ||
    status === "declined" ||
    (exitCode !== null && exitCode !== 0)
  ) {
    return "failed";
  }
  if (lifecycle === "item.completed" || status === "completed") {
    return "completed";
  }
  return "started";
}

function claudeSystemEvent(
  record: UnknownRecord,
  agent: LocalAgentTranscriptAgent,
  sequence: number,
): LocalDevSessionEvent | null {
  const subtype = textValue(record.subtype);
  const turnId = textValue(record.uuid) || `${agent.agentId}-system-${sequence}`;
  if (subtype === "init") {
    const model = textValue(record.model);
    const tools = stringArray(record.tools).join(", ");
    return normalizedTurn(agent, sequence, {
      turn_id: turnId,
      role: "system",
      status: "completed",
      summary: "Claude Code session initialized",
      output: boundedText([model && `model=${model}`, tools && `tools=${tools}`].filter(Boolean).join("; ")),
    });
  }
  if (subtype === "api_retry") {
    const attempt = numericValue(record.attempt);
    const maxRetries = numericValue(record.max_retries);
    return normalizedTurn(agent, sequence, {
      turn_id: turnId,
      role: "system",
      status: "started",
      summary: `Claude API retry ${attempt ?? "?"}/${maxRetries ?? "?"}`,
      output: boundedText(record.error),
    });
  }
  if (subtype === "plugin_install") {
    const status = textValue(record.status);
    return normalizedTurn(agent, sequence, {
      turn_id: turnId,
      role: "system",
      status: status === "failed" ? "failed" : status === "started" ? "started" : "completed",
      summary: `Claude plugin install: ${status || "update"}`,
      output: boundedText(record.error ?? record.name),
    });
  }
  return null;
}

function claudeAssistantEvent(
  record: UnknownRecord,
  agent: LocalAgentTranscriptAgent,
  sequence: number,
): LocalDevSessionEvent | readonly LocalDevSessionEvent[] | null {
  const message = recordValue(record.message);
  if (!message) return null;
  const blocks = recordArray(message.content);
  const events: LocalDevSessionEvent[] = [];
  const text = contentText(blocks);
  if (text) {
    appendTurn(events, normalizedTurn(agent, sequence + events.length, {
      turn_id: textValue(message.id) || textValue(record.uuid) || `${agent.agentId}-message-${sequence}`,
      role: "assistant",
      status: "completed",
      summary: summaryText(text),
      output: text,
    }));
  }

  for (const toolUse of blocks.filter((block) => textValue(block.type) === "tool_use")) {
    const name = textValue(toolUse.name) || "Claude tool call";
    appendTurn(events, normalizedTurn(agent, sequence + events.length, {
      turn_id: textValue(toolUse.id) || textValue(record.uuid) || `${agent.agentId}-tool-${sequence}`,
      role: "tool",
      status: "started",
      summary: name,
      input: boundedJson(toolUse.input),
    }));
  }

  return collapseTurns(events);
}

function claudeUserEvent(
  record: UnknownRecord,
  agent: LocalAgentTranscriptAgent,
  sequence: number,
): LocalDevSessionEvent | readonly LocalDevSessionEvent[] | null {
  const message = recordValue(record.message);
  if (!message) return null;
  const blocks = recordArray(message.content);
  const events: LocalDevSessionEvent[] = [];
  for (const toolResult of blocks.filter((block) => textValue(block.type) === "tool_result")) {
    const failed = toolResult.is_error === true;
    appendTurn(events, normalizedTurn(agent, sequence + events.length, {
      turn_id: textValue(toolResult.tool_use_id) || textValue(record.uuid) || `${agent.agentId}-result-${sequence}`,
      role: "tool",
      status: failed ? "failed" : "completed",
      summary: failed ? "Claude tool failed" : "Claude tool completed",
      output: claudeContentValue(toolResult.content),
    }));
  }
  if (events.length > 0) {
    return collapseTurns(events);
  }

  const text = contentText(blocks);
  if (!text) return null;
  return normalizedTurn(agent, sequence, {
    turn_id: textValue(record.uuid) || `${agent.agentId}-user-${sequence}`,
    role: "user",
    status: "completed",
    summary: summaryText(text),
    input: text,
  });
}

function claudeResultEvent(
  record: UnknownRecord,
  agent: LocalAgentTranscriptAgent,
  sequence: number,
): LocalDevSessionEvent | null {
  const subtype = textValue(record.subtype) || "unknown";
  const failed = record.is_error === true || subtype.includes("error") || subtype === "failed";
  return normalizedTurn(agent, sequence, {
    turn_id: textValue(record.uuid) || `${textValue(record.session_id) || agent.agentId}-result-${sequence}`,
    role: "assistant",
    status: failed ? "failed" : "completed",
    summary: `Claude Code result: ${subtype}`,
    output: boundedText(record.result) || boundedJson(record.structured_output),
  });
}

function appendTurn(
  events: LocalDevSessionEvent[],
  event: LocalDevSessionEvent | null,
): void {
  if (event) events.push(event);
}

function collapseTurns(
  events: readonly LocalDevSessionEvent[],
): LocalDevSessionEvent | readonly LocalDevSessionEvent[] | null {
  if (events.length === 0) return null;
  return events.length === 1 ? events[0]! : events;
}

function normalizedTurn(
  agent: LocalAgentTranscriptAgent,
  sequence: number,
  event: Omit<LocalDevSessionEvent, "sequence" | "kind" | "agent_id" | "agent_kind" | "agent_label">,
): LocalDevSessionEvent | null {
  return parseLocalDevSessionEventMessage(JSON.stringify({
    sequence,
    kind: "agent_turn",
    agent_id: agent.agentId,
    agent_kind: agent.agentKind,
    agent_label: agent.agentLabel,
    ...event,
  }));
}

function parseRecord(line: string): UnknownRecord | null {
  try {
    return recordValue(JSON.parse(line) as unknown);
  } catch {
    return null;
  }
}

function boundedText(value: unknown): string | undefined {
  const text = textValue(value);
  if (text.length === 0) return undefined;
  if (text.length <= MAX_SNIPPET_LENGTH) return text;
  return `${text.slice(0, MAX_SNIPPET_LENGTH - TRUNCATION_MARKER.length)}${TRUNCATION_MARKER}`;
}

function boundedJson(value: unknown): string | undefined {
  if (value === undefined || value === null) return undefined;
  try {
    return boundedText(JSON.stringify(value));
  } catch {
    return undefined;
  }
}

function summaryText(value: string): string {
  const firstLine = value.split(/\r?\n/, 1)[0]?.trim() ?? "";
  return firstLine.length <= 240 ? firstLine : `${firstLine.slice(0, 237)}...`;
}

function claudeContentValue(value: unknown): string | undefined {
  if (typeof value === "string") return boundedText(value);
  const blocks = recordArray(value);
  return contentText(blocks) || boundedJson(value);
}

function contentText(blocks: readonly UnknownRecord[]): string | undefined {
  const text = blocks
    .filter((block) => textValue(block.type) === "text")
    .map((block) => textValue(block.text))
    .filter((value) => value.length > 0)
    .join("\n");
  return boundedText(text);
}

function nestedText(value: unknown, key: string): string {
  return textValue(recordValue(value)?.[key]);
}

function textValue(value: unknown): string {
  if (typeof value === "string") return value;
  if (typeof value === "number" && Number.isFinite(value)) return String(value);
  if (typeof value === "boolean") return String(value);
  return "";
}

function numericValue(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map(textValue).filter((item) => item.length > 0);
}

function recordArray(value: unknown): UnknownRecord[] {
  if (!Array.isArray(value)) return [];
  return value.map(recordValue).filter((item): item is UnknownRecord => item !== null);
}

function recordValue(value: unknown): UnknownRecord | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as UnknownRecord
    : null;
}

function requirePrompt(prompt: string): void {
  if (prompt.trim().length === 0) {
    throw new Error("native agent process prompt must not be empty");
  }
}
