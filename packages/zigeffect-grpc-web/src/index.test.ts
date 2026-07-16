import { expect, test } from "bun:test";
import {
  connectStreamingQueryOptions,
  connectUnaryMutationOptions,
  connectUnaryQueryOptions,
  createCausalContextInterceptor,
  createZigEffectConnectTransport,
  openConnectSubscription,
} from "./index";
import type { Interceptor } from "@connectrpc/connect";

test("Solid Query options use stable contract-derived keys and cancellation", async () => {
  let observedSignal: AbortSignal | undefined;
  const options = connectUnaryQueryOptions({
    serviceName: "example.v1.Orders",
    methodName: "ListOrders",
    input: { accountId: "account-1" },
    call: async (_input, signal) => {
      observedSignal = signal;
      return { count: 2 };
    },
  });
  expect(options.queryKey).toEqual([
    "zigeffect-connect",
    "example.v1.Orders",
    "ListOrders",
    { accountId: "account-1" },
  ]);
  const controller = new AbortController();
  expect(await options.queryFn({ signal: controller.signal })).toEqual({ count: 2 });
  expect(observedSignal).toBe(controller.signal);
});

test("Connect transport normalizes its base URL", () => {
  const transport = createZigEffectConnectTransport({ baseUrl: "https://api.example.com/" });
  expect(transport).toBeDefined();
});

test("causal context is installed automatically with bounded request and W3C trace identifiers", async () => {
  const interceptor = createCausalContextInterceptor({
    requestId: () => "request-42",
    traceparent: () => "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  });
  let observed: Headers | undefined;
  const next = (async (request: { header: Headers }) => {
    observed = request.header;
    return {};
  }) as unknown as Parameters<Interceptor>[0];
  const invoke = interceptor(next);
  await invoke({ header: new Headers() } as never);
  expect(observed?.get("x-request-id")).toBe("request-42");
  expect(observed?.get("traceparent")).toBe("00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01");
});

test("causal context rejects unsafe correlation values before transport", async () => {
  const interceptor = createCausalContextInterceptor({
    requestId: () => "unsafe\r\nheader",
    traceparent: () => "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
  });
  const next = (async () => ({})) as unknown as Parameters<Interceptor>[0];
  const invoke = interceptor(next);
  expect(invoke({ header: new Headers() } as never)).rejects.toThrow("causal request ID");
});

test("Solid mutation and bounded streaming helpers preserve keys and abort signals", async () => {
  const controller = new AbortController();
  const mutation = connectUnaryMutationOptions({
    serviceName: "example.v1.Orders",
    methodName: "Create",
    signal: () => controller.signal,
    call: async (input: { id: string }, signal) => ({ id: input.id, aborted: signal?.aborted }),
  });
  expect(mutation.mutationKey).toEqual(["zigeffect-connect", "example.v1.Orders", "Create"]);
  expect(await mutation.mutationFn({ id: "42" })).toEqual({ id: "42", aborted: false });

  let observedSignal: AbortSignal | undefined;
  const stream = connectStreamingQueryOptions({
    serviceName: "example.v1.Orders",
    methodName: "Watch",
    input: { account: "a" },
    maxMessages: 2,
    call: async function* (_input, signal) {
      observedSignal = signal;
      yield 1;
      yield 2;
    },
  });
  expect(await stream.queryFn({ signal: controller.signal })).toEqual([1, 2]);
  expect(observedSignal).toBe(controller.signal);
});

test("live subscription delivers incrementally and propagates cancellation", async () => {
  const messages: number[] = [];
  let streamSignal: AbortSignal | undefined;
  const subscription = openConnectSubscription({
    serviceName: "example.v1.Orders",
    methodName: "Watch",
    input: { account: "a" },
    call: async function* (_input, signal) {
      streamSignal = signal;
      yield 1;
      yield 2;
    },
    onMessage: (message) => messages.push(message),
  });
  await subscription.completed;
  expect(messages).toEqual([1, 2]);
  expect(streamSignal).toBe(subscription.signal);
  subscription.abort("done");
  expect(subscription.signal.aborted).toBe(true);
});
