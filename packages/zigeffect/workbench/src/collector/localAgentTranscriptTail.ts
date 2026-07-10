import type { LocalDevAgentKind } from "../causalArtifact";
import {
  parseLocalDevSessionEventMessage,
  type LocalDevSessionEvent,
} from "../localDevSessionFeed";
import { postLocalAgentEvent } from "./localAgentRuntime";

export type LocalAgentTranscriptAgent = {
  agentId: string;
  agentKind: LocalDevAgentKind;
  agentLabel: string;
};

export type LocalAgentTranscriptAdapter = (
  line: string,
  agent: LocalAgentTranscriptAgent,
  sequence: number,
) => LocalDevSessionEvent | readonly LocalDevSessionEvent[] | null;

export type LocalAgentTranscriptTailOptions = LocalAgentTranscriptAgent & {
  agentEventsUrl: string;
  adapter?: LocalAgentTranscriptAdapter;
  fetcher?: typeof fetch;
  sequenceStart?: number;
};

export type LocalAgentTranscriptTailSummary = {
  lines: number;
  turns: number;
  ignored: number;
  posted: number;
  lastSequence: number;
};

type UnknownRecord = Record<string, unknown>;

export function parseLocalAgentTranscriptLine(
  line: string,
  agent: LocalAgentTranscriptAgent,
  sequence: number,
  adapter?: LocalAgentTranscriptAdapter,
): LocalDevSessionEvent | null {
  return parseLocalAgentTranscriptEvents(line, agent, sequence, adapter)[0] ?? null;
}

export function parseLocalAgentTranscriptEvents(
  line: string,
  agent: LocalAgentTranscriptAgent,
  sequence: number,
  adapter?: LocalAgentTranscriptAdapter,
): LocalDevSessionEvent[] {
  const trimmed = line.trim();
  if (trimmed.length === 0) {
    return [];
  }

  const adapted = adapter?.(trimmed, agent, sequence);
  if (adapted) {
    const candidates = Array.isArray(adapted) ? adapted : [adapted];
    const normalized = candidates
      .map((event, index) => parseLocalDevSessionEventMessage(JSON.stringify({
        ...event,
        sequence: sequence + index,
      })))
      .filter((event): event is LocalDevSessionEvent => event !== null);
    if (normalized.length > 0) {
      return normalized;
    }
  }
  const event = eventFromJsonLine(trimmed, agent, sequence) ?? eventFromTaggedLine(trimmed, agent, sequence);
  if (!event) {
    return [];
  }
  const normalized = parseLocalDevSessionEventMessage(JSON.stringify(event));
  return normalized ? [normalized] : [];
}

export async function runLocalAgentTranscriptTail(
  stream: ReadableStream<Uint8Array>,
  options: LocalAgentTranscriptTailOptions,
): Promise<LocalAgentTranscriptTailSummary> {
  const reader = stream.getReader();
  const decoder = new TextDecoder();
  const sequenceStart = options.sequenceStart ?? 0;
  let buffer = "";
  let lines = 0;
  let turns = 0;
  let ignored = 0;
  let posted = 0;
  let lastSequence = sequenceStart;

  async function processLine(line: string): Promise<void> {
    if (line.trim().length === 0) {
      return;
    }
    lines += 1;
    const sequence = lastSequence + 1;
    const events = parseLocalAgentTranscriptEvents(line, options, sequence, options.adapter);
    lastSequence += Math.max(1, events.length);
    if (events.length === 0) {
      ignored += 1;
      return;
    }
    turns += events.length;
    for (const event of events) {
      await postLocalAgentEvent(options.agentEventsUrl, event, options.fetcher);
      posted += 1;
    }
  }

  while (true) {
    const { done, value } = await reader.read();
    if (done) {
      break;
    }
    buffer += decoder.decode(value, { stream: true });
    const parts = buffer.split(/\r?\n/);
    buffer = parts.pop() ?? "";
    for (const part of parts) {
      await processLine(part);
    }
  }

  buffer += decoder.decode();
  await processLine(buffer);

  return {
    lines,
    turns,
    ignored,
    posted,
    lastSequence,
  };
}

function eventFromJsonLine(
  line: string,
  agent: LocalAgentTranscriptAgent,
  sequence: number,
): Partial<LocalDevSessionEvent> | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(line) as unknown;
  } catch {
    return null;
  }
  if (!isRecord(parsed) || !looksLikeTurnRecord(parsed)) {
    return null;
  }

  return {
    sequence,
    kind: "agent_turn",
    agent_id: textValue(parsed.agent_id ?? parsed.agentId, agent.agentId),
    agent_kind: agentKindValue(parsed.agent_kind ?? parsed.agentKind ?? parsed.kind, agent.agentKind),
    agent_label: textValue(parsed.agent_label ?? parsed.agentLabel, agent.agentLabel),
    turn_id: textValue(parsed.turn_id ?? parsed.turnId ?? parsed.id, `${agent.agentId}-${sequence}`),
    role: roleValue(parsed.role),
    status: textValue(parsed.status, "completed"),
    summary: optionalText(parsed.summary ?? parsed.value ?? parsed.message),
    input: optionalText(parsed.input ?? parsed.prompt),
    output: optionalText(parsed.output ?? parsed.response ?? parsed.content),
    artifact_path: optionalText(parsed.artifact_path ?? parsed.artifactPath),
  };
}

function eventFromTaggedLine(
  line: string,
  agent: LocalAgentTranscriptAgent,
  sequence: number,
): Partial<LocalDevSessionEvent> | null {
  const match = /^(user|assistant|tool|system)\s*:\s*(.+)$/i.exec(line);
  if (!match) {
    return null;
  }
  const role = roleValue(match[1]);
  const text = match[2]!.trim();
  return {
    sequence,
    kind: "agent_turn",
    agent_id: agent.agentId,
    agent_kind: agent.agentKind,
    agent_label: agent.agentLabel,
    turn_id: `${agent.agentId}-${sequence}`,
    role,
    status: "completed",
    summary: text,
    input: role === "user" ? text : undefined,
    output: role === "user" ? undefined : text,
  };
}

function looksLikeTurnRecord(record: UnknownRecord): boolean {
  if (textValue(record.kind, "") === "agent_turn") {
    return true;
  }
  if (textValue(record.type, "") === "turn") {
    return true;
  }
  return (
    record.role !== undefined ||
    record.summary !== undefined ||
    record.input !== undefined ||
    record.output !== undefined ||
    record.prompt !== undefined ||
    record.response !== undefined
  );
}

function agentKindValue(value: unknown, fallback: LocalDevAgentKind): LocalDevAgentKind {
  const kind = textValue(value, fallback);
  if (kind === "codex" || kind === "claude-code" || kind === "zigeffect" || kind === "human") {
    return kind;
  }
  return fallback;
}

function roleValue(value: unknown): LocalDevSessionEvent["role"] {
  const role = textValue(value, "assistant");
  if (role === "user" || role === "assistant" || role === "tool" || role === "system") {
    return role;
  }
  return "unknown";
}

function optionalText(value: unknown): string | undefined {
  const text = textValue(value, "");
  return text.length > 0 ? text : undefined;
}

function textValue(value: unknown, fallback: string): string {
  if (typeof value === "string") {
    return value.length > 0 ? value : fallback;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }
  if (typeof value === "boolean") {
    return String(value);
  }
  return fallback;
}

function isRecord(value: unknown): value is UnknownRecord {
  return typeof value === "object" && value !== null;
}
