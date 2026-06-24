// Live-attach collector — the WebSocket bridge between the engine and the
// workbench. The engine's `drainHubToNdjson` (CausalHubBackend → NDJSON) feeds
// this collector via `POST /ingest` (NDJSON body) or stdin (`engine | collector`);
// the collector maps each line to a `LiveFrame` and broadcasts it — ONE frame
// per WebSocket message — to every client connected at `ws://host/live`. The
// frontend's `webSocketLiveSource(ws://…/live)` (used by `?live=`) consumes it.
//
// RUNTIME BOUNDARY: this is LOCAL tooling, not a Cloudflare Worker handler, so it
// uses Bun-native `Bun.serve` (with WebSocket) per the project's runtime rule.

import type { Server, ServerWebSocket, WebSocketHandler } from "bun";
import { causalLineToFrame, type LiveFrame } from "./frame";
import type { LiveCommandFrame } from "../liveAttach";

export type Collector = {
  /** Bun.serve `fetch` handler: upgrades `/live` to WS, ingests `POST /ingest`. */
  fetch: (request: Request, server: Server<undefined>) => Response | Promise<Response> | undefined;
  /** Bun.serve `websocket` handlers tracking connected clients. */
  websocket: WebSocketHandler<undefined>;
  /** Map one engine NDJSON line → a frame, broadcast it, return it (or null). */
  ingestLine: (line: string) => LiveFrame | null;
  /** Ingest an NDJSON body; returns the number of frames broadcast. */
  ingestBody: (body: string) => number;
  /** Broadcast already-mapped LiveFrame JSON from a trusted engine host. */
  ingestFrame: (body: unknown) => LiveFrame | null;
  /** Validate and broadcast one policy-gated live command intent. */
  ingestCommand: (body: unknown) => LiveCommandFrame | null;
  /** Return command frames newer than the provided command sequence. */
  commandsSince: (afterSequence: number) => LiveCommandFrame[];
  /** Number of currently-connected WebSocket clients. */
  clientCount: () => number;
};

export function createCollector(): Collector {
  const clients = new Set<ServerWebSocket<undefined>>();
  const commandHistory: LiveCommandFrame[] = [];
  let sequence = 0;
  let commandSequence = 0;

  const WS_OPEN = 1; // WebSocket.OPEN
  function broadcast(frame: LiveFrame | LiveCommandFrame): void {
    const message = JSON.stringify(frame);
    for (const client of clients) {
      // Skip a socket that is closing/closed (it is removed on its `close`
      // callback, which may lag the client's close). `send` returns a status
      // (-1 closed / 0 backpressure / >0 bytes) rather than throwing; on a slow
      // subscriber a 0 means the frame is buffered by Bun, which is acceptable
      // for a best-effort live stream.
      if (client.readyState !== WS_OPEN) continue;
      client.send(message);
    }
  }

  function ingestLine(line: string): LiveFrame | null {
    const frame = causalLineToFrame(line, sequence + 1);
    if (!frame) return null;
    sequence += 1;
    broadcast(frame);
    return frame;
  }

  function ingestBody(body: string): number {
    let count = 0;
    for (const line of body.split("\n")) {
      if (ingestLine(line)) count += 1;
    }
    return count;
  }

  function safeFrameNumber(value: unknown): value is number {
    return typeof value === "number" && Number.isSafeInteger(value) && value >= 0;
  }

  function isFrameBody(value: unknown): value is LiveFrame {
    if (typeof value !== "object" || value === null) return false;
    const record = value as Record<string, unknown>;
    return (
      safeFrameNumber(record.sequence) &&
      safeFrameNumber(record.event_id) &&
      typeof record.event_kind === "string" &&
      typeof record.status === "string"
    );
  }

  function ingestFrame(body: unknown): LiveFrame | null {
    if (!isFrameBody(body)) return null;
    sequence = Math.max(sequence, body.sequence);
    broadcast(body);
    return body;
  }

  function ingestFrameBody(body: unknown): number | null {
    const frames = Array.isArray(body) ? body : [body];
    let count = 0;
    for (const frame of frames) {
      if (!ingestFrame(frame)) return null;
      count += 1;
    }
    return count;
  }

  function redactCommandText(value: string): string {
    return value
      .replace(/\b(authorization|proxy-authorization)\s*:\s*(bearer|basic)\s+[^;\s,]+/gi, "$1: $2 <redacted>")
      .replace(/\bcookie\s*:\s*[^,\n\r]+/gi, "Cookie: <redacted>")
      .replace(
        /\b(api[_-]?key|x-api-key|token|password|secret|session(?:_id)?|sid)\b\s*[:=]\s*("[^"]*"|'[^']*'|[^;\s,]+)/gi,
        "$1=<redacted>",
      );
  }

  function optionalNumber(record: Record<string, unknown>, key: string): number | null {
    const value = record[key];
    return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : null;
  }

  function ingestCommand(body: unknown): LiveCommandFrame | null {
    if (typeof body !== "object" || body === null) return null;
    const record = body as Record<string, unknown>;
    if (typeof record.kind !== "string" || record.kind.length === 0) return null;
    commandSequence += 1;
    const frame: LiveCommandFrame = {
      sequence: commandSequence,
      command_id: `cmd-${commandSequence}`,
      command_kind: record.kind,
      status: "received",
      reason: typeof record.reason === "string" ? redactCommandText(record.reason) : "",
      redacted_detail: typeof record.redacted_detail === "string" ? redactCommandText(record.redacted_detail) : "",
      run_id: optionalNumber(record, "run_id"),
      scope_id: optionalNumber(record, "scope_id"),
      fiber_id: optionalNumber(record, "fiber_id"),
      schedule_id: optionalNumber(record, "schedule_id"),
      resource_id: optionalNumber(record, "resource_id"),
    };
    commandHistory.push(frame);
    broadcast(frame);
    return frame;
  }

  function commandsSince(afterSequence: number): LiveCommandFrame[] {
    return commandHistory.filter((command) => command.sequence > afterSequence);
  }

  const websocket: WebSocketHandler<undefined> = {
    open(ws) {
      clients.add(ws);
    },
    close(ws) {
      clients.delete(ws);
    },
    message() {
      // Browser clients are read-only subscribers; inbound messages are ignored.
    },
  };

  function fetch(request: Request, server: Server<undefined>): Response | Promise<Response> | undefined {
    const url = new URL(request.url);

    if (url.pathname === "/live") {
      if (server.upgrade(request)) return undefined; // upgraded to WebSocket
      return new Response("expected a websocket upgrade", { status: 426 });
    }

    if (url.pathname === "/ingest" && request.method === "POST") {
      return request.text().then(
        (body) =>
          new Response(JSON.stringify({ ingested: ingestBody(body) }), {
            headers: { "content-type": "application/json" },
          }),
      );
    }

    if (url.pathname === "/frames" && request.method === "POST") {
      return request.json().then(
        (body) => {
          const ingested = ingestFrameBody(body);
          if (ingested === null) return new Response("invalid frame", { status: 400 });
          return new Response(JSON.stringify({ ingested }), {
            headers: { "content-type": "application/json" },
          });
        },
        () => new Response("invalid frame", { status: 400 }),
      );
    }

    if (url.pathname === "/command" && request.method === "POST") {
      return request.json().then(
        (body) => {
          const command = ingestCommand(body);
          if (!command) return new Response("invalid command", { status: 400 });
          return new Response(JSON.stringify(command), {
            headers: { "content-type": "application/json" },
          });
        },
        () => new Response("invalid command", { status: 400 }),
      );
    }

    if (url.pathname === "/commands" && request.method === "GET") {
      const rawAfter = url.searchParams.get("after") ?? "0";
      const after = Number(rawAfter);
      if (!Number.isSafeInteger(after) || after < 0) {
        return new Response("invalid after cursor", { status: 400 });
      }
      const commands = commandsSince(after);
      const nextAfter = commands.length > 0 ? commands[commands.length - 1]!.sequence : Math.max(after, commandSequence);
      return new Response(JSON.stringify({ commands, next_after: nextAfter }), {
        headers: { "content-type": "application/json" },
      });
    }

    if (url.pathname === "/health") {
      return new Response(JSON.stringify({ ok: true, clients: clients.size }), {
        headers: { "content-type": "application/json" },
      });
    }

    return new Response("not found", { status: 404 });
  }

  return { fetch, websocket, ingestLine, ingestBody, ingestFrame, ingestCommand, commandsSince, clientCount: () => clients.size };
}

// `engine | bun collector.ts` — serve + pipe stdin NDJSON to connected clients.
if (import.meta.main) {
  const port = Number(process.env.PORT ?? 4500);
  const collector = createCollector();
  const server = Bun.serve({ port, fetch: collector.fetch, websocket: collector.websocket });
  // eslint-disable-next-line no-console
  console.log(
    `zigeffect live-attach collector on http://127.0.0.1:${server.port}  (ws: /live, ingest: POST /ingest, commands: /command + /commands)`,
  );

  void (async () => {
    const reader = Bun.stdin.stream().getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? ""; // keep the trailing partial line
      for (const line of lines) collector.ingestLine(line);
    }
    if (buffer.trim().length > 0) collector.ingestLine(buffer);
  })();
}
