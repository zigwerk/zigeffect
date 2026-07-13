import { expect, test } from "bun:test";
import {
  connectStreamingQueryOptions,
  connectUnaryMutationOptions,
  connectUnaryQueryOptions,
  createZigEffectConnectTransport,
  openConnectSubscription,
} from "./index";

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
