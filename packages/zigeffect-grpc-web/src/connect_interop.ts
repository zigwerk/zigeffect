import { Code, ConnectError, createClient } from "@connectrpc/connect";
import { createConnectTransport } from "@connectrpc/connect-web";
import { create, toBinary } from "@bufbuild/protobuf";
import { ConformanceService, ServerStreamRequestSchema } from "./gen/zigeffect/grpc/v1/conformance_pb";

const baseUrl = process.argv[2];
if (!baseUrl) throw new Error("missing base URL");

const preflight = await fetch(`${baseUrl}/zigeffect.grpc.v1.ConformanceService/Unary`, {
  method: "OPTIONS",
  headers: {
    Origin: "http://localhost:39052",
    "Access-Control-Request-Method": "POST",
    "Access-Control-Request-Headers": "content-type,connect-protocol-version",
  },
});
if (preflight.status !== 204) throw new Error(`preflight failed: ${preflight.status}`);
if (preflight.headers.get("access-control-allow-origin") !== "http://localhost:39052") {
  throw new Error("preflight omitted the allowed origin");
}

const transport = createConnectTransport({ baseUrl, useBinaryFormat: true });
const client = createClient(ConformanceService, transport);
const response = await client.unary({ id: "connect-es", sequence: 42n });
if (response.id !== "connect-es" || response.acceptedSequence !== 42n) {
  throw new Error(`unexpected response: ${response.id}/${response.acceptedSequence}`);
}

let responseContentType = "";
let responseRequestId: string | null = null;
let streamComplete: string | null = null;
const sequences: bigint[] = [];
const streamStarted = performance.now();
let firstMessageAt: number | null = null;
for await (const message of client.serverStream(
  { count: 3n },
  {
    headers: new Headers({ "request-id": "connect-stream-1" }),
    onHeader(headers) {
      responseContentType = headers.get("content-type") ?? "";
      responseRequestId = headers.get("request-id");
    },
    onTrailer(trailers) {
      streamComplete = trailers.get("stream-complete");
    },
  },
)) {
  if (firstMessageAt === null) firstMessageAt = performance.now();
  sequences.push(message.sequence);
}
const streamCompleted = performance.now();
if (sequences.join(",") !== "0,1,2") {
  throw new Error(`unexpected stream: ${sequences.join(",")}`);
}
if (!responseContentType.startsWith("application/connect+proto")) {
  throw new Error(`unexpected stream content type: ${responseContentType}`);
}
if (responseRequestId !== "connect-stream-1" || streamComplete !== "true") {
  throw new Error(`stream metadata missing: ${responseRequestId}/${streamComplete}`);
}
if (firstMessageAt === null || firstMessageAt < streamStarted || streamCompleted - firstMessageAt < 20) {
  throw new Error(`stream was buffered instead of delivered incrementally: ${firstMessageAt}/${streamCompleted}`);
}

try {
  for await (const _ of client.serverStream({ count: -1n })) {
    throw new Error("invalid stream unexpectedly returned a message");
  }
  throw new Error("invalid stream unexpectedly completed successfully");
} catch (error) {
  if (!(error instanceof ConnectError) || error.code !== Code.InvalidArgument) {
    throw error;
  }
}

const cancellation = new AbortController();
let cancelledAfterMessage = false;
try {
  for await (const _ of client.serverStream({ count: 32n }, { signal: cancellation.signal })) {
    cancelledAfterMessage = true;
    cancellation.abort();
  }
  throw new Error("aborted stream unexpectedly completed successfully");
} catch (error) {
  if (!(error instanceof ConnectError) || error.code !== Code.Canceled) throw error;
}
if (!cancelledAfterMessage) throw new Error("stream did not deliver before cancellation");

const afterCancellation = await client.unary({ id: "after-cancel", sequence: 7n });
if (afterCancellation.id !== "after-cancel" || afterCancellation.acceptedSequence !== 7n) {
  throw new Error("channel did not recover after stream cancellation");
}

const timeoutPayload = toBinary(
  ServerStreamRequestSchema,
  create(ServerStreamRequestSchema, { count: 3n }),
);
const timeoutEnvelope = new Uint8Array(timeoutPayload.length + 5);
new DataView(timeoutEnvelope.buffer).setUint32(1, timeoutPayload.length, false);
timeoutEnvelope.set(timeoutPayload, 5);
const timeoutResponse = await fetch(
  `${baseUrl}/zigeffect.grpc.v1.ConformanceService/ServerStream`,
  {
    method: "POST",
    headers: {
      "content-type": "application/connect+proto",
      "connect-protocol-version": "1",
      "connect-timeout-ms": "10",
    },
    body: timeoutEnvelope,
  },
);
if (timeoutResponse.status !== 200) throw new Error(`timeout stream HTTP status: ${timeoutResponse.status}`);
const timeoutBody = new Uint8Array(await timeoutResponse.arrayBuffer());
let timeoutOffset = 0;
let timeoutEnd: { error?: { code?: string } } | undefined;
while (timeoutOffset < timeoutBody.length) {
  if (timeoutBody.length - timeoutOffset < 5) throw new Error("truncated timeout envelope");
  const flags = timeoutBody[timeoutOffset]!;
  const length = new DataView(timeoutBody.buffer, timeoutBody.byteOffset + timeoutOffset + 1, 4).getUint32(0, false);
  const end = timeoutOffset + 5 + length;
  if (end > timeoutBody.length) throw new Error("oversized timeout envelope");
  if ((flags & 0x02) !== 0) {
    timeoutEnd = JSON.parse(new TextDecoder().decode(timeoutBody.subarray(timeoutOffset + 5, end)));
  }
  timeoutOffset = end;
}
if (timeoutEnd?.error?.code !== "deadline_exceeded") {
  throw new Error(`server did not enforce Connect timeout: ${JSON.stringify(timeoutEnd)}`);
}
