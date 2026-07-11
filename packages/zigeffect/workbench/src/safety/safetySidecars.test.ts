import { expect, test } from "bun:test";
import { parseFuzzArtifact, parseScheduleArtifact, parseSourceMapArtifact, parseStaticSafetyReport } from "./safetySidecars";

test("safety sidecar parsers retain source allowances schedules and fuzz replay", () => {
  const staticReport = parseStaticSafetyReport({ schema: "zigeffect.static-safety-report.v1", verdict: "passed", truncated: false, findings: [{ id: "ZFX-one", construct: "foreign_interface", disposition: "allowed", allowance_id: "ffi", source: { component: "api", path: "adapters/ffi.zig", declaration: "call", line: 2, column: 3, fingerprint: "sha256:one", source_digest: "sha256:source" } }] });
  expect(staticReport.findings[0]?.allowance_id).toBe("ffi");
  const sourceMap = parseSourceMapArtifact({ schema: "zigeffect.source-map.v1", schema_version: 1, entries: [{ id: 42, component: "api", file: "src/main.zig", declaration: "run", line: 1, column: 1 }] });
  expect(sourceMap.entries[0]?.id).toBe(42);
  const schedule = parseScheduleArtifact({ schema: "zigeffect.schedule-exploration.v1", schema_version: 1, verdict: "failed", truncated: false, failure: { kind: "deadlock", schedule: [0, 1], source_ref_id: 42, error_name: "" } });
  expect(schedule.failure?.schedule).toEqual([0, 1]);
  const fuzz = parseFuzzArtifact({ schema: "zigeffect.fuzz-artifact.v1", status: "failed", seed: 7, cases: 12, input_artifact: "fuzz/7.bin", replay_command: "check-fuzz" });
  expect(fuzz.replay_command).toBe("check-fuzz");
});

test("safety sidecars fail closed for unsupported or malformed artifacts", () => {
  expect(() => parseSourceMapArtifact({ schema: "zigeffect.source-map.v2", schema_version: 2, entries: [] })).toThrow("unsupported");
  expect(() => parseScheduleArtifact({ schema: "zigeffect.schedule-exploration.v1", schema_version: 1, verdict: "failed", truncated: false, failure: { kind: "deadlock", schedule: [-1], source_ref_id: null, error_name: "" } })).toThrow("non-negative");
  expect(() => parseFuzzArtifact({ schema: "zigeffect.fuzz-artifact.v1", status: "maybe", seed: 1, cases: 1, input_artifact: "x", replay_command: "x" })).toThrow("invalid fuzz status");
});
