import { expect, test } from "bun:test";
import sample from "../../public/sample-test-run.json";
import { parseTestRunReceipt, testRunIsComplete } from "./testReceipt";

test("test run parser preserves requirement source causal replay and completeness evidence", () => {
  const run = parseTestRunReceipt(sample);
  expect(run.project).toBe("agent-store");
  expect(run.receipts[0]?.scenario.requirement).toBe("req-create-order");
  expect(run.receipts[0]?.assertions[0]?.source.path).toBe("src/orders.zig");
  expect(run.receipts[0]?.assertions[0]?.causal_event_ids).toEqual([7, 8]);
  expect(run.receipts[0]?.replay_command).toContain("zigeffect test replay");
  expect(run.receipts[0]?.execution.native_receipt).toBe(true);
  expect(run.receipts[0]?.coverage.required_gaps).toBe(0);
  expect(run.receipts[0]?.evidence.map((item) => item.kind)).toEqual(["model", "schedule", "differential", "virtual_world", "mutation", "performance", "sandbox"]);
  expect(testRunIsComplete(run)).toBe(true);
});

test("test run parser rejects future schemas malformed counts and invalid assertion status", () => {
  expect(() => parseTestRunReceipt({ ...sample, schema_version: 2 })).toThrow("unsupported test run schema");
  expect(() => parseTestRunReceipt({ ...sample, selected: 2 })).toThrow("counts do not match");
  const malformed = structuredClone(sample) as any;
  malformed.receipts[0].assertions[0].status = "maybe";
  expect(() => parseTestRunReceipt(malformed)).toThrow("invalid assertion status");
});

test("test run parser surfaces incomplete evidence without treating it as passed", () => {
  const incomplete = structuredClone(sample) as any;
  incomplete.status = "incomplete";
  incomplete.passed = 0;
  incomplete.incomplete = 1;
  incomplete.receipts[0].status = "incomplete";
  incomplete.receipts[0].completeness.dropped_runtime_events = 1;
  const run = parseTestRunReceipt(incomplete);
  expect(run.status).toBe("incomplete");
  expect(testRunIsComplete(run)).toBe(false);
});

test("test run parser distinguishes durable graph IDs from runtime-local IDs", () => {
  const durable = structuredClone(sample) as any;
  durable.receipts[0].causal_event_id_space = "graph_durable";
  durable.receipts[0].causal_graph_session_id = 9;
  const run = parseTestRunReceipt(durable);
  expect(run.receipts[0]?.causal_event_id_space).toBe("graph_durable");
  expect(run.receipts[0]?.causal_graph_session_id).toBe(9);

  durable.receipts[0].causal_graph_session_id = null;
  expect(() => parseTestRunReceipt(durable)).toThrow("durable causal IDs require a graph session");
});
