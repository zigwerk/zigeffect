import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { deriveAppFacingPreviewModel, deriveProductionTelemetryPreviewModel, parseArtifactJson } from "./causalArtifact";
import {
  appFacingPreviewAuthorityRows,
  appFacingPreviewStatusMetrics,
  appFacingPreviewVerificationCommands,
  productionTelemetryAuthorityRows,
  productionTelemetryStatusMetrics,
  productionTelemetryVerificationCommands,
  workbenchTabsForArtifact,
} from "./App";

test("workbenchTabsForArtifact exposes telemetry only for production telemetry artifacts", () => {
  expect(workbenchTabsForArtifact(false).map((tab) => tab.id)).not.toContain("telemetry");
  expect(workbenchTabsForArtifact(true).map((tab) => tab.id)).toContain("telemetry");
});

test("workbenchTabsForArtifact exposes app preview only for app-facing preview artifacts", () => {
  expect(workbenchTabsForArtifact(false).map((tab) => tab.id)).not.toContain("app-preview");
  expect(workbenchTabsForArtifact(false, false).map((tab) => tab.id)).not.toContain("app-preview");
  expect(workbenchTabsForArtifact(false, true).map((tab) => tab.id)).toContain("app-preview");
  expect(workbenchTabsForArtifact(true, true).map((tab) => tab.id)).toEqual(
    expect.arrayContaining(["telemetry", "app-preview"]),
  );
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

test("app-facing preview UI helpers expose SolidJS read-only authority evidence", () => {
  const model = deriveAppFacingPreviewModel({
    schema: "zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1",
    schema_version: 1,
    status: "ready",
    decision: "approve",
    ready_for_next_branch: true,
    applied: false,
    mutation_authority: "none",
    read_only_preview: true,
    solid_webui_enabled: true,
    solid_webui_renderer: "solidjs",
    webui_bridge: "webui-dev/zig-webui",
    hosted_live_dashboard_enabled: false,
    app_mutation_controls_enabled: false,
    react_renderer_enabled: false,
    alternate_renderer_enabled: false,
    nendb_write_enabled: false,
    nendb_adapter_execution_enabled: false,
    durable_write_enabled: false,
    deployment_mutation_enabled: false,
    bridge_records: [{ id: "solid-webui-review-preview-bridge", status: "read-only-preview-next" }],
    checks: [{ name: "solid-webui-readonly", status: "pass", detail: "read-only" }],
    required_verification_commands: ["bun run zigeffect:workbench:typecheck"],
    verified_commands: ["bun run zigeffect:workbench:test"],
    next_branch_if_ready: "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report",
  }, { artifactPath: "app-preview.json" });

  expect(model).not.toBeNull();

  const metrics = appFacingPreviewStatusMetrics(model!);
  const authority = appFacingPreviewAuthorityRows(model!.authority);
  const commands = appFacingPreviewVerificationCommands(model!);

  expect(metrics).toContainEqual({ label: "status", value: "ready", tone: "ok" });
  expect(metrics).toContainEqual({ label: "decision", value: "approve", tone: "ok" });
  expect(authority).toContainEqual({ label: "renderer", value: "solidjs", safe: true });
  expect(authority).toContainEqual({ label: "webui bridge", value: "webui-dev/zig-webui", safe: true });
  expect(authority).toContainEqual({ label: "app mutation controls", value: "false", safe: true });
  expect(authority).toContainEqual({ label: "hosted live dashboard", value: "false", safe: true });
  expect(authority).toContainEqual({ label: "react renderer", value: "false", safe: true });
  expect(authority).toContainEqual({ label: "alternate renderer", value: "false", safe: true });
  expect(commands.map((command) => command.label)).toEqual(["required 1", "verified 1"]);
  expect(commands.map((command) => command.command)).toEqual([
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
  ]);
});
