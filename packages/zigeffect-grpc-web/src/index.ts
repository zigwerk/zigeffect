import type { Interceptor } from "@connectrpc/connect";
import { createConnectTransport } from "@connectrpc/connect-web";

export interface ConnectTransportOptions {
  baseUrl: string;
  credentials?: RequestCredentials;
  interceptors?: readonly Interceptor[];
  fetch?: typeof globalThis.fetch;
  causalContext?: CausalContextOptions;
}

export interface CausalContextOptions {
  requestId?: () => string;
  traceparent?: () => string;
}

function randomHex(bytes: number) {
  const value = new Uint8Array(bytes);
  globalThis.crypto.getRandomValues(value);
  return Array.from(value, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function defaultTraceparent() {
  return `00-${randomHex(16)}-${randomHex(8)}-01`;
}

function validRequestId(value: string) {
  return /^[A-Za-z0-9._:-]{1,128}$/.test(value);
}

function validTraceparent(value: string) {
  return /^00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}$/.test(value) &&
    value.slice(3, 35) !== "0".repeat(32) &&
    value.slice(36, 52) !== "0".repeat(16);
}

/**
 * Adds bounded cross-boundary identifiers understood by the native runtime.
 * Values become numeric correlation keys in causal records; payloads, browser
 * state, credentials, and the header strings themselves are never retained.
 */
export function createCausalContextInterceptor(options: CausalContextOptions = {}): Interceptor {
  const requestId = options.requestId ?? (() => globalThis.crypto.randomUUID());
  const traceparent = options.traceparent ?? defaultTraceparent;
  return (next) => async (request) => {
    const nextRequestId = requestId();
    const nextTraceparent = traceparent();
    if (!validRequestId(nextRequestId)) throw new Error("causal request ID must be 1-128 safe ASCII characters");
    if (!validTraceparent(nextTraceparent)) throw new Error("causal traceparent must be a valid non-zero W3C trace context");
    request.header.set("x-request-id", nextRequestId);
    request.header.set("traceparent", nextTraceparent);
    return next(request);
  };
}

export function createZigEffectConnectTransport(options: ConnectTransportOptions) {
  const baseFetch = options.fetch ?? globalThis.fetch;
  const credentialedFetch = ((input: RequestInfo | URL, init?: RequestInit) =>
    baseFetch(input, { ...init, credentials: options.credentials ?? "include" })) as unknown as typeof globalThis.fetch;
  return createConnectTransport({
    baseUrl: options.baseUrl.replace(/\/$/, ""),
    interceptors: [
      createCausalContextInterceptor(options.causalContext),
      ...(options.interceptors ?? []),
    ],
    fetch: credentialedFetch,
    useBinaryFormat: true,
  });
}

export interface UnaryQueryOptions<Input, Output> {
  serviceName: string;
  methodName: string;
  input: Input;
  call: (input: Input, signal: AbortSignal) => Promise<Output>;
  staleTime?: number;
}

/** Framework-native options for `createQuery` from `@tanstack/solid-query`. */
export function connectUnaryQueryOptions<Input, Output>(options: UnaryQueryOptions<Input, Output>) {
  return {
    queryKey: [
      "zigeffect-connect",
      options.serviceName,
      options.methodName,
      options.input,
    ] as const,
    queryFn: ({ signal }: { signal: AbortSignal }) => options.call(options.input, signal),
    staleTime: options.staleTime,
  };
}

export interface UnaryMutationOptions<Input, Output> {
  serviceName: string;
  methodName: string;
  call: (input: Input, signal?: AbortSignal) => Promise<Output>;
  signal?: () => AbortSignal | undefined;
}

/** Framework-native options for `createMutation` from `@tanstack/solid-query`. */
export function connectUnaryMutationOptions<Input, Output>(options: UnaryMutationOptions<Input, Output>) {
  return {
    mutationKey: ["zigeffect-connect", options.serviceName, options.methodName] as const,
    mutationFn: (input: Input) => options.call(input, options.signal?.()),
  };
}

export interface StreamingQueryOptions<Input, Output> {
  serviceName: string;
  methodName: string;
  input: Input;
  call: (input: Input, signal: AbortSignal) => AsyncIterable<Output>;
  maxMessages?: number;
  staleTime?: number;
}

/**
 * A bounded server-stream collector for Solid Query. For truly live streams,
 * use `openConnectSubscription` below so each message is delivered without
 * waiting for stream completion.
 */
export function connectStreamingQueryOptions<Input, Output>(options: StreamingQueryOptions<Input, Output>) {
  const maxMessages = options.maxMessages ?? 1_000;
  if (!Number.isSafeInteger(maxMessages) || maxMessages <= 0) {
    throw new Error("maxMessages must be a positive safe integer");
  }
  return {
    queryKey: [
      "zigeffect-connect-stream",
      options.serviceName,
      options.methodName,
      options.input,
    ] as const,
    queryFn: async ({ signal }: { signal: AbortSignal }) => {
      const messages: Output[] = [];
      for await (const message of options.call(options.input, signal)) {
        if (messages.length === maxMessages) {
          throw new Error("Connect stream exceeded maxMessages");
        }
        messages.push(message);
      }
      return messages;
    },
    staleTime: options.staleTime,
  };
}

export interface ConnectSubscription<Input, Output> {
  serviceName: string;
  methodName: string;
  input: Input;
  call: (input: Input, signal: AbortSignal) => AsyncIterable<Output>;
  onMessage: (message: Output) => void;
  onError?: (error: unknown) => void;
  onComplete?: () => void;
  signal?: AbortSignal;
}

/** Starts a cancellable, SSR-safe server-stream subscription. */
export function openConnectSubscription<Input, Output>(options: ConnectSubscription<Input, Output>) {
  const controller = new AbortController();
  const abortFromParent = () => controller.abort(options.signal?.reason);
  if (options.signal?.aborted) abortFromParent();
  else options.signal?.addEventListener("abort", abortFromParent, { once: true });
  const completed = (async () => {
    try {
      for await (const message of options.call(options.input, controller.signal)) {
        options.onMessage(message);
      }
      if (!controller.signal.aborted) options.onComplete?.();
    } catch (error) {
      if (!controller.signal.aborted) options.onError?.(error);
      throw error;
    } finally {
      options.signal?.removeEventListener("abort", abortFromParent);
    }
  })();
  return {
    key: ["zigeffect-connect-subscription", options.serviceName, options.methodName, options.input] as const,
    signal: controller.signal,
    abort: (reason?: unknown) => controller.abort(reason),
    completed,
  };
}

export * from "./gen/zigeffect/grpc/v1/conformance_pb";
export * from "./gen/grpc/health/v1/health_pb";
export * from "./gen/grpc/reflection/v1/reflection_pb";
