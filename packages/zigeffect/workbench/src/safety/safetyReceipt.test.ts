import { expect, test } from "bun:test";
import { parseSafetyReceipt, receiptIsComplete } from "./safetyReceipt";

const fixture = {
  schema: "zigeffect.safety-receipt.v1", schema_version: 1, verdict: "passed", project: "demo", component: "", source_revision: "sha256:abc", profile: "agent_safe_v1",
  toolchain: { zig_version: "0.16.0", target: "aarch64-macos", optimize: "Debug" },
  static: { files: 1, source_bytes: 20, forbidden: 0, allowed: 0, stale: 0, introduced: 0, resolved: 0 },
  memory: { allocations: 1, frees: 1, live_allocations: 0, live_bytes: 0, peak_bytes: 32, invalid_frees: 0, out_of_memory: 0 },
  completeness: { dropped_diagnostics: 0, dropped_findings: 0, dropped_runtime_events: 0, stale_source_refs: 0, truncated_artifacts: 0 },
  gates: [{ kind: "source_policy", required: true, status: "passed", command_id: "", detail: "passed", artifact_id: "static.json", replay_command: "zigeffect project check --agent --json" }],
  diagnostics: [], finding_ids: [], causal_artifact_ids: [],
};

test("safety receipt parser accepts complete v1 evidence", () => {
  const receipt = parseSafetyReceipt(JSON.stringify(fixture));
  expect(receipt.verdict).toBe("passed");
  expect(receiptIsComplete(receipt)).toBe(true);
});

test("safety receipt parser fails closed for unknown schemas and malformed evidence", () => {
  expect(() => parseSafetyReceipt({ ...fixture, schema: "zigeffect.safety-receipt.v2" })).toThrow("unsupported");
  expect(() => parseSafetyReceipt({ ...fixture, gates: [{ ...fixture.gates[0], status: "maybe" }] })).toThrow("invalid gate status");
  const incomplete = parseSafetyReceipt({ ...fixture, verdict: "incomplete", completeness: { ...fixture.completeness, dropped_findings: 1 } });
  expect(receiptIsComplete(incomplete)).toBe(false);
});
