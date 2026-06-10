import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { deriveProductionTelemetryPreviewModel, parseArtifactJson } from "./causalArtifact";
import {
  productionTelemetryAuthorityRows,
  productionTelemetryStatusMetrics,
  productionTelemetryVerificationCommands,
  workbenchTabsForArtifact,
} from "./App";

test("workbenchTabsForArtifact exposes telemetry only for production telemetry artifacts", () => {
  expect(workbenchTabsForArtifact(false).map((tab) => tab.id)).not.toContain("telemetry");
  expect(workbenchTabsForArtifact(true).map((tab) => tab.id)).toContain("telemetry");
});

test("production telemetry UI helpers expose read-only NenDB retention evidence", () => {
  const artifactJson = readFileSync(
    new URL("../public/sample-production-telemetry-nendb-retention-fixtures.json", import.meta.url),
    "utf8",
  );
  const model = deriveProductionTelemetryPreviewModel(parseArtifactJson(artifactJson), {
    artifactPath: "sample-production-telemetry-nendb-retention-fixtures.json",
  });

  expect(model).not.toBeNull();

  const metrics = productionTelemetryStatusMetrics(model!);
  const authority = productionTelemetryAuthorityRows(model!.authority);
  const commands = productionTelemetryVerificationCommands(model!);

  expect(metrics).toContainEqual({ label: "status", value: "ready", tone: "ok" });
  expect(metrics).toContainEqual({ label: "decision", value: "approve", tone: "ok" });
  expect(authority).toContainEqual({ label: "mutation authority", value: "none", safe: true });
  expect(authority).toContainEqual({ label: "nendb writes", value: "false", safe: true });
  expect(model!.mappingFixtures.map((fixture) => fixture.id)).toContain("nendb-runtime-event-node-fixture");
  expect(model!.mappingFixtures.map((fixture) => fixture.id)).toContain("nendb-correlation-edge-fixture");
  expect(model!.validationChecks).toContain("nendb-write-disabled");
  expect(commands.map((command) => command.command)).toContain("zig build causal-production-telemetry-local-pipeline-fixtures");
});
