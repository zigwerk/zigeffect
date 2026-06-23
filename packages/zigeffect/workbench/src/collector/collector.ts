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

export type Collector = {
  /** Bun.serve `fetch` handler: upgrades `/live` to WS, ingests `POST /ingest`. */
  fetch: (request: Request, server: Server<undefined>) => Response | Promise<Response> | undefined;
  /** Bun.serve `websocket` handlers tracking connected clients. */
  websocket: WebSocketHandler<undefined>;
  /** Map one engine NDJSON line → a frame, broadcast it, return it (or null). */
  ingestLine: (line: string) => LiveFrame | null;
  /** Ingest an NDJSON body; returns the number of frames broadcast. */
  ingestBody: (body: string) => number;
  /** Number of currently-connected WebSocket clients. */
  clientCount: () => number;
};

export function createCollector(): Collector {
  const clients = new Set<ServerWebSocket<undefined>>();
  let sequence = 0;

  const WS_OPEN = 1; // WebSocket.OPEN
  function broadcast(frame: LiveFrame): void {
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

    if (url.pathname === "/health") {
      return new Response(JSON.stringify({ ok: true, clients: clients.size }), {
        headers: { "content-type": "application/json" },
      });
    }

    return new Response("not found", { status: 404 });
  }

  return { fetch, websocket, ingestLine, ingestBody, clientCount: () => clients.size };
}

// `engine | bun collector.ts` — serve + pipe stdin NDJSON to connected clients.
if (import.meta.main) {
  const port = Number(process.env.PORT ?? 4500);
  const collector = createCollector();
  const server = Bun.serve({ port, fetch: collector.fetch, websocket: collector.websocket });
  // eslint-disable-next-line no-console
  console.log(
    `zigeffect live-attach collector on http://127.0.0.1:${server.port}  (ws: /live, ingest: POST /ingest)`,
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
